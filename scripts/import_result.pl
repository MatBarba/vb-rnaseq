#!/usr/bin/env perl

use strict;
use warnings;
use Readonly;
use Carp;
use autodie;
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

use JSON qw( decode_json );
use Perl6::Slurp qw( slurp );
use RNAseqDB::DB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

###############################################################################
# MAIN
# Get command line args
my %opt = %{ opt_check() };

# Connect to the database schema
$logger->debug("Connect to DB");
my $db = RNAseqDB::DB->connect(
  "dbi:mysql:host=$opt{host}:port=$opt{port}:database=$opt{db}",
  $opt{user},
  $opt{password}
);

# Get the list of json files
$logger->debug("Get json files");
my %tracks_results;
for my $json_file (glob $opt{json_files}) {
  my $json_content = slurp $json_file;
  my $json_data = decode_json($json_content);
  %tracks_results = ( %tracks_results, %$json_data );
}

# Add those tracks to the database
add_tracks_results($db, \%tracks_results);

###############################################################################
# MAIN FUNCTIONS
sub add_tracks_results {
  my ($db, $results_href) = @_;
  
  $logger->info("Importing " . (keys %$results_href) . " tracks");
  
  for my $merge_id (sort keys %$results_href) {
    $logger->info("Importing data for $merge_id");
    my $track_data = $results_href->{$merge_id};
    $logger->debug("Data:" . Dumper($track_data));
    
    # First, get the track_id
    my $track_id = $db->get_track_id_from_merge_id($merge_id);
    
    if ($track_id) {
      # Then, add the data
      my @files = (
        $track_data->{bw_file},
        $track_data->{bam_file},
      );
      $db->add_track_results($track_id, $track_data->{cmds}, \@files);
    }
  }
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
    This script import tracks aligned with the RNAseq pipeline into the RNAseq DB.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    --json_files <path> : path to the files to add to the database (to use a joker, use double quotes)
    
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
    "json_files=s",
    "help",
    "verbose",
    "debug",
  );

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --json_files")   if not $opt{json_files};
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

