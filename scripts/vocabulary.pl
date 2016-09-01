#!/usr/bin/env perl

use strict;
use warnings;
use Readonly;
use Carp;
use autodie;
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

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

# Retrieve the tracks

# Analyze vocabulary
$db->vocabulary($base_vocabulary);
my $tracks_voc = $db->analyze_tracks_vocabulary;

if ($opt{list}) {
  print Dumper $tracks_voc;
}

if ($opt{add}) {
  $db->add_vocabulary_to_tracks($tracks_voc);
}

###############################################################################
# SUBS

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

