#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case);
use Readonly;
use autodie;

use Data::Dumper;
use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

Readonly my $RUN_REGEX    => qr{^(.RR\d{6,})$};
Readonly my $EXP_REGEX    => qr{^(.RX\d{6,})$};
Readonly my $STUDY_REGEX  => qr{^(.RP\d{6,})$};
Readonly my $SAMPLE_REGEX => qr{^(.RS\d{6,})$};

###############################################
## MAIN
my %opt = %{ opt_check() };
my $sra_ids_aref = get_sra_ids($opt{input});
my $srrs = extract_srr($sra_ids_aref);
print_srrs($srrs);

###############################################
# SUBS
sub get_sra_ids {
  my $inpath = shift;
  
  my @sra_list = ();
  open my $SRA, '<', $inpath;
  while (my $id = <$SRA>) {
    chomp $id;
    next if $id eq '';
    push @sra_list, $id;
  }
  close $SRA;
  return \@sra_list;
}

sub extract_srr {
  my $sra_ids_aref = shift;
  
  my $srrs = {};
  for my $id (@$sra_ids_aref) {
    if ($id =~ /$RUN_REGEX/) {
      $srrs = get_run_data($id, $srrs);
    }
    elsif ($id =~ /$EXP_REGEX/) {
      $srrs = get_experiment_data($id, $srrs);
    }
    elsif ($id =~ /$STUDY_REGEX/) {
      $srrs = get_study_data($id, $srrs);
    }
    else {
      $logger->info("Unrecognized id: $id\n");
    }
    # Don't spam!
    #sleep 1;
  }
  
  return $srrs;
}

sub add_run {
  my ($srrs, $run) = @_;
  
  if ( not is_rnaseq($run) ) {
    $logger->info("SKIP " . $run->accession());
    return $srrs;
  }
  $logger->info("OK " . $run->accession());
  
  my $study_id  = $run->study()->accession();
  my $exp_id    = $run->experiment()->accession();
  my $run_id    = $run->accession();
  my $pubmed_id = get_pubmed($run);
  
  for my $sample (@{ $run->samples() }) {
    my $sample_id = $sample->accession();
    $srrs->{$study_id}->{$exp_id}->{$sample_id}->{$run_id} = $pubmed_id;
  }
  
  
  return $srrs;
}

sub get_pubmed {
  my $run = shift;
  
  my %pubmed = ();
  %pubmed = ( %pubmed, %{ has_pubmed($run->study()) } );
  %pubmed = ( %pubmed, %{ has_pubmed($run->experiment()) } );
  %pubmed = ( %pubmed, %{ has_pubmed($run) } );
  
  return join(',', sort keys %pubmed);
}

sub has_pubmed {
  my $obj = shift;
  my $links = $obj->links();
  
  my %pubmed = ();
  for my $link (@$links) {
    my $xref = $link->{XREF_LINK};
    if (defined $xref and defined $xref->{DB} and $xref->{DB} eq 'pubmed') {
      $pubmed{ $xref->{ID} }++;
    }
  }
  return \%pubmed;
}

sub is_rnaseq {
  my $run = shift;
  
  # Check study type
  my $study_type = $run->study()->type();
  if ($study_type eq 'Transcriptome Analysis') {
    return 1;
  }
  
  # Otherwise, check experiment type (in case the study is mixed)
  my $design = $run->experiment()->design();
  my $source = $design->{LIBRARY_DESCRIPTOR}->{LIBRARY_SOURCE};
  if ($source eq 'TRANSCRIPTOMIC') {
    return 1;
  }
  
  # Not RNAseq then
  return 0;
}

sub get_run_data {
  my $id   = shift;
  my $srrs = shift;
  $logger->info("Get data for run $id\n");
  my $run_adaptor = get_adaptor('Run');
  my ($run) = @{ $run_adaptor->get_by_accession($id) };
  
  $srrs = add_run($srrs, $run);
  return $srrs;
}

sub get_experiment_data {
  my $id = shift;
  my $srrs = shift;
  $logger->info("Get data for experiment $id\n");
  my $experiment_adaptor = get_adaptor('Experiment');
  my ($experiment) = @{ $experiment_adaptor->get_by_accession($id) };
  
  # Get all runs
  for my $run (@{ $experiment->runs() }) {
    $srrs = add_run($srrs, $run);
  }
  return $srrs;
}

sub get_study_data {
  my $id = shift;
  my $srrs = shift;
  $logger->info("Get data for study $id\n");
  my $study_adaptor = get_adaptor('Study');
  my ($study) = @{ $study_adaptor->get_by_accession($id) };
  
  # Get all runs
  for my $run (@{ $study->runs() }) {
    $srrs = add_run($srrs, $run);
  }
  return $srrs;
}

sub print_srrs {
  my $srrs = shift;
  
  foreach my $study_id (sort keys %$srrs) {
    my $studies = $srrs->{$study_id};
    foreach my $exp_id (sort keys %$studies) {
      my $exps = $studies->{$exp_id};
      foreach my $sample_id (sort keys %$exps) {
        my $sample = $exps->{$sample_id};
        foreach my $run_id (sort keys %$sample) {
          my $pubmed_id = $sample->{$run_id};
          printf "%s\t%s\t%s\t%s\t%s\n", $study_id, $exp_id, $sample_id, $run_id, $pubmed_id;
        }
      }
    }
  }
}

###############################################
# COMMAND LINE USAGE
sub usage
{
    my $error = shift;
    my $help = '';
    if ($error) {
        $help = "[ $error ]\n";
    }
    $help .= <<'EOF';
    This script takes a list of SRA identifier and prints a list of all the corresponding SRR, SRX, SRP.
    
    --input <path> : list of SRP, SRX, or SRR identifiers.
    
    --verbose      : print more info
    --help         : print this help
    
EOF
    print STDERR "$help\n";
    exit(1);
}

# Get the command-line arguments and check for the mandatory ones
sub opt_check
{
    my %opt = ();
    GetOptions(\%opt,
        "input=s",
        "verbose",
        "help|h"
    );

    usage()               if $opt{help};
    usage("Need --input") if not $opt{input};
    Log::Log4perl->easy_init($INFO) if $opt{verbose};
    
    return \%opt;
}

__END__

