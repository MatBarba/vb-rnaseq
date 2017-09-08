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

# Prepare json reader
my $json = JSON->new;
$json->relaxed;

# Update tracks data
if ($opt{input_tracks}) {
$logger->debug("Extract tracks data from the json file");
  my $entries = $json->decode("" . slurp $opt{input_tracks});
  update_tracks($db, $entries, \%opt);
}

# Update bundles data
if ($opt{input_bundles}) {
  my $entries = $json->decode("" . slurp $opt{input_bundles});
  update_bundles($db, $entries, \%opt);
}

# Copy tracks
if ($opt{copy_tracks}) {
  copy_tracks($db);
}

###############################################################################
# MAIN FUNCTIONS

sub copy_tracks {
  my $db = shift;
  
  # Retrieve the list of bundles witht their tracks
  my $bundles = $db->resultset('Bundle')->search({},
  {
    prefetch => {
      bundle_tracks => 'track'
    }
  });
  
  # Copy the tracks text and descriptions to the bundles, if the bundles have
  # only 1 track -> title_auto + text_auto
  for my $bundle ($bundles->all) {
    my @tracks = $bundle->bundle_tracks;
    if (@tracks == 1) {
      my $track = $tracks[0]->track;
      $bundle->update({
          text_auto  => $track->text_manual  // $track->text_auto,
          title_auto => $track->title_manual // $track->title_auto,
        });
    }
  }
}

sub update_tracks {
  my ($db, $entries, $opt) = @_;
  
  # 1) Add list of tracks for each entry
  my $matched_entries = match_tracks($db, $entries);
  
  # Stats
  my @to_merge = grep { @{ $_->{tracks} } > 1 } @$matched_entries;
  my @unique = grep { @{ $_->{tracks} } == 1 } @$matched_entries;
  $logger->info( sprintf("%d total entries\n", @$matched_entries+0) );
  $logger->info( sprintf("%d Tracks to merge\n", @to_merge+0) );
  $logger->info( sprintf("%d unique tracks\n", @unique+0) );
  
  # 2) Merge the tracks if asked to
  $matched_entries = merge_tracks($db, $matched_entries) if $opt->{merge_tracks};
  
  # 3) Annotate tracks
  annotate_tracks($db, $matched_entries) if $opt->{annotate_tracks};
}

sub match_tracks {
  my ($db, $entries) = @_;
  
  my @ok_entries;
  ENTRY: for my $entry (@$entries) {
    # For this entry, get the list of tracks
    my @tracks = $db->get_tracks(sra_ids => $entry->{sra_ids}, species => $entry->{species});
    my $sra_list = join(',', @{ $entry->{sra_ids} });
    
    # Check number of tracks found
    if (@tracks == 0) {
      $logger->warn("No track found for the following SRAs: $sra_list");
      next ENTRY;
    }
    elsif (@tracks > 1) {
      $logger->warn("More than 1 track found for the following SRAs: $sra_list");
    }
    else {
      $logger->debug("One track found for the following SRAs: $sra_list = track_id " . $tracks[0]->track_id);
    }
    
    # Store the list of tracks
    my @track_ids = map { $_->track_id } @tracks;
    $entry->{tracks} = \@track_ids;
    push @ok_entries, $entry;
  }
  return \@ok_entries;
}

sub merge_tracks {
  my ($db, $entries) = @_;
  
  if (@$entries == 0) {
    $logger->info("No tracks to merge");
    return;
  }
  
  $logger->info("Merging tracks...");
  my @merged_entries;
  for my $entry (@$entries) {
    if (@{$entry->{tracks}} > 1) {
      my $track_id = $db->merge_tracks_by_sra_ids($entry->{sra_ids});
      $entry->{tracks} = [$track_id];
    } else {
      $logger->warn("No more than 1 tracks to merge");
    }
    push @merged_entries, $entry;
  }
  
  # Force regenerate all the merge_ids
  my $force = 0;
  $db->regenerate_merge_ids($force);
  
  return \@merged_entries;
}

sub annotate_tracks {
  my ($db, $entries) = @_;
  
  if (not $entries or @$entries == 0) {
    $logger->info("No tracks to annotate");
    return;
  }
  
  $logger->info("Annotate tracks");
  for my $entry (@$entries) {
    my $track_id = $entry->{tracks}->[0];
    next if not $track_id;
    $logger->debug("Annotate track $track_id");

    my $track_content = {
      text_manual   => $entry->{text},
      title_manual  => $entry->{title},
    };
    $db->update_track($track_id, $track_content);
  }
  
  # Regenerate the human file name
  $logger->info("Regenerate human file names");
  $db->update_file_names();
}

###############################################################################
# BUNDLES
sub update_bundles {
  my ($db, $entries, $opt) = @_;
  
  # 1) Add list of bundles for each entry
  my $matched_entries = match_bundles($db, $entries);
  
  # Stats
  my @to_merge = grep { @{ $_->{bundles} } > 1 } @$matched_entries;
  my @unique = grep { @{ $_->{bundles} } == 1 } @$matched_entries;
  $logger->info( sprintf("%d total entries\n", @$matched_entries+0) );
  $logger->info( sprintf("%d Bundles to merge\n", @to_merge+0) );
  $logger->info( sprintf("%d unique tracks\n", @unique+0) );
  
  # 2) Merge the bundles if asked to
  $matched_entries = merge_bundles($db, $matched_entries) if $opt->{merge_bundles};
  
  # 3) Annotate tracks
  annotate_bundles($db, $matched_entries) if $opt->{annotate_bundles};
}

sub match_bundles {
  my ($db, $entries) = @_;
  
  my @ok_entries;
  ENTRY: for my $entry (@$entries) {
    # For this entry, get the list of bundles
    my @tracks = $db->get_tracks(sra_ids => $entry->{sra_ids}, species => $entry->{species});
    my $sra_list = join(',', @{ $entry->{sra_ids} });
    
    # Get the corresponding bundles
    my @bundles;
    for my $track (@tracks) {
      push @bundles, @{ $db->get_bundle_id_from_track_id($track->track_id) };
    }
    my %bundles_hash = map { $_ => 1 } @bundles;
    @bundles = sort keys %bundles_hash;
    
    # Check number of bundles found
    if (@bundles == 0) {
      $logger->warn("No bundle found for the following SRAs: $sra_list");
      next ENTRY;
    }
    elsif (@bundles > 1) {
      $logger->warn("More than 1 bundle found for the following SRAs: $sra_list = " . join(',', @bundles));
    }
    else {
      $logger->debug("One bundle found for the following SRAs: $sra_list = $bundles[0]");
    }
    
    # Store the list of bundles
    $entry->{bundles} = \@bundles;
    push @ok_entries, $entry;
  }
  return \@ok_entries;
}

sub merge_bundles {
  my ($db, $entries) = @_;
  
  if (@$entries == 0) {
    $logger->info("No bundles to merge");
    return;
  }
  
  $logger->info("Merging bundles");
  my @merged_entries;
  my $n_merged = 0;
  for my $entry (@$entries) {
    if (@{$entry->{bundles}} > 1) {
      my $bundle_id = $db->merge_bundles(@{ $entry->{bundles} });
      $logger->debug("New bundle: $bundle_id");
      $entry->{bundles} = [$bundle_id];
      $n_merged++;
    }
    push @merged_entries, $entry;
  }
  $logger->info("$n_merged merged bundles were created");
  return \@merged_entries;
}

sub annotate_bundles {
  my ($db, $entries) = @_;
  
  # Check number
  my $n = @$entries;
  $logger->info("$n to bundles");
  return if $n == 0;
  
  # Annotate each entry
  for my $entry (@$entries) {
    # Check that the bundle is merged
    if (@{$entry->{bundles}} > 1) {
      $logger->debug('Skip annotation (needs merging)');
      next;
    }
    
    # Check that the bundle has an id
    my $bundle_id = $entry->{bundles}->[0];
    if (not $bundle_id) {
      $logger->debug("Warning: bundle without id, can't annotate");
      next;
    }
    
    # Can annotate the bundle
    $logger->debug("Annotate bundle $bundle_id");
    my $bundle_content = {
      text_manual   => $entry->{text},
      title_manual  => $entry->{title},
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
    This script annotates and merges tracks based on a json file of the following format:
    
    [
      {
        "title": "Foo",
        "text": "Bar",
        "sra_ids": ["A", "B", "C"],
      }
    ]
    
    The script first tries to find tracks matching exactly the list of SRA ids.
    * If some entries match several tracks, they can be merged with option -merge
    * After the merging phase, all the tracks can be annotated with option -annotate
      This will add the title and text as title_manual and text_manual in the track table.
    
    Database connection (mandatory):
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    TRACKS
    --input_tracks <path> : json file with the entries data, in the format described above
    -merge_tracks         : merge tracks when an entry match several of them
    -annotate_tracks      : fill the title and text fields for each track from the json file
    
    BUNDLES
    --input_bundles <path> : json file with the entries data, in the format described above
    -merge_bundles         : merge bundles when an entry match several of them
    -annotate_bundles      : fill the title and text fields for each bundle from the json file
    
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
    "input_tracks=s",
    "merge_tracks",
    "annotate_tracks",
    "input_bundles=s",
    "merge_bundles",
    "annotate_bundles",
    "copy_tracks",
    "help",
    "verbose",
    "debug",
  );

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --input_tracks or --input_bundles or --copy_tracks")   if not ($opt{input_tracks} or $opt{input_bundles} or $opt{copy_tracks});
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

