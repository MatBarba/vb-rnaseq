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
use Bio::EnsEMBL::RNAseqDB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

###############################################################################
# MAIN
# Get command line args
my %opt = %{ opt_check() };

# Connect to the database schema
$logger->debug("Connect to DB");
my $db = Bio::EnsEMBL::RNAseqDB->connect(
  "dbi:mysql:host=$opt{host}:port=$opt{port}:database=$opt{db}",
  $opt{user},
  $opt{password}
);

# Get the drupal nodes data
$logger->debug("Extract drupal data");
my $drupal = decode_json("" . slurp $opt{input});
$logger->debug($drupal);

# Match the drupal nodes to the tracks
match_drupal_tracks($db, $drupal);

# Update the drupal nodes informations
update_tracks($db, $drupal);

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
      my $tracks = $db->get_tracks(sra_ids => \@sras);
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

sub update_tracks {
  my ($db, $drupal) = @_;
  $logger->debug("Update tracks with drupal node information...");
  
  NODE: for my $node (@$drupal) {
    my $node_id = $node->{node_id};
    my $track_id = $node->{track_id};
    if (not defined $track_id) {
      $logger->warn("No track associated with drupal node $node_id");
      next NODE;
    }
    
    # First: update tracks
    my $track_content = {
      text_manual   => $node->{text},
      title_manual  => $node->{title},
    };
    $db->update_track($track_id, $track_content);
    
    # Second: update bundles (if they are 1 track = 1 bundle)
    my $bundle_ids_aref = $db->get_bundle_id_from_track_id($track_id);
    my $n_bundles = scalar @$bundle_ids_aref;
    if ($n_bundles == 0) {
      $logger->warn("No bundle found associated with track $track_id (for node $node_id)");
      next NODE;
    }
    elsif ($n_bundles > 1) {
      $logger->warn("More than one active drupal node found associated with track $track_id (for node $node_id)");
      next NODE;
    }
    
    # One bundle, one track: let's update the bundle too
    my $bundle_id = $bundle_ids_aref->[0];
    my $bundle_content = {
      text_manual    => $node->{text},
      title_manual   => $node->{title},
      drupal_node_id => $node_id,
    };
    $db->update_bundle($bundle_id, $bundle_content);
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

