use utf8;
package RNAseqDB::Species;
use Moose::Role;

use strict;
use warnings;
use List::Util qw( first );
use JSON;
use Perl6::Slurp;
use Log::Log4perl qw( :easy );

my $logger = get_logger();
use Data::Dumper;
use Readonly;
use Try::Tiny;

use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);

sub _get_species_id {
  my ($self, $species_href) = @_;
  my $taxid = $species_href->{taxon_id};
  my $name = $species_href->{binomial_name};
  delete $species_href->{taxon_id};
  delete $species_href->{binomial_name};
  
  if (not defined $taxid) {
    $logger->warn("WARNING: new species has no taxon_id");
    return;
  }
  
  # Try to get the species id if it exists
  my $species_req = $self->resultset('Species')->search({
      taxon_id => $taxid,
  });

  my @species_rows = $species_req->all;
  my $num_species = scalar @species_rows;
  if ($num_species == 1) {
    $logger->debug("Species $taxid has 1 id already.");
    return $species_rows[0]->species_id;
  }
  # Error: there should not be more than one row per species
  elsif ($num_species > 1) {
    $logger->warn("Several species found with taxid $taxid");
    return;
  }
  # Last case: we have to add this species
  else {
    my $insertion = $self->resultset('Species')->create({
        taxon_id        => $taxid,
        binomial_name   => $name,
      });
    $name ||= '';
    $logger->info("NEW SPECIES added: $taxid, $name");
    return $insertion->id();
  }
  return;
}

sub add_species {
  my ($self, $species_href) = @_;
  
  my $nname     = $species_href->{production_name};
  my $nstrain   = $species_href->{strain};
  my $nassembly = $species_href->{assembly};
  $nstrain ||= '';
  
  my $species_id = $self->_get_species_id( $species_href );
  if (not defined $species_id) {
    $logger->warn("WARNING: Couldn't get the species id for $nname, $nstrain");
    return 0;
  }
  $species_href->{species_id} = $species_id;
  
  if (defined $nname) {
    # Check that the taxon doesn't already exists
    my $currents = $self->resultset('Strain')->search({
        production_name => $nname
      });
    
    my ($current_sp) = $currents->all;
    
    # Already exists? Check that it is the same
    if (defined $current_sp) {
      $logger->debug("Strain with name $nname already in the database");
      return 0;
    }
      
    # Ok? Add it
    else {
      $self->resultset('Strain')->create( $species_href );
      $logger->debug("NEW STRAIN added: $nname, $nstrain, $nassembly");
      return 1;
    }
  }
   else {
     $logger->warn("WARNING: no production_name given");
    return 0;
  }
}

1;


=head1 NAME

RNAseqDB::Species - Species role for the RNAseq DB


=head1 VERSION

This document describes RNAseqDB::Species version 0.0.1


=head1 SYNOPSIS

    use RNAseqDB::DB;

    # Connect to an RNAseqDB
    my $rdb = RNAseqDB::DB->connect(
      "dbi:mysql:host=$host:port=$port:database=$db",
      $user,
      $password
    );
    
    # Prepare the species table
    $rdb->add_species('aedes_aegypti', 7159, 'Liverpool');

=head1 DESCRIPTION

This module is a role to interface the taxonomy part of the RNAseqDB::DB object.

=head1 INTERFACE

=over
 
=item add_species()

  function       : add a species line to the species table.
  arg            : hash ref with the following keys:
  
    production_name
    binomial_name
    taxon_id
    strain
  
  returntype     : integer: 0 = not added, 1 = added
  usage:

    # those are equivalent
    my $species_href = {
      production_name => 'anopheles_stephensiI',
      binomial_name   => 'Anopheles stephensi',
      taxon_id        => 30069,
      strain          => 'Indian',
    }
    $rdb->add_species( $species_href );
    
=back


=head1 CONFIGURATION AND ENVIRONMENT

RNAseqDB::Species requires no configuration files or environment variables.


=head1 DEPENDENCIES

 * Log::Log4perl
 * DBIx::Class
 * Moose::Role


=head1 BUGS AND LIMITATIONS

...

=head1 AUTHOR

Matthieu Barba  C<< <mbarba@ebi.ac.uk> >>

