#!/usr/bin/env perl

use v5.14;
use strict;
use warnings;
use Readonly;
use Carp;
use Carp 'verbose';
use autodie;
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

use JSON qw( decode_json );
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

my @species = ();

# Get the list of files in the directory
my %files = get_files_from_dir($opt{dir});

# Get the list of expected new tracks from DB
my %old_aligned = get_aligned_tracks($db);
my %new_aligned = get_non_aligned_tracks($db);

# Check old aligned track
my @old;
my @new;
my @unknown;
for my $base_path (sort keys %files) {
  if (exists $old_aligned{$base_path}) {
    push @old, $base_path;
    delete $old_aligned{$base_path};
  } elsif (exists $new_aligned{$base_path}) {
    push @new, $base_path;
  } else {
    push @unknown, $base_path;
  }
}

$logger->info("Old aligned files correct: " . scalar(@old)) if @old;
$logger->info("New aligned files correct: " . scalar(@new)) if @new;
$logger->info("Unknown files: " . scalar(@unknown)) if @unknown;
my @remaining_old = sort keys %old_aligned;

if ($opt{unknown}) {
  for my $u (@unknown) { say $u }
}

if ($opt{import}) {
  $logger->info("Import new aligned data to db");
  
  my %tracks_results;
  for my $name (@new) {
    my $json_file;
    if ($files{$name} and $files{$name}{cmds}) {
      $logger->debug("$name has: " . join(", ", sort keys %{$files{$name}}));
      $json_file = $files{$name}{cmds};
    } else {
      $logger->warn("No files data for $name");
      next;
    }

    my $json_content = slurp $json_file;
    my $json_data = decode_json($json_content);
    %tracks_results = ( %tracks_results, %$json_data );
  }

  # Add those tracks to the database
  add_tracks_results($db, \%tracks_results);
}

###############################################################################
# MAIN FUNCTIONS

sub get_files_from_dir {
  my ($dir) = @_;
  
  my %files;

  for my $type (qw(bam bigwig cmds)) {
    $logger->info("Load files of type $type");
    
    my $tdir = "$dir/$type";
    opendir(my $dh, $tdir);
    while (my $sp = readdir $dh) {
      next if $sp =~ /^\./;

      my $sp_dir = "$tdir/$sp";
      $logger->debug($sp_dir);

      opendir(my $spdh, $sp_dir);
      while (my $file = readdir $spdh) {
        next if $file =~ /^\./;
        next if $file =~ /bam\.bai$/;
        my $base_path = "$sp/$file";
        $base_path =~ s/\.(bam|bw|cmds.*)$//;
        $base_path =~ s/_([A-Z][a-z]{3,4}[A-Z][0-9])$//;  # Also remove the assembly?
        $logger->debug($base_path);

        if (not exists $files{$base_path}) {
          $files{$base_path} = {};
        }
        my $file_path = "$sp_dir/$file";
        $files{$base_path}{$type} = $file_path;
      }
    }
  }

  $logger->info(scalar(keys %files) . " tracks files");
  return %files;
}

sub get_non_aligned_tracks {
  my ($db) = @_;

  # Get the list of tracks already aligned from DB
  my @tracks = $db->get_tracks(aligned => 0, all_assemblies => 1);

  my %unknown;
  for my $track (@tracks) {
    my $merge_id = $track->merge_id;

    # Get all possible assemblies
    for my $ta ($track->track_analyses) {
      my $assembly = $ta->assembly;
      my $production_name = $assembly->production_name;

      my $track_basepath = "$production_name/${merge_id}";
      $unknown{$track_basepath}++;
    }
  }
  $logger->info(scalar(keys %unknown) . " known unaligned tracks");
  return %unknown;
}

sub get_aligned_tracks {
  my ($db) = @_;

  # Get the list of tracks already aligned from DB
  my @tracks = $db->get_tracks(aligned => 1, all_assemblies => 1);

  my %known;
  for my $track (@tracks) {
    my $merge_id = $track->merge_id;

    # Get all possible assemblies
    for my $ta ($track->track_analyses) {
      my $assembly = $ta->assembly;
      my $production_name = $assembly->production_name;

      my $track_basepath = "$production_name/${merge_id}";
      $known{$track_basepath}++;
    }
  }
  $logger->info(scalar(keys %known) . " known aligned tracks");
  return %known;
}

sub add_tracks_results {
  my ($db, $results_href) = @_;
  
  $logger->info("Importing " . (keys %$results_href) . " tracks");
  
  TRACK: for my $merge_id (sort keys %$results_href) {
    $logger->info("Importing data for $merge_id");
    my $track_data = $results_href->{$merge_id};
    my $assembly = guess_assembly($track_data);
    
    # First, get the track_id
    my ($track) = $db->get_tracks(
      merge_ids => [$merge_id],
      assembly => $assembly
    );
    if (not $track) {
      $logger->warn("No track for $merge_id ($assembly). Skip.");
      next TRACK;
    }
    my @track_ans = $track->track_analyses;
    my $track_an = shift @track_ans;
    
    # Then, add the data
    if ($track_an) {
      my @files = (
        $track_data->{bw_file},
        $track_data->{bam_file},
      );
      
      # Only keep the file names, not the whole path
      @files   = map { remove_paths($_) } @files;
      my @cmds = map { remove_paths($_) } @{$track_data->{cmds}};
      my $version = $track_data->{aligner_version};
      
      # Add those data to the database
      $db->add_commands($track_an, \@cmds, $version);
      $db->add_files($track_an, \@files);
    }
    else {
      $logger->warn("Can't match the merge_id to a track_id in the database ($merge_id)");
    }
  }
}

sub guess_assembly {
  my $data = shift;
  
  my $file = $data->{bw_file};
  croak("Can't get bigwig path from cmds file.") if not $file;
  my $assembly;
  if ($file =~ /_([A-Z][a-z]{3}[A-Z]\d)\.bw/) {
    $assembly = $1;
  }
  return $assembly;
}

sub remove_paths {
  my $str = shift;
  
  $str =~ s{\/?\b[^ ]+\/([^\/ ]+)\b}{$1}g;
  $str =~ s/\s+/ /g;
  $str =~ s/\s+$//;
  return $str;
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
    
    --dir <path> : directory where each bam, bigwig, commands dirs are stored

    ACTION:
    (By default: report)
    --import          : import any known, new aligned track
    --unknown         : list all files that are unknown in the final_dir
    
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
    "dir=s",
    "import",
    "unknown",
    "import",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --dir")   if not $opt{dir};
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

