#!/usr/bin/env perl

use strict;
use warnings;
use Readonly;
use Carp;
use autodie;
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);

use RNAseqDB::DB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

###############################################################################
# MAIN
# Get command line args
my %opt = %{ opt_check() };

# Connect to the database schema
my $db = RNAseqDB::DB->connect(
  "dbi:mysql:host=$opt{host}:port=$opt{port}:database=$opt{db}",
  $opt{user},
  $opt{password}
);

# Add a single species from the command-line
my $species_added = 0;
if ($opt{production_name} and $opt{taxon_id}) {
  my $species = {
    production_name    => $opt{production_name},
    binomial_name      => $opt{binomial_name},
    taxon_id           => $opt{taxon_id},
    strain             => $opt{strain},
    assembly           => $opt{assembly},
    assembly_accession => $opt{assembly_accession},
  };
  my $added = $db->add_species( $species );
  $species_added += $added;
}
# Or add a list from a file (more efficient)
elsif (defined $opt{file}) {
  my @species_list = get_species_from_file($opt{file});
  for my $species (@species_list) {
    my $added = $db->add_species( $species );
    $species_added += $added;
  }
}

$logger->info("$species_added new species added");

###############################################################################
# UTILITY SUBS
sub get_species_from_file {
  my $file = shift;
  return () if not defined $file;
  
  my @species_list;
  open my $SPECIES_FH, '<', $file;
  while( my $line = readline $SPECIES_FH ) {
    next if $line =~ /^\s*$/;
    chomp $line;
    my @elts = split /\t/, $line;
    my %species = (
      binomial_name      => $elts[0],
      production_name    => $elts[1],
      taxon_id           => $elts[2],
      strain             => $elts[3],
      assembly           => $elts[4],
      assembly_accession => $elts[5],
    );
    push @species_list, \%species;
  }
  close $SPECIES_FH;
  return @species_list;
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
    This script adds a production species to the RNAseqDB.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Input:
    --production_name <str> : Production name
    --binomial_name <str>   : Binomial name
    --taxon_id <str>        : NCBI taxonomic id
    --strain <str>          : Strain name (optional)
    or
    --file <path>     : path to a file with a list of SRA run accessions
    
    Other:
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
    "production_name=s",
    "binomial_name=s",
    "taxon_id=s",
    "strain=s",
    "file=s",
    "help",
    "verbose",
    "debug",
  );

  usage()              if $opt{help};
  usage("Need --host") if not $opt{host};
  usage("Need --port") if not $opt{port};
  usage("Need --user") if not $opt{user};
  usage("Need --db") if not $opt{db};
  usage("Need --species and --taxon_id, or --file") if not (($opt{production_name} and $opt{taxon_id}) xor $opt{file});
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

