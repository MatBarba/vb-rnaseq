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
use File::Spec qw(cat_file);
use File::Path qw(make_path);
use File::Copy;
use Data::Dumper;

use EGTH::TrackHub;
use EGTH::TrackHub::Genome;
use EGTH::TrackHub::Track;

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

my $groups = $db->get_track_groups({
    species     => $opt{species},
    files_dir   => $opt{files_dir},
  });
if (@$groups == 0) {
  die "No group to extract";
}

# Retrieve track groups
if (defined $opt{output}) {
  open my $OUT, '>', $opt{output};
  my $json = JSON->new;
  $json->allow_nonref;  # Keep undef values as null
  $json->canonical;     # order keys
  $json->pretty;        # Beautify
  print $OUT $json->encode($groups) . "\n";
  close $OUT;
} elsif (defined $opt{hub_root}) {
  my $groups = $db->get_track_groups({
      species     => $opt{species},
      files_dir   => $opt{files_dir},
    });
  
  # Create a trackhub for each group
  create_trackhubs($groups, $opt{hub_root});
}

###############################################################################
# SUB
# Trackhubs creation
sub create_trackhubs {
  my ($groups, $dir) = @_;
  
  GROUP: for my $group (@$groups) {
    # Create the TrackHub
    my $hub = EGTH::TrackHub->new(
      id          => $group->{id},
      shortLabel  => $group->{label} // $group->{id},
      longLabel   => $group->{description} // $group->{label} // $group->{id},
    );
    $hub->root_dir( $dir );
    
    # Create the associated genome
    my $genome = EGTH::TrackHub::Genome->new(
      id      => $group->{assembly},
    );
    
    # Add all tracks to the genome
    my @hub_tracks;
    TRACK: for my $track (@{ $group->{_childDocuments_} }) {
      if (not $track->{bigwig_url}) {
        warn "No bigwig file for this track $track->{id}";
        next TRACK;
      }
      my $hub_track = EGTH::TrackHub::Track->new(
        track => $track->{id},
        shortLabel => $track->{id},
        longLabel => $track->{id},
        bigDataUrl  => $track->{bigwig_url},
        visibility  => 'all',
      );
      
      push @hub_tracks, $hub_track;
    }
    
    if (@hub_tracks == 0) {
      carp "No track can be used for this group $group->{id}: skip";
      next GROUP;
    } elsif (@hub_tracks == 1) {
      $genome->add_track($hub_tracks[0]);
    } else {
      # Put all that in a supertrack
      $genome->add_track($hub_tracks[0]); # Deactivated for now
    }
    
    # Add the genome...
    $hub->add_genome($genome);
    
    # And create the trackhub files
    $hub->create_files;
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
    This script exports groups of tracks.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Tracks filter:
    --species <str>   : only outputs tracks for a given species (production_name)
    
    The script can output the groups in json format or create track hubs.
    
    JSON OUTPUT
    --output <path>   : path to the output file in json
    
    TRACK HUBS
    --hub_root   <path> : root where the trackhubs will be created
    
    Other parameters:
    -files_dir        : root dir to use for the files paths
    
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
    "files_dir=s",
    "output=s",
    "hub_root=s",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --output or --hub_root") if (not $opt{output} and not $opt{hub_root});
  $opt{password} //= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

