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

# Add a single run from the command-line
my $runs_added = 0;
if ($opt{run}) {
  my $added = $db->add_run( $opt{run} );
  $runs_added += $added;
}
# Or add a list from a file (more efficient)
else {
  my @runs = get_runs_from_file($opt{file});
  for my $run_acc (@runs) {
    my $added = $db->add_run( $run_acc );
    $runs_added += $added;
  }
}

$logger->info("$runs_added new runs added");

###############################################################################
# UTILITY SUBS
sub get_runs_from_file {
  my $file = shift;
  
  my @run_accs;
  open my $RUNS_FH, '<', $file;
  while( my $line = readline $RUNS_FH ) {
    chomp $line;
    push @run_accs, $line;
  }
  close $RUNS_FH;
  return @run_accs;
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
    This script adds an SRA run to the RNAseqDB.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Input:
    --run <str>       : SRA run accession (e.g. SRR000000)
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
    "run=s",
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
  usage("Need --run or --file") if not ($opt{run} xor $opt{file});
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

