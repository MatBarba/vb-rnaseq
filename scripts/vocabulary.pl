#!/usr/bin/env perl

use strict;
use warnings;
use Readonly;
use Carp;
use autodie;
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

use RNAseqDB::DB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

# Structure of data to identify controlled terms (with variations)
# using regexp when possible
my $base_vocabulary = {
  'dev' => {
    'embryos'   => ['embryos?'],
    'pupae'     => ['pupae?'],
    'larvae'    => ['larvae?'],
    'adults'    => ['adults?'],
    '1st instar'  => ['1st instar'],
    '2nd instar'  => ['2nd instar'],
    '3rd instar'  => ['3rd instar'],
    '4th instar'  => ['4th instar'],
    'post-emergence'  => ['post[ -]emergence'],
  },
  'tissue'  => {
    'antennae'  => [qw/antennae antenna/],
    'ovaries'   => [qw/ovaries ovary/],
    'brains'    => ['brains?'],
    'terminal genitalia' => ['terminal genitalia'],
    'anterior midgut' => ['anterior midgut'],
    'whole body'  => ['whole body', 'carcass'],
    'posterior midgut'  => ['posterior midgut'],
    'rectum'  => ['rectum'],
    'malpighian tubules'  => ['malpighian tubules'],
    'fat body'  => ['fat body'],
    'testes'  => ['testes'],
    'maxillary palps'  => ['maxillary palps'],
    'midlegs'  => ['midlegs'],
    'hindlegs'  => ['hindlegs'],
    'forelegs'  => ['forelegs'],
    'proboscis'  => ['proboscis'],
    'rostrums'  => ['rostrums'],
    'cell line' => ['cell line'],
    'abdominal tips' => ['abdominal tips'],
  },
  'sex' => {
    'male'  => [qw/males male/],
    'female'  => [qw/females female/],
    'mixed sex' => ['mixed sex'],
  },
  'feeding' => {
    'non-blood-fed' => [
    'non-blood[ -]fee?d',
    ],
    'blood-fed' => [
    '(?:post[ -])?blood[ -](?:fee?d|meal)',
    ],
    'sugar-fed' => [
    '(?:post[ -])?sugar[ -](?:fee?d|meal)',
    'sugar diet',
    ],
  },
  'condition' => {
    'resistant' => ['resistant', 'resistance'],
    'post-infection'  => ['post[ -]infect(?:ion|ed)'],
  },
};

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

# Retrieve the tracks
my @tracks = $db->get_active_tracks($opt{species});

# Analyze vocabulary
my $tracks_voc = analyze_tracks_vocabulary(\@tracks, $base_vocabulary);

if ($opt{list}) {
  print Dumper $tracks_voc;
}

if ($opt{add}) {
  add_vocabulary_to_tracks($db, $tracks_voc);
}

###############################################################################
# SUBS

sub format_voc {
  my ($voc) = @_;
  my @formatted_voc;
  
  for my $type (keys %$voc) {
    my $type_href = $voc->{$type};
    
    for my $name (keys %$type_href) {
      my $synonyms_aref = $type_href->{$name};
      
      my $synonyms_regex = join '|', @$synonyms_aref;
      my %synonym_group = (
        pattern   => $synonyms_regex,
        type      => $type,
        name      => $name
      );
      push @formatted_voc, \%synonym_group;
    }
  }
  $logger->debug(Dumper \@formatted_voc);
  
  return \@formatted_voc;
}

sub analyze_tracks_vocabulary {
  my ($tracks, $base_vocabulary) = @_;
  
  # Reformat the controlled vocabulary in a programmatically usable form
  my $vocabulary = format_voc($base_vocabulary);
  
  my %tracks_vocabulary;
  foreach my $track (@$tracks) {
    my $title0 = $track->title_manual || $track->title_auto;
    next if not $title0;
    my $title = $title0;
    $title =~ s/\([^\)]*\)//g;
    my %track_voc;
    
    # Check patterns
    for my $voc (@$vocabulary) {
      my $pattern = $voc->{pattern};
      if ($title =~ s/([^-]|^)\b($pattern)\b([^-]|$)/$1$3/i) {
        $track_voc{$pattern} = {
          type  => $voc->{type},
          name  => $voc->{name},
        };
      }
    }
    
    # Store keywords
    $tracks_vocabulary{$track->track_id} = [values %track_voc];
    $logger->debug($track->merge_id . "\n\t" . $title0  . "\n\t" . $title ."\n\t". Dumper(\%track_voc));
    
    # Logging...
    if ($title =~ /[^ ]/) {
      $logger->info("Incomplete: $title");
    }
  }
  
  return \%tracks_vocabulary;
}

sub add_vocabulary_to_tracks {
  my ($db, $tracks_voc) = @_;
  
  for my $track_id (sort keys %$tracks_voc) {
    my $voc_aref = $tracks_voc->{$track_id};
    foreach my $voc (@$voc_aref) {
      $db->add_vocabulary_to_track(
        track_id  => $track_id,
        name      => $voc->{name},
        type      => $voc->{type},
      );
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
    "help",
    "verbose",
    "debug",
  );

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need an action") if not ($opt{list} or $opt{add});
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

