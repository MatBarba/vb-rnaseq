#!/usr/bin/env perl

use strict;
use warnings;
use Readonly;
use Carp;
use autodie;
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;
use Perl6::Slurp qw(slurp);
use JSON;

use Bio::EnsEMBL::RNAseqDB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

# Structure of data to identify controlled terms (with variations)
# using regexp when possible
my $base_vocabulary = {
  'dev' => {
    'embryos'   =>'embryos?',
    'pupae'     =>'pupae?',
    'larvae'    =>'larvae?',
    'adults'    =>'adults?',
    '1st instar'  =>'1st instar',
    '2nd instar'  =>'2nd instar',
    '3rd instar'  =>'3rd instar',
    '4th instar'  =>'4th instar',
    'post-emergence'  =>'post[ -]emergence',
  },
  'tissue'  => {
    'antennae'  =>'antennae?',
    'ovaries'   =>'ovar(?:y|ies)',
    'brains'    =>'brains?',
    'terminal genitalia' =>'terminal genitalia',
    'anterior midgut' =>'anterior midgut',
    'whole body'  =>'whole body|carcass',
    'posterior midgut'  =>'posterior midgut',
    'rectum'  =>'rectum',
    'malpighian tubules'  =>'malpighian tubules',
    'fat body'  =>'fat body',
    'testes'  =>'testes',
    'maxillary palps'  =>'maxillary palps',
    'midlegs'  =>'midlegs',
    'hindlegs'  =>'hindlegs',
    'forelegs'  =>'forelegs',
    'proboscis'  =>'proboscis',
    'rostrums'  =>'rostrums',
    'cell line' =>'cell line',
    'abdominal tips' =>'abdominal tips',
  },
  'sex' => {
    'male'  =>'males?',
    'female'  =>'females?',
    'mixed sex' =>'mixed sex',
  },
  'feeding' => {
    'non-blood-fed' =>'non-blood[ -]fee?d',
    'blood-fed' =>'(?:post[ -])?blood[ -](?:fee?d|meal)',
    'sugar-fed' =>'(?:post[ -])?sugar[ -](?:fee?d|meal|diet)',
  },
  'condition' => {
    'resistance' =>'resistan(?:t|ce)',
    'post-infection'  =>'post[ -]infect(?:ion|ed)',
  },
};

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

# Use a file?
if ($opt{input}) {
  load_cv_json($db, $opt{input});
} else {
  # Analyze vocabulary
  $db->vocabulary($base_vocabulary);
  my $tracks_voc = $db->analyze_tracks_vocabulary();

  if ($opt{list}) {
    print Dumper $tracks_voc;
  }

  if ($opt{add}) {
    $db->add_vocabulary_to_tracks($tracks_voc);
  }
}

###############################################################################
# SUBS
sub load_cv_json {
  my ($db, $input) = @_;
  my $cv_json = slurp $input;
  my $json = JSON->new;
  my $cv_list = $json->decode($cv_json);
  
  TRACK: for my $track_name (keys %$cv_list) {
    my $cv = $cv_list->{$track_name};
    my @cv_terms = @{$cv->{cvterms}};
    
    # Get the track_id
    my $sra_id = $cv->{sra_id};
    
    if (@cv_terms == 0) {
      $logger->warn("WARNING: No CV terms for $track_name");
      next TRACK;
    } elsif (not $sra_id) {
      $logger->warn("WARNING: No sra_id for $track_name");
      next TRACK;
    }
    
    my @tracks = $db->get_tracks(sra_ids => [$sra_id]);
    
    if (@tracks == 0) {
      $logger->warn("WARNING: No track for sra_id $sra_id. Skip $track_name.");
      next TRACK;
    } elsif (@tracks > 1) {
      $logger->warn("WARNING: More than one track for sra_id $sra_id. Skip $track_name.");
      next TRACK;
    } else {
      $logger->info("Add voc for $track_name");
      my $track = shift @tracks;
      my $track_id = $track->track_id;

      for my $cv_term (@cv_terms) {
        # Parse the field to extract the accession (if there is one)
        my ($voc_type, $voc_acc, $voc_text);
        if ($cv_term =~ /^([A-z0-9]+):(\d+) ?(.*)$/) {
          $voc_type = $1;
          $voc_acc  = $1 . ':' . $2;
          $voc_text = $3;
        } else {
          $voc_text = $cv_term;
        }
        $logger->warn(sprintf("%s, %s, %s", $voc_acc // 'noacc', $voc_text // 'notext', $voc_type // 'notype'));

        # Upload the vocabulary
        $db->add_vocabulary_to_track(
          track_id  => $track_id,
          acc   => $voc_acc,
          text  => $voc_text,
          type  => $voc_type,
        );
      }
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
    This simple script helps to find controlled vocabulary in tracks.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Actions:
    --list            : simply list the controlled vocabulary found in the tracks
    --add             : actually add the controlled vocabulary to the database
    --input <path>    : use a json file with CV terms matched to tracks with SRA ids
    
    Filter:
    --species <str>   : production_name to only annotate tracks of a given species (optional)
    
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
    "species=s",
    "list",
    "add",
    "input=s",
    "help",
    "verbose",
    "debug",
  );

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need one action") if not ($opt{list} xor $opt{add} xor $opt{input});
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

