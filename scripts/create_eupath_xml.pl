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
  my $exps = get_eupath_experiments_species($db, $species);
  if (@$exps == 0) {
    warn "No experiments to export for $species\n";
    next;
  }

  $exps = add_alignments_metadata($exps, $opt{alignments}, $species);

  make_eupath_xml($exps, $species, $opt{out}, \%opt);
}

###############################################################################
# SUBS

sub add_alignments_metadata {
  my ($exps, $aln_dir, $species) = @_;
  return $exps if not $aln_dir;

  # Get alignment metadata for each experiment
  my %runs;
  my @metadata_files = glob("$aln_dir/$species/*/*/metadata.json");
  for my $json_path (@metadata_files) {
    open my $json, "<", $json_path;
    my $line = <$json>;
    close $json;
    my $meta = decode_json($line);
    $runs{ $meta->{sraQueryString} } = $meta;
  }

  # Match all the runs to each exp
  EXP: for my $exp (@$exps) {
    SAMPLE: for my $sample (@{ $exp->{samples} }) {
      my $exp_runs = $sample->{runs};

      # Check each exp_run
      my ($is_paired, $is_stranded) = (0, 0);
      my ($is_not_paired, $is_not_stranded) = (0, 0);

      for my $exp_run (@$exp_runs) {
        if (exists $runs{ $exp_run }) {
          my $match_run = $runs{ $exp_run };
          if ($match_run->{hasPairedEnds}) { $is_paired++ } else { $is_not_paired++ }
          if ($match_run->{isSrandSpecific}) { $is_stranded++ } else { $is_not_stranded++ }
          delete $runs{ $exp_run };
        }
        else {
          warn("Missing run $exp_run in alignment\n");
          delete $runs{ $exp_run };
          next SAMPLE;
        }
      }

      # Check that the experiment is homogeneous
      if ($is_paired * $is_not_paired == 0 and $is_paired + $is_not_paired > 0) {
        $exp->{is_paired} = $is_paired ? 1 : 0;
      } else {
          warn("Runs are not homogeneously paired: $is_paired vs $is_not_paired (for @$exp_runs)\n");
      }
      if ($is_stranded * $is_not_stranded == 0 and $is_stranded + $is_not_stranded > 0) {
        $exp->{is_stranded} = $is_stranded ? 1 : 0;
      } else {
          warn("Runs are not homogeneously stranded: $is_stranded vs $is_not_stranded (for @$exp_runs)\n");
      }
    }
  }

  # Check if there is any remaining runs aligned but not in the db
  my @runs_left = sort keys %runs;
  if (@runs_left) {
    my $nruns = @runs_left;
    print STDERR "There are $nruns runs aligned that could not be found in the database: " . join(", ", @runs_left) . "\n";
  }

  return $exps;
}

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
  my %done_exp;
  for my $b ($bundles->all) {
    # Experiment name = study_name
    my ($study_name, $study) = get_study($b);
    my $exp_name = $study_name;
    $exp_name =~ s/[() -]+/_/g;
    $exp_name =~ s/_+$//;
    next if exists $done_exp{$exp_name};

    # Get samples
    my @samples = get_samples($b);

    my $exp = {
      study_id => $study->study_sra_acc,
      name => $exp_name,
      title => $exp_name . " " . $study->title,
      abstract => $study->abstract,
      date => simple_date($study->date),
      samples => \@samples,
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
  $str =~ s/[\/,]//g; # Remove commas and slashes
  $str =~ s/_+$|^_+//g;

  return $str;
}

sub make_eupath_xml {
  my ($hubs, $species, $output_dir, $opt) = @_;
  
  my $exp_dir = catfile($output_dir, 'experiments');
  my $aconfig_dir = catfile($output_dir, 'analysis_configs');
  my $presenter_dir = catfile($output_dir, 'presenters');
  make_eupath_experiment_xml($hubs, $species, $exp_dir);
  make_eupath_analysis_config_xml($hubs, $species, $aconfig_dir);
  make_eupath_presenter_xml($hubs, $species, $presenter_dir, $opt);
}

sub make_eupath_experiment_xml {
  my ($hubs, $species, $output_dir) = @_;

  make_path($output_dir);

  # Write the species experiment xml
  my $sp_file = catfile($output_dir, $species . ".xml");
  print_experiments_species_file($hubs, $sp_file);

  # Write each experiment xml
  my $sp_dir = catdir($output_dir, $species);
  make_path($sp_dir);
  for my $exp (@$hubs) {
    # Write to the experiment file
    print_experiment_file($species, $sp_dir, $exp);
  }

  return;
}

sub print_experiments_species_file {
  my ($hubs, $sp_file) = @_;

  my $output = new IO::File(">$sp_file");
  my $wr = new XML::Writer( OUTPUT => $output, DATA_MODE => 'true', DATA_INDENT => 2 );
  $wr->startTag("datasets");

  for my $exp (@$hubs) {
    $wr->startTag("dataset", class => "rnaSeqExperiment");
    add_prop($wr, "projetName", '$$projectName$$');
    add_prop($wr, "organismAbbrev", '$$organismAbbrev$$');
    add_prop($wr, "name", $exp->{name});

    # TODO
    # version (date)
    add_prop($wr, "version", $exp->{date});
    add_prop($wr, "limitNU", 5);  # Default value -k from hisat2
    add_prop($wr, "hasPairedEnds", $exp->{is_paired} ? "true" : "false");
    add_prop($wr, "isStrandSpecific", $exp->{is_stranded} ? "true" : "false");
    add_prop($wr, "alignWithCdsCoordinates", "false");
    $wr->endTag("dataset");
  }
  $wr->endTag("datasets");
  $wr->end();

  return $sp_file;
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

sub make_eupath_analysis_config_xml {
  my ($hubs, $species, $output_dir) = @_;

  make_path($output_dir);

  # Write each analysis xml
  my $sp_dir = catdir($output_dir, $species);
  make_path($sp_dir);
  for my $exp (@$hubs) {
    # Write to the analysis file
    print_analysis_file($species, $sp_dir, $exp);
  }

  return;
}

sub print_analysis_file {
  my ($species, $sp_dir, $exp) = @_;

  my $exp_name = $exp->{name};
  my $exp_title = $exp->{title};
  my $exp_file = catfile($sp_dir, $exp_name . ".xml");
    
  # Init XML
  my $output = new IO::File(">$exp_file");
  my $wr = new XML::Writer( OUTPUT => $output, DATA_MODE => 'true', DATA_INDENT => 2 );
  $wr->startTag("xml");
  $wr->startTag("step", class => "ApiCommonData::Load::RnaSeqAnalysis");

  # Set up name
  $wr->startTag("property", name => "profileSetName", value => $exp_title);
  $wr->endTag("property");

  # List samples
  $wr->startTag("property", name => "samples");
  for my $sample (@{ $exp->{samples} }) {
    for my $run ( @{ $sample->{runs} }) {
      my $value = $sample->{name} . "|" . $run;
      add_value($wr, $value);
    }
  } 
  $wr->endTag("property");

  # Use alignment metadata here
  $exp->{is_strand_specific} = $exp->{is_stranded};
  $wr->startTag("property", name => "isStrandSpecific", value => $exp->{is_strand_specific});
  $wr->endTag("property");

  # End XML
  $wr->endTag("step");
  $wr->endTag("xml");
  $wr->end;
}

sub make_eupath_presenter_xml {
  my ($hubs, $species, $output_dir, $opt) = @_;

  make_path($output_dir);

  # Write each presenter xml
  my $sp_dir = catdir($output_dir, $species);
  make_path($sp_dir);
  for my $exp (@$hubs) {
    # Write to the presenter file
    print_presenter_file($species, $sp_dir, $exp, $opt);
  }

  return;
}

sub print_presenter_file {
  my ($species, $sp_dir, $exp, $opt) = @_;

  my $exp_name = $exp->{name};
  my $exp_file = catfile($sp_dir, $exp_name . ".xml");
    
  # Init XML
  my $output = new IO::File(">$exp_file");
  my $wr = new XML::Writer( OUTPUT => $output, DATA_MODE => 'true', DATA_INDENT => 2 );
  $wr->startTag("datasetPresenter", name => $exp_name);

  my $cdata = 1;
  add_tag($wr, "displayName", $exp->{title}, $cdata);
  add_tag($wr, "shortDisplayName", $exp_name, $cdata);
  add_tag($wr, "shortAttribution", "", $cdata);
  add_tag($wr, "summary", "", $cdata);
  add_tag($wr, "description", $exp->{abstract}, $cdata);

  add_tag($wr, "protocol", "");
  add_tag($wr, "caveat", "");
  add_tag($wr, "acknowledgement", "");
  add_tag($wr, "releasePolicy", "");

  # History
  $wr->startTag('history', buildNumber => $opt->{build} ? $opt->{build} : "");
  $wr->endTag('history');

  # Contacts
  add_tag($wr, "primaryContactId", "");
  add_tag($wr, "contactId", "");  # Can be repeated

  # Link
  $wr->startTag('link');
  add_tag($wr, "text", "SRA project id");
  add_tag($wr, "url", "https://www.ncbi.nlm.nih.gov/sra/?term=" . $exp->{study_id});
  $wr->endTag('link');

  add_tag($wr, "pubmedid", "");

  # Template
  $wr->startTag('templateInjector', className => "org.apidb.apicommon.model.datasetInjector.RNASeq");
  add_prop($wr, "switchStrandsGBrowse", "false");
  add_prop($wr, "switchStrandsProfiles", "false");
  add_prop($wr, "isEuPathDBSite", "true");
  add_prop($wr, "isAlignedToAnnotatedGenome", "true");
  add_prop($wr, "isTimeSeries", "false"); # TODO
  add_prop($wr, "showIntronJunctions", "true");
  add_prop($wr, "includeInUnifiedJunctions", "true");
  add_prop($wr, "hasMultipleSamples", "true");  # TODO
  add_prop($wr, "hasFishersExactTestData", "false");
  add_prop($wr, "optionalQuestionDescription", "");
  # Graph
  add_prop($wr, "graphType", "line");
  add_prop($wr, "graphColor", "brown");
  add_prop($wr, "graphForceXLabelsHorizontal", "");
  add_prop($wr, "graphBottomMarginSize", "");
  add_prop($wr, "graphSampleLabels", "");
  add_prop($wr, "graphPriorityOrderGrouping", "0");
  add_prop($wr, "graphXAxisSamplesDescription", "<![CDATA[]]>");
  add_prop($wr, "isDESeq", "false");
  add_prop($wr, "isDEGseq", "false");
  add_prop($wr, "includeProfileSimilarity", "false");
  add_prop($wr, "profileTimeShift", "");

  $wr->endTag('templateInjector');


  # End XML
  $wr->endTag("datasetPresenter");
  $wr->end;
}

sub add_prop {
  my ($wr, $name, $value) = @_;

  $wr->startTag("prop", name => $name);
  $wr->characters($value);
  $wr->endTag("prop");
}

sub add_value {
  my ($wr, $value) = @_;

  $wr->startTag("value");
  $wr->characters($value);
  $wr->endTag("value");
}

sub add_tag {
  my ($wr, $tag, $value, $cdata) = @_;

  $wr->startTag($tag);
  $value = "![CDATA[$value]]" if ($value and $cdata);
  $wr->characters($value);
  $wr->endTag($tag);
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

    RNASEQ FILES
    --alignments <path>: path to a directory with RNA-Seq alignments, with metadata json files
    
    FILTERS
    --species <str>   : only use tracks for a given species (production_name)
    --antispecies <str> : skip those species
    
    ACTIONS
    --out <path>      : create xml files in this directory

    PRESENTER DATA
    --build <str>     : build that the dataset is part of
    
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
    "alignments=s",
    "species=s",
    "antispecies=s",
    "out=s",
    "build=s",
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

