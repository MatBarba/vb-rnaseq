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

my @sras = ();

# Add a single SRA accession from the command-line
if ($opt{sra_acc}) {
  my @sra_list = split(/,/, $opt{sra_acc});
  if ($opt{species}) {
    push @sras, map { [$_, $opt{species}] } @sra_list;
  } else {
    push @sras, map { [$_] } @sra_list;
  }
}
# Or add a list from a file (more efficient)
if ($opt{file}) {
  push @sras, get_sras_from_file( $opt{file} );
}

# Add all runs for those SRA accessions
my $runs_added = 0;
for my $sra_acc (@sras) {
  my ($acc, $species) = @$sra_acc;

  $logger->info("Add $acc for $species");

  my $added = $db->add_sra($acc, $species);
  $runs_added += $added;
}

$logger->info("$runs_added new runs added");

# Finalization: add new bundles (by default, 1 bundle = 1 study)
$db->create_new_bundles();

###############################################################################
# UTILITY SUBS
sub get_sras_from_file {
  my $file = shift;
  
  my @sra_accs;
  open my $SRAS_FH, '<', $file;
  while( my $line = readline $SRAS_FH ) {
    next if $line =~ /^\s*$|^\#/;
    chomp $line;
    my $acc = [split /\s+/, $line];
    push @sra_accs, $acc;
  }
  close $SRAS_FH;
  return @sra_accs;
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
    This script adds SRA runs to the RNAseqDB from a single SRA accession or from a list.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Input:
    --sra_acc <str>   : SRA accession list (e.g. SRP000000,SRP00001 for 2 studies)
    --species <str>   : production_name for the species to use (optional, in case of ambiguity)
    or
    --file <path>     : path to a file with a list of SRA accessions
    
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
    "sra_acc=s",
    "species=s",
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
  usage("Need --sra or --file") if not ($opt{sra_acc} xor $opt{file});
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

