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

# Add a single SRA accession from the command-line
my $runs_added = 0;
if ($opt{sra_acc}) {
  my $added = $db->add_sra( $opt{sra_acc} );
  $runs_added += $added;
}

# Or add a list from a file (more efficient)
else {
  my @sras = get_sras_from_file( $opt{file} );
  for my $sra_acc (@sras) {
    my $added = $db->add_sra( $sra_acc );
    $runs_added += $added;
  }
}

$logger->info("$runs_added new runs added");

###############################################################################
# UTILITY SUBS
sub get_sras_from_file {
  my $file = shift;
  
  my @sra_accs;
  open my $SRAS_FH, '<', $file;
  while( my $line = readline $SRAS_FH ) {
    chomp $line;
    push @sra_accs, $line;
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
    --sra_acc <str>   : SRA accession (e.g. SRP000000 for a study)
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
  usage("Need --run or --file") if not ($opt{sra_acc} xor $opt{file});
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

