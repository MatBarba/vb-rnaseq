#!/usr/bin/env perl

use 5.10.0;
use strict;
use warnings;
use Readonly;
use Carp;
use autodie qw(:all);
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use JSON;
use Perl6::Slurp;
use List::Util qw( first );
use File::Path qw(make_path);
use File::Copy;
use File::Temp;
use Data::Dumper;

use Bio::EnsEMBL::RNAseqDB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

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

my $data = $db->get_new_runs_tracks( $opt{species} );
if (keys %$data == 0) {
  die "No tracks to align";
}

if ($opt{list}) {
    my $json = JSON->new->allow_nonref->canonical;
    print $json->pretty->encode($data) . "\n";
}
elsif ($opt{groups_file}) {
  make_groups_file($data, $opt{groups_file});
}

###############################################################################
# SUBS

sub make_groups_file {
  my ($data, $groups_file) = @_;

  open my $outfile, ">", $groups_file;

  for my $species (sort keys %$data) {
    for my $track_id (sort keys %{$data->{$species}}) {
      my $tdata = $data->{$species}->{$track_id};
      my $run_ids = $tdata->{run_accs};
      my $merge_id = $tdata->{merge_id};

      my @line = ($species, $merge_id, join(",", @$run_ids));
      print $outfile join("\t", @line) . "\n";
    }
  }
  close $outfile;

  return $groups_file;
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
    This script extracts a list of tracks to be aligned and either display the list,
    or align them with a pipeline.

    DATABASE CONNECTION
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    FILTERS
    --species <str>   : only use tracks for a given species (production_name)
    
    ACTIONS
    --groups_file <path> : create a groups file for the SRA alignment pipeline
    --list           : list the tracks to be aligned (print to STDOUT)
    
    OTHER
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
    "list",
    "groups_file=s",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --list or --groups_file") if not ($opt{list} xor $opt{groups_file});
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

