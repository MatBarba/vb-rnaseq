#!/usr/bin/env perl

use 5.10.0;
use strict;
use warnings;
use Readonly;
use Carp;
use autodie qw(:all);
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use List::Util qw( first );
use File::Path qw(make_path);
use File::Spec::Functions qw(catdir catfile);
use File::Copy;
use File::Temp;
use Data::Dumper;
use IO::File;
use XML::Writer;
use JSON qw(decode_json);

use Bio::EnsEMBL::RNAseqDB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

use Data::Dumper;

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

my @assemblies = $db->get_assemblies(%opt);
for my $assembly (@assemblies) {
  my $species = $assembly->production_name;
  print STDERR "Work on species $species\n";
  my $exps = get_experiments($db, $species);
  if (@$exps == 0) {
    warn "No experiments to export for $species\n";
    next;
  }

  # Print the samples
  print_tracks($species, $exps);
}

###############################################################################
# SUBS

sub get_experiments {
  my ($db, $species) = @_;

  my $search = {
    'me.status'    => 'ACTIVE',
    'track.status' => 'ACTIVE',
  };
  $search->{'assembly.production_name'} = $species;

  my $bundles = $db->resultset('Bundle')->search(
    $search,
    {
      order_by    => { -asc => 'me.bundle_id' },
      prefetch    => {
        bundle_tracks => {
          track => [
            {
              'track_analyses' => 'assembly',
            },
            {
              'sra_tracks' => { 'run' => [{ 'experiment' => 'study' }, 'sample'] },
            },
          ],
        },
      },
    }
  );

  # Get experiment data
  my @experiments;
  my %done_exp;
  for my $b ($bundles->all) {
    # Experiment name = study_name
    my ($study_name, $study) = get_study($b);
    my $exp_name = $study_name;
    $exp_name =~ s/[() -]+/_/g;
    $exp_name =~ s/_+$//;
    next if exists $done_exp{$exp_name};

    # Get tracks
    my @tracks = get_tracks($b);

    my $exp = {
      study_id => $study->study_sra_acc,
      name => $exp_name,
      title => $exp_name . " " . $study->title,
      abstract => $study->abstract,
      date => simple_date($study->date),
      tracks => \@tracks,
    };

    push @experiments, $exp;
    $done_exp{$exp_name}++;
  }
  
  return \@experiments;
}


sub simple_date {
  my ($date) = @_;

  $date =~ s/^(\d{4}-\d{2}-\d{2}).*$/$1/;
  return $date;
}


sub get_study {
  my ($bundle) = @_;

  my %studies_hash;
  for my $bt ($bundle->bundle_tracks->all) {
    my $track = $bt->track;
    for my $st ($track->sra_tracks->all) {
      my $run = $st->run;
      my $study = $run->experiment->study;
      $studies_hash{$study->study_sra_acc} = $study;
    }
  }

  my @studies = sort { $a->study_sra_acc cmp $b->study_sra_acc } values %studies_hash;

  my $study_name;
  my $study;

  if (@studies == 1) {
    $study = $studies[0];
    ($study_name) = $studies[0]->study_sra_acc;
  } else {
    $study = $studies[0];
    my $first_study = $studies[0];
    my $last_study = $studies[-1];
    $study_name = $first_study->study_sra_acc . "_" . $last_study->study_sra_acc;
    warn("More than one study for the bundle: $study_name\n");
  }
  return ($study_name, $study);
}


sub get_tracks {
  my ($bundle) = @_;

  my @tracks;
  for my $bt ($bundle->bundle_tracks->all) {
    my $track = $bt->track;
    my @runs;
    my %samples;
    for my $st ($track->sra_tracks->all) {
      my $run = $st->run;
      push @runs, $run->run_sra_acc;
      my $sample = $run->sample;
      $samples{ $sample->sample_sra_acc }++;
    }
    push @tracks, {
      title => $track->title_manual || $track->title_auto || "",
      text => $track->text_manual || $track->text_auto || "",
      runs => \@runs,
      samples => [sort keys %samples],
    };
  }
  return @tracks;
}

sub print_tracks {
  my ($species, $exps) = @_;

  for my $exp (@$exps) {
    my $exp_name = $exp->{name};
    for my $track (@{ $exp->{tracks} }) {
      my @line = (
        $species,
        $track->{title},
        join(",", @{ $track->{runs} }),

        $exp_name,
        join(",", @{ $track->{samples} }),
        $track->{text},
      );
      print join("\t", @line) . "\n";
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
    This script creates a list of samples, their runs, their names.

    DATABASE CONNECTION
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name

    FILTERS
    --species <str>   : only use tracks for a given species (production_name)
    --antispecies <str> : skip those species
    
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
    "species=s",
    "antispecies=s",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

