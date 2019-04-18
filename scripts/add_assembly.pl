#!/usr/bin/env perl

use strict;
use warnings;
use Readonly;
use Carp;
use autodie;
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);

use Bio::EnsEMBL::RNAseqDB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();
$Carp::Verbose = 1;

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

# Add an assembly
my $added = $db->add_assembly(
  species            => $opt{species},
  production_name    => $opt{production_name},
  assembly           => $opt{assembly},
  assembly_accession => $opt{accession},
  sample             => $opt{sample},
  do_not_retire      => $opt{do_not_retire}
);

$logger->info("New assembly $opt{assembly} added for $opt{production_name}");

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
    This script adds a new assembly to the RNAseqDB.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Input:
    --species <str>   : Production name of the species
    --assembly <str>  : New assembly
    --accession <str> : GCA accession (recommended for track hubs)
    --sample <str>    : sample region (recommended for track hubs)

    --production_name <str> : Assembly production name if different from species
    --do_not_replace  : use as an alt assembly, don't retire the other ones
    
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
    "species=s",
    "production_name=s",
    "assembly=s",
    "accession=s",
    "sample=s",
    "do_not_replace",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()              if $opt{help};
  usage("Need --host") if not $opt{host};
  usage("Need --port") if not $opt{port};
  usage("Need --user") if not $opt{user};
  usage("Need --db")   if not $opt{db};
  $opt{password} ||= '';
  usage("Need --species")  if not $opt{species};
  usage("Need --assembly") if not $opt{assembly};
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

