use utf8;
package RNAseqDB::DB;

use strict;
use warnings;
use Log::Log4perl qw( :easy );
my $logger = get_logger();

use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);
use base 'RNAseqDB::Schema';

sub add_run {
  my ($self, $run_acc) = @_;
  
  # Try to get the run id if it exists
  my $run_req = $self->resultset('Run')->search({
      run_sra_acc => $run_acc,
  });

  my @run_rows = $run_req->all;
  my $num_run = scalar @run_rows;
  if ($num_run == 1) {
    $logger->debug("Run " . $run_acc . " has 1 id already.");
    return 0;
  }
  
  # Retrieve run data from ENA
  my $run_adaptor = get_adaptor('Run');
  my ($run) = @{ $run_adaptor->get_by_accession($run_acc) };
  
  # Retrieve the experiment and sample ids to create a run
  my $experiment_id = $self->_get_experiment_id($run->experiment());
  my $sample_id = $self->_get_sample_id($run->sample());
  
  if (    defined $experiment_id
      and defined $sample_id) {
    $logger->info("ADDING run " . $run->accession() . "");
    $self->resultset('Run')->create({
        run_sra_acc     => $run->accession(),
        experiment_id   => $experiment_id,
        sample_id       => $sample_id,
        title           => $run->title(),
      });
  } else {
    $logger->warn("An error occured: can't insert the run " . $run_acc);
    return 0;
  }
  
  return 1;
}

sub _get_experiment_id {
  my ($self, $experiment) = @_;
  
  # Try to get the experiment id if it exists
  my $exp_req = $self->resultset('Experiment')->search({
      experiment_sra_acc => $experiment->accession()
  });

  my @exp_rows = $exp_req->all;
  my $num_exp = scalar @exp_rows;
  if ($num_exp == 1) {
    $logger->debug("Experiment " . $experiment->accession() . " has 1 id already.");
    return $exp_rows[0]->experiment_id;
  }
  # Error: there should not be more than one row per experiment
  elsif ($num_exp > 1) {
    $logger->warn("Several experiments found with accession " . $experiment->accession());
    return;
  }
  # Last case: we have to add this experiment
  else {
    my $study_id = $self->_get_study_id($experiment->study());
    
    if (defined $study_id) {
      $logger->info("ADDING experiment " . $experiment->accession() . "");
      my $insertion = $self->resultset('Experiment')->create({
          experiment_sra_acc     => $experiment->accession(),
          title                  => $experiment->title(),
          study_id               => $study_id,
        });
      return $insertion->id();
    }
  }
}

sub _get_study_id {
  my ($self, $study) = @_;
  
  # Try to get the study id if it exists
  my $study_req = $self->resultset('Study')->search({
      study_sra_acc => $study->accession()
  });

  my @study_rows = $study_req->all;
  my $num_study = scalar @study_rows;
  if ($num_study == 1) {
    $logger->debug("Study " . $study->accession() . " has 1 id already.");
    return $study_rows[0]->study_id;
  }
  # Error: there should not be more than one row per study
  elsif ($num_study > 1) {
    $logger->warn("Several studies found with accession " . $study->accession());
    return;
  }
  # Last case: we have to add this study
  else {
    $logger->info("ADDING study " . $study->accession() . "");
    my $insertion = $self->resultset('Study')->create({
        study_sra_acc   => $study->accession(),
        title           => $study->title(),
        abstract        => $study->abstract(),
      });
    return $insertion->id();
  }
}


sub _get_sample_id {
  my ($self, $sample) = @_;
  
  # Try to get the sample id if it exists
  my $sample_req = $self->resultset('Sample')->search({
      sample_sra_acc => $sample->accession()
  });

  my @sample_rows = $sample_req->all;
  my $num_sample = scalar @sample_rows;
  if ($num_sample == 1) {
    $logger->debug("Sample " . $sample->accession() . " has 1 id already.");
    return $sample_rows[0]->sample_id;
  }
  # Error: there should not be more than one row per sample
  elsif ($num_sample > 1) {
    $logger->warn("Several samples found with accession " . $sample->accession());
    return;
  }
  # Last case: we have to add this sample
  else {
    $logger->info("ADDING sample " . $sample->accession() . "");
    my $insertion = $self->resultset('Sample')->create({
        sample_sra_acc    => $sample->accession(),
        title             => $sample->title(),
        description       => $sample->description(),
        taxon_id          => $sample->taxon()->taxon_id(),
      });
    return $insertion->id();
  }
}
1;

__END__


=head1 NAME

RNAseqDB::DB - Interface for the RNAseq DB.


=head1 VERSION

This document describes RNAseqDB::DB version 0.0.1


=head1 SYNOPSIS

    use RNAseqDB::DB;

    # Connect to an RNAseqDB
    my $rdb = RNAseqDB::DB->connect(
      "dbi:mysql:host=$host:port=$port:database=$db",
      $user,
      $password
    );
    
    # Add a run to the database
    $rdb->add_run('SRR000000');


=head1 DESCRIPTION

This module is an object interface for the RNAseqDB. It inherits the RNAseqDB::Schema object, which is a DBIx class.


The purpose of the interface is to simplify the population of the database.


The module logs with Log4perl (easy mode).

=head1 INTERFACE

=over

=item BUILD connect()

  (Inherited from RNAseqDB::Schema)
  Args           : DBI connection arguments
  Function       : create a connection to an RNAseq DB
  Usage:

    my $rdb = RNAseqDB::DB->connect(
      "dbi:mysql:host=$host:port=$port:database=$db",
      $user,
      $password
    );


=item add_run()

  Function       : add an SRA run to the RNAseq DB, as well as any corresponding sample, experiment, and study.
  Arg[1]         : String:  an SRA run accession
  Returntype     : Integer: 0 = run not added, 1 = run added
  Usage:

    # Those are equivalent
    $rdb->add_run('SRR000000');

  NB: the run will not be added if it is not already in the database. It will also not be added if it fails to retrieve the corresponding sample and experiment ids.

=back


=head1 CONFIGURATION AND ENVIRONMENT

RNAseqDB::DB requires no configuration files or environment variables.


=head1 DEPENDENCIES

* Bio::EnsEMBL::ENA (eg-ena)
* Log::Log4perl
* DBIx::Class


=head1 BUGS AND LIMITATIONS

...

=head1 AUTHOR

Matthieu Barba  C<< <mbarba@ebi.ac.uk> >>

