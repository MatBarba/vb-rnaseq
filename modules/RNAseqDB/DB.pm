use utf8;
package RNAseqDB::DB;

use strict;
use warnings;
use List::Util qw( first );
use Log::Log4perl qw( :easy );
my $logger = get_logger();
use Data::Dumper;
use Readonly;

use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);
use base 'RNAseqDB::Schema';

my Readonly $SRP_REGEX = qr{[SED]RP\d+};
my Readonly $SRX_REGEX = qr{[SED]RX\d+};
my Readonly $SRR_REGEX = qr{[SED]RR\d+};
my Readonly $SRS_REGEX = qr{[SED]RS\d+};

sub add_sra {
  my ($self, $sra_acc) = @_;
  
  if ($sra_acc =~ $SRP_REGEX) {
    $self->add_study( $sra_acc );
  }
  elsif ($sra_acc =~ $SRX_REGEX) {
    $self->add_experiment( $sra_acc );
  }
  elsif ($sra_acc =~ $SRR_REGEX) {
    $self->add_run( $sra_acc );
  }
  elsif ($sra_acc =~ $SRS_REGEX) {
    $self->add_sample( $sra_acc );
  }
}

sub add_runs_from() {
  my ($self, $acc, $table) = @_;
  
  return 0 if not defined $acc or $acc =~ /^\s*$/;
  
  # Try to get the id if it exists
  my $table_class = ucfirst $table;
  my $key = $table . '_sra_acc';
  my $req = $self->resultset( $table_class )->search({
      $key => $acc,
  });

  my @rows = $req->all;
  my $num = scalar @rows;
  if ($num == 1) {
    $logger->debug("$table " . $acc . " has 1 id already.");
    return 0;
  }
 
  # Retrieve data from ENA
  my $adaptor = get_adaptor( $table );
  my ($sra) = @{ $adaptor->get_by_accession($acc) };
  
  if (not defined $sra) {
    $logger->warn("$table impossible to get: " . $acc);
    return 0;
  }
  
  # Add each one individually
  my $total = 0;
  for my $run (@{ $sra->runs() }) {
    $self->add_run( $run->accession() );
    $total++;
  }
  return $total;
}

sub add_study {
  my ($self, $study_acc) = @_;
  return $self->add_runs_from($study_acc, 'study');
}

sub add_experiment {
  my ($self, $experiment_acc) = @_;
  return $self->add_runs_from($experiment_acc, 'experiment');
}

sub add_sample {
  my ($self, $sample_acc) = @_;
  return $self->add_runs_from($sample_acc, 'sample');
}

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
    
    # Get strain
    my @strain_attrib = grep {
      lc($_->{TAG}) eq 'strain' and $_->{VALUE} ne 'missing'
    } @$attribs_aref;
    my $strain = join(',', map { $_->{VALUE} } @strain_attrib);
    
    # Get biosample accession
    my $identifiers_aref = $sample->identifiers()->{EXTERNAL_ID};
    $identifiers_aref = [$identifiers_aref] if not ref($identifiers_aref) eq 'ARRAY';
    my $biosample_href = first { $_->{namespace} eq 'BioSample' } @$identifiers_aref;
    my $biosample_acc = $biosample_href->{content};
    
    # Get taxon_id
    my $taxon_id = $sample->taxon()->taxon_id();
    
    # Get the correct species_id
    my $species_id = $self->_get_species_id($taxon_id, $strain);
    
    # No species id? Failed to add
    if (not defined $species_id) {
      $logger->info("Skip sample because the species ($taxon_id, $strain) could not be found in the species table");
      return;
    }
    
    $logger->info("ADDING sample " . $sample->accession() . "");
    my $insertion = $self->resultset('Sample')->create({
        sample_sra_acc    => $sample->accession(),
        title             => $sample->title(),
        description       => $sample->description(),
        taxon_id          => $taxon_id,
        strain            => $strain,
        species_id        => $species_id,
        biosample_acc     => $biosample_acc,
      });
    return $insertion->id();
  }
}

sub _get_species_id {
  my ($self, $taxon_id, $strain) = @_;
  $strain ||= '';
  
  my $species_href = $self->_get_species_ids();
  return if not defined $species_href;
  my $sp_taxons = $species_href->{ $taxon_id };
  
  if (defined $sp_taxons) {
    # First try, with the couple taxon_id and strain
    if(defined $sp_taxons->{ $strain }) {
      return $sp_taxons->{ $strain };
    }

    # Second try: try to find the species.strain name in the sample.strain name
    my @sp_strains = keys %$sp_taxons;
    my @found_sp_strains = ();
    for my $sp_strain (@sp_strains) {
      next if $sp_strain eq '';
      # Can we find the strain name?
      if ($strain =~ /$sp_strain/) {
        push @found_sp_strains, $sp_strain;
      }
    }

    # Found 1 match?
    my $sp_match = scalar @found_sp_strains;
    if ($sp_match == 1) {
      my $sp_strain = $found_sp_strains[0];
      $logger->info("WARNING: Automatically matched the strain $strain to $sp_strain ($sp_taxons->{ $sp_strain })");
      return $sp_taxons->{ $sp_strain };
    }
    elsif ($sp_match > 1) {
      $logger->warn("WARNING: Several species match the strain name: $taxon_id, $strain");
      return;
    }
    else {
      # Last try, match with only the taxon_id
      my @species_id_list = map { $sp_taxons->{$_} } sort keys %$sp_taxons;
      my %species_ids = map { $_ => 1 } @species_id_list;

      # Found only 1 possible species_id for this taxon_id?
      my $sp_ids_match = scalar(keys %species_ids);
      
      if ($sp_ids_match == 1) {
        $logger->info("Matched species: $taxon_id, $strain => $species_id_list[0]");
        return $species_id_list[0];
      }
      # Several possibilities?
      elsif ($sp_ids_match > 1) {
        my $sp_list = join(', ', @species_id_list);
        $logger->warn("WARNING: Several species match the taxon_id: $taxon_id, $strain ($sp_list). Using $species_id_list[0] (please check!)");
        return $species_id_list[0];
        return;
      }
      else {
        $logger->info("Rejected species, strain is not found in the species table: $taxon_id, $strain");
        return;
      }
    }
  }
  else {
    $logger->warn( "WARNING: Taxon_id is not defined in the species table: $taxon_id ($strain)" );
    return;
  }
}

sub _get_species_ids {
  my $self = shift;
  
  if (not defined $self->{species_ids}) {
   $self->_load_species(); 
  }
  return $self->{species_ids};
}

sub _load_species {
  my ($self) = @_;
  
  my $species_req = $self->resultset('Species')->search({
      status  => 'ACTIVE',
    });
  my @lines = $species_req->all;
  if (@lines == 0) {
    $logger->warn("WARNING: the species table appears to be empty");
    return;
  }
  
  my %species_id = ();
  
  for my $line (@lines) {
    my $strain = $line->strain;
    $strain ||= '';
    my $taxon_id = $line->taxon_id;
    $taxon_id ||= '';
    $logger->warn("Taxon without taxon_id: " . $line->production_name) if not defined $taxon_id;
    my $key = $taxon_id . '__' . $strain;
    $species_id{ $taxon_id }{ $strain } = $line->species_id;
  }
  
  $self->{species_ids} = \%species_id;
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
        $logger->warn("WARNING: Adding an existing name $cname with a different taxon_id: $ntax / $ctax (is it an alias?)");
      }
      elsif ( (defined $nstrain and not defined $cstrain)
          or  (defined $cstrain and not defined $nstrain)
          or  (defined $cstrain and defined $nstrain and $cstrain ne $nstrain)
      ) {
        $logger->warn("WARNING: Adding an existing name $cname with a different strain: $nstrain / $cstrain (is it an alias?)");
      }
      else {
        $logger->debug("Species $cname already in the database");
        return 0;
      }
      $self->resultset('Species')->create( $species_href );
      return 1;
      
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

