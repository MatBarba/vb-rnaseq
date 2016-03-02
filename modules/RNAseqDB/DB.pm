use utf8;
package RNAseqDB::DB;

use strict;
use warnings;
use List::Util qw( first );
use Log::Log4perl qw( :easy );
my $logger = get_logger();
use Data::Dumper;

use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);
use base 'RNAseqDB::Schema';

sub add_run {
  my ($self, $run_acc) = @_;
  return 0 if not defined $run_acc or $run_acc =~ /^\s*$/;
  
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
  
  if (not defined $run) {
    $logger->warn("Run impossible to get: " . $run_acc);
    return 0;
  }
  
  # Retrieve the experiment and sample ids to create a run
  my $sample_id = $self->_get_sample_id($run->sample());
  if (not defined $sample_id) {
    $logger->warn("Can't insert the run $run_acc: no sample_id returned");
    return 0;
  }
  my $experiment_id = $self->_get_experiment_id($run->experiment());
  my $submitter = $self->_get_run_submitter($run);
  
  if (    defined $experiment_id
      and defined $sample_id) {
    $logger->info("ADDING run " . $run->accession() . "");
    $self->resultset('Run')->create({
        run_sra_acc     => $run->accession(),
        experiment_id   => $experiment_id,
        sample_id       => $sample_id,
        title           => $run->title(),
        submitter       => $submitter,
      });
  } else {
    $logger->warn("An error occured: can't insert the run " . $run_acc);
    return 0;
  }
  
  return 1;
}

sub _get_run_submitter {
  my ($self, $run) = @_;
  
  my $identifiers = $run->identifiers()->{SUBMITTER_ID};
  return $identifiers->{namespace};
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
    
    # All is ok? Insert!
    my $attribs_aref = $sample->attributes();
    $attribs_aref = [$attribs_aref] if ref($attribs_aref) eq 'HASH';
    my @strain_attrib = grep {
      lc($_->{TAG}) eq 'strain' and $_->{VALUE} ne 'missing'
    } @$attribs_aref;
    my $strain = join(',', map { $_->{VALUE} } @strain_attrib);
    my $taxon_id = $sample->taxon()->taxon_id();
    
    # Wait, we still have to filter out wrong taxa...
    if (not $self->_is_ok_sample_taxon( $taxon_id, $strain )) {
      return;
    }
    
    $logger->info("ADDING sample " . $sample->accession() . "");
    my $insertion = $self->resultset('Sample')->create({
        sample_sra_acc    => $sample->accession(),
        title             => $sample->title(),
        description       => $sample->description(),
        taxon_id          => $taxon_id,
        strain            => $strain
      });
    return $insertion->id();
  }
}

sub _is_ok_sample_taxon {
  my ($self, $taxon_id, $strain) = @_;
  return if not defined $taxon_id;
  
  my $name = $self->_get_prod_name($taxon_id, $strain);
  
  return defined $name;
}

sub _get_prod_name {
  my ($self, $taxon_id, $strain) = @_;
  $strain ||= '';
  
  my $names = $self->_get_production_names();
  
  # First try, with the couple taxon_id and strain
  my $key = $taxon_id . '__' . $strain;
  
  if (defined $names->{ $key }) {
    return $names->{ $key };
  }
  # Second try, with only the taxon_id
  elsif (defined $names->{ $taxon_id }) {
    $logger->info("Selecting taxon with only taxid: $taxon_id ($names->{ $taxon_id })");
    return $names->{ $taxon_id };
  }
  else {
    $logger->info("Rejected taxon with taxid: $taxon_id");
    return;
  }
}

sub _get_production_names {
  my $self = shift;
  
  if (not defined $self->{production_names}) {
   $self->_load_production_names(); 
  }
  return $self->{production_names};
}

sub _load_production_names {
  my ($self) = @_;
  
  my $species_req = $self->resultset('Species')->search({
      status  => 'ACTIVE',
    });
  my @lines = $species_req->all;
  
  my %names = ();
  for my $line (@lines) {
    my $strain = $line->strain;
    $strain ||= '';
    my $taxon_id = $line->taxon_id;
    $taxon_id ||= '';
    $logger->warn("Taxon without taxon_id: " . $line->production_name) if not defined $taxon_id;
    my $key = $taxon_id . '__' . $strain;
    $names{ $key } = $line->production_name;
    $names{ $taxon_id } = $line->production_name;
  }
  
  $self->{production_names} = \%names;
}

sub add_species {
  my ($self, $species_href) = @_;
  
  my $nname   = $species_href->{production_name};
  my $ntax    = $species_href->{taxon_id};
  my $nstrain = $species_href->{strain};
  $nstrain ||= '';
  
  if (    defined $nname
      and defined $ntax
  ) {
    # Check that the taxon doesn't already exists
    my $currents = $self->resultset('Species')->search({
        production_name => $nname
      });
    
    my ($current_sp) = $currents->all;
    
    # Already exists? Check that it is the same
    if (defined $current_sp) {
      my $cname   = $current_sp->production_name;
      my $ctax    = $current_sp->taxon_id;
      my $cstrain = $current_sp->strain;
      $cstrain ||= '';
      
      if (   (defined $ntax and not defined $ctax)
          or (defined $ctax and not defined $ntax)
          or ($ctax != $ntax)
      ) {
        $logger->warn("WARNING: Trying to add an existing name $cname with a different taxon_id: $ntax / $ctax");
      }
      elsif ( (defined $nstrain and not defined $cstrain)
          or  (defined $cstrain and not defined $nstrain)
          or  (defined $cstrain and defined $nstrain and $cstrain ne $nstrain)
      ) {
        $logger->warn("WARNING: Trying to add an existing name $cname with a different strain: $nstrain / $cstrain");
      }
      else {
        $logger->debug("Species $cname already in the database");
      }
      return 0;
      
    # Ok? Add it
    } else {
      $self->resultset('Species')->create( $species_href );
      $logger->debug("NEW SPECIES added: $nname");
      return 1;
    }
  }
   else {
    return 0;
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

=item add_species()

  function       : add a species line to the species table.
  arg[1]         : production name
  arg[2]         : taxon name
  arg[3]         : strain name
  returntype     : integer: 0 = not added, 1 = added
  usage:

    # those are equivalent
    $rdb->add_species('anopheles_stephensii', 30069, 'indian');

=item get_prod_name()

  function       : extract the production name for a taxon_id + strain couple.
  returntype     : String, production name
  usage:

    # those are equivalent
    my $name = $rdb->get_prod_name(30069, 'Indian');
    
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

