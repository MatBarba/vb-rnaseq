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
use Data::Dumper;

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

# Retrieve track groups
my $groups = $db->get_track_groups({
  species     => $opt{species},
  files_dir   => $opt{files_dir},
});
if (@$groups == 0) {
  die "No group to extract";
}

if (defined $opt{output}) {
  open my $OUT, '>', $opt{output};
  my $json = JSON->new;
  $json->allow_nonref;  # Keep undef values as null
  $json->canonical;     # order keys
  $json->pretty;        # Beautify
  print $OUT $json->encode($groups) . "\n";
  close $OUT;
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
    This script exports groups of tracks.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Tracks filter:
    --species <str>   : only outputs tracks for a given species (production_name)
    
    The script can output the groups in json format.
    
    FILES OUTPUT
    --output <path>   : path to the output file
    
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
    "registry=s",
    "species=s",
    "output=s",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --output") if not $opt{output};
  $opt{password} //= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

