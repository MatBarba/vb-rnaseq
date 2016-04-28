#!/usr/bin/env perl

use strict;
use warnings;
use Readonly;
use Carp;
use autodie;
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

use JSON qw( decode_json encode_json );
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

# Get the drupal nodes data
$logger->debug("Extract drupal data");
my $drupal = decode_json(slurp $opt{input});
$logger->debug($drupal);

# Match the drupal nodes to the tracks
match_drupal_tracks($db, $drupal);

# Update the drupal nodes informations
update_drupal_nodes($db, $drupal);

# Write the updated json file
if (defined $opt{output}) {
  open my $JSOUT, '>', $opt{output};
  print $JSOUT encode_json($drupal);
  close $JSOUT;
}

###############################################################################
# MAIN FUNCTIONS
sub match_drupal_tracks {
  my ($db, $drupal) = @_;
  $logger->debug("Matching drupal nodes to tracks...");
  
  NODE: for my $node (@$drupal) {
    my $node_id = $node->{node_id};
    $logger->debug("\t$node_id");
    
    # First, try to get track from a sample
    my @types = qw( srs srr srx srp vbsrs vbsrr vbsrx vbsrp );
    TYPE: foreach my $type (@types) {
      if (not defined $node->{ $type } or $node->{ $type } =~ /^\s*$/) {
        $logger->debug("\t$node_id: Skip $type");
        next TYPE;
      }
      my @sras = split /[ ,]/, $node->{ $type };
      my $tracks = $db->get_tracks_from_sra(\@sras);
      if ( scalar @$tracks == 0 ) {
        $logger->warn("$node_id: No track found for SRA $type accessions = @sras");
        next TYPE;
      }
      elsif ( scalar @$tracks > 1 ) {
        $logger->warn("$node_id: More than one track found for SRA $type accessions = @sras");
        next TYPE;
      }
      else {
        $logger->info("$node_id: One track found for SRA $type accessions = @sras : track_id = $tracks->[0]");
        $node->{track_id} = $tracks->[0];
        next NODE;
      }
    }
    $logger->warn(sprintf "%s: Could not use any SRA accession to match this drupal node (%s)", $node_id, $node->{title});
  }
}

sub update_drupal_nodes {
  my ($db, $drupal) = @_;
  $logger->debug("Update all drupal nodes linked to tracks...");
  
  NODE: for my $node (@$drupal) {
    my $node_id = $node->{node_id};
    my $track_id = $node->{track_id};
    if (not defined $track_id) {
      $logger->warn("No track associated with drupal node $node_id");
      next NODE;
    }
    
    # Get the drupal node_id to update
    my $node_ids_aref = $db->get_drupal_id_from_track_id($track_id);
    my $n_nodes = scalar @$node_ids_aref;
    if ($n_nodes == 0) {
      $logger->warn("No drupal node found associated with track $track_id (for node $node_id)");
      next NODE;
    }
    elsif ($n_nodes > 1) {
      $logger->warn("More than one active drupal node found associated with track $track_id (for node $node_id)");
      next NODE;
    }
    
    # One drupal node, one track: let's update the drupal_node
    my $drupal_id = $node_ids_aref->[0];
    my $node_content = {
      manual_text    => $node->{text},
      manual_title   => $node->{title},
      drupal_node_id => $node_id,
    };
    $db->update_drupal_node($drupal_id, $node_content);
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
    This script exports the list of tracks to create from an RNAseq DB in a JSON format.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    --input <path>    : input file with drupal nodes data
    --output <path>   : output file with updated drupal nodes data (linked node = track_id)
    
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
    "input=s",
    "output=s",
    "help",
    "verbose",
    "debug",
  );

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --input")   if not $opt{input};
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

