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

use Bio::EnsEMBL::RNAseqDB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

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
  my @exps = get_eupath_experiments_species($db, $species);
  if (@exps == 0) {
    warn "No experiments to export for $species";
    next;
  }

  make_eupath_xml(\@exps, $species, $opt{out});
}

###############################################################################
# SUBS

sub get_eupath_experiments_species {
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
              'sra_tracks' => { 'run' => { 'experiment' => 'study' } },
            },
          ],
        },
      },
    }
  );

  # Get experiment data
  my @experiments;
  for my $b ($bundles->all) {
    # Experiment name = study_name
    my $study = get_study($b);
    my $exp_name = $study;
    $exp_name =~ s/[() -]+/_/g;
    $exp_name =~ s/_+$//;

    # Get samples
    my @samples = get_samples($b);

    my $exp = {
      name => $exp_name,
      samples => \@samples,
    };

    push @experiments, $exp;
  }
  
  return @experiments;
}

sub get_study {
  my ($bundle) = @_;

  my %study;
  for my $bt ($bundle->bundle_tracks->all) {
    my $track = $bt->track;
    for my $st ($track->sra_tracks->all) {
      my $run = $st->run;
      $study{ $run->experiment->study->study_sra_acc }++;
    }
  }

  if (keys(%study) == 1) {
    my ($study_id) = keys(%study);
    return $study_id;
  } else {
    my @studies = keys(%study);
    my $study_id = $studies[0] . "_" . $studies[-1];
    warn("More thant one study for the bundle: $study_id");
    return $study_id;
  }
}

sub get_samples {
  my ($bundle) = @_;

  my @samples;
  for my $bt ($bundle->bundle_tracks->all) {
    my $track = $bt->track;
    my @runs;
    for my $st ($track->sra_tracks->all) {
      push @runs, $st->run->run_sra_acc;
    }
    push @samples, {
      name => clean_name($track->title_manual || $track->title_auto || $track->merge_id),
      runs => \@runs,
    };
  }
  return @samples;
}

sub clean_name {
  my ($str) = @_;

  $str =~ s/[ ().]/_/g;
  $str =~ s/_+$|^_+//g;

  return $str;
}

sub make_eupath_xml {
  my ($hubs, $species, $output_dir) = @_;

  print("Work on $species\n");

  make_path($output_dir);
  my $sp_dir = catdir($output_dir, $species);
  make_path($sp_dir);


  for my $exp (@$hubs) {
    # Write to the experiment file
    print_experiment_file($species, $sp_dir, $exp);
  }

  return;
}

sub print_experiment_file {
  my ($species, $sp_dir, $exp) = @_;

  my $exp_name = $exp->{name};
  my $exp_file = catfile($sp_dir, $exp_name . ".xml");
    
  my $output = new IO::File(">$exp_file");
  my $wr = new XML::Writer( OUTPUT => $output, DATA_MODE => 'true', DATA_INDENT => 2 );
  $wr->startTag("datasets");

  for my $sample (@{ $exp->{samples} }) {
    $wr->startTag("dataset", class => "rnaSeqSample_QuerySRA");
    add_prop($wr, "organismAbbrev", $species);
    add_prop($wr, "experimentName", $exp_name);
    add_prop($wr, "sampleName", $sample->{name});
    add_prop($wr, "sraQueryString", join(",", @{ $sample->{runs} }));
    $wr->endTag("dataset");
  } 

  $wr->endTag("datasets");
  $wr->end;
}

sub add_prop {
  my ($wr, $name, $value) = @_;

  $wr->startTag("prop", name => $name);
  $wr->characters($value);
  $wr->endTag("prop");
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
    This script creates a list of xml files for RNA-Seq data for EupathDB.

    DATABASE CONNECTION
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    FILTERS
    --species <str>   : only use tracks for a given species (production_name)
    --antispecies <str> : skip those species
    
    ACTIONS
    --out <path>      : create xml files in this directory
    
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
    "out=s",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --out") if not $opt{out};
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

