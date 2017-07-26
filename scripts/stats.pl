#!/usr/bin/env perl
use 5.10.00;
use strict;
use warnings;
use Readonly;
use Carp;
use autodie;

use List::Util qw(sum first);
use List::MoreUtils qw(uniq);
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;
use Readonly;

use Bio::EnsEMBL::RNAseqDB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

Readonly my @SRA_COLS => qw(studies experiments runs samples tracks bundles);

###############################################################################
# MAIN
# Get command line args
my %opt = %{ opt_check() };

# Connect to the database schema
my $db = Bio::EnsEMBL::RNAseqDB->connect(
  "dbi:mysql:host=$opt{host}:port=$opt{port}:database=$opt{db}",
  $opt{user},
  $opt{password}
);

# Retrieve the list of species
my $species = get_species_from_db($db, \%opt);

print_stats($species, $opt{species});

###############################################################################
# SUBS

sub get_species_from_db {
  my ($db, $opt) = @_;

  my %species_search;
  $species_search{'strains.production_name'} = $opt->{species} if $opt->{species};
  if ($opt->{antispecies}) {
    my @anti = split ',', $opt->{antispecies};
    $species_search{'-not'} = [ map { { "strains.production_name" => $_ } } @anti ];
  }
  $species_search{'track.status'} = 'ACTIVE';
  $species_search{'study.status'} = 'ACTIVE';
  $species_search{'experiment.status'} = 'ACTIVE';
  $species_search{'runs.status'} = 'ACTIVE';
  $species_search{'samples.status'} = 'ACTIVE';
  my @species = $db->resultset('Species')->search(
    \%species_search,
    { prefetch =>
      {
        'strains' => 
        [
          {'assemblies' => { 'track_analyses' => { 'track' => { 'bundle_tracks' => 'bundle' } } } },
          { 'samples' => { 'runs' => { 'experiment' => 'study' } } },
        ],
      } 
    }
  );
  return \@species;
}

sub print_stats {
  my ($species, $expected_species) = @_;
  my $sp_count = @$species;
  
  say "Species\t$sp_count";
  my %stats;
  my %expected = map { $_ => 1 } @$expected_species;
  
  for my $sp (@$species) {
    for my $strain ($sp->strains) {
      my $name = $strain->production_name;
      delete $expected{$name};
      
      # Assemblies
      for my $assembly ($strain->assemblies) {
        my $old = $assembly->latest ? "" : " (old)";
        say "$name\t" . $assembly->assembly . $old;
      }
      
      # SRA stats
      my $sp_stats = get_stats($strain);
      $stats{$name} = $sp_stats;
    }
  }
  for my $missing_sp (sort keys %expected) {
    say "Missing $missing_sp";
    $stats{$missing_sp} = {};
  }
  
  print_row_stats(\%stats);
}

sub get_stats {
  my ($strain) = @_;
  
  my %count;
  my %experiment_count;
  my %study_count;
  my %bundle_count;
  
  for my $s ($strain->samples) {
    $count{samples}++;
    for my $r ($s->runs) {
      $count{runs}++;
      
      my $e = $r->experiment;
      $experiment_count{$e->experiment_id}++;
      my $s = $e->study;
      $study_count{$s->study_id}++;
    }
  }
  $count{studies} = scalar keys %study_count;
  $count{experiments} = scalar keys %experiment_count;
  
  # Get tracks stats
  my $assembly = first { $_->latest } $strain->assemblies;
  for my $tra ($assembly->track_analyses) {
    my $tr = $tra->track;
    if ($tr->status eq 'ACTIVE') {
      $count{tracks}++;
    }
    
    for my $bun_tr ($tr->bundle_tracks) {
      my $bundle = $bun_tr->bundle;
      $bundle_count{$bundle->bundle_id}++;
    }
  }
  $count{bundles} = scalar keys %bundle_count;
  
  return \%count;
}

sub print_row_stats {
  my ($stats) = @_;
  
  say "";
  say join("\t", ("#Species", @SRA_COLS));
  my %sum;
  
  for my $species (sort keys %$stats) {
    my $sp_stats = $stats->{$species};
    my @line = ($species);
    push @line, map { $sp_stats->{$_} // 0 } @SRA_COLS;
    say join("\t", @line);
    
    for my $col (@SRA_COLS) {
      $sum{$col} += $sp_stats->{$col} // 0;
    }
  }
  
  say "";
  say join("\n", map { "$_\t$sum{$_}" } keys %sum);
}

###############################################################################
# Parameters and usage
# Print a simple usage note
sub usage {
  my $error = shift;
  my $help = '';
  if ($error) {
    $help = "[ $error ]\n";
  }
  $help .= <<'EOF';
    Prints stats for the given rnaseq database.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Options:
    --species <str>     : production_name to only search for one species
    --antispecies <str> : production_name of species to exclude
    
    --help            : show this help message
    --verbose         : show detailed progress
    --debug           : show even more information (for debugging purposes)
EOF
  print STDERR "$help\n";
  exit(1);
}

# Get the command-line arguments and check for the mandatory ones
sub opt_check {
  my %opt = ();
  GetOptions(\%opt,
    "host=s",
    "port=i",
    "user=s",
    "password=s",
    "db=s",
    "species=s",
    "antispecies=s",
    "help",
    "verbose",
    "debug",
  );

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  $opt{password} ||= '';
  $opt{species} = [split(/,/, $opt{species})] if $opt{species};
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

