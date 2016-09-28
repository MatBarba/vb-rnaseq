package Bio::EnsEMBL::RNAseqDB::Species;
use 5.10.00;
use strict;
use warnings;
use Carp;
use Moose::Role;

use List::Util qw( first );
use JSON;
use Log::Log4perl qw( :easy );
my $logger = get_logger();

# Add one species + strain + assembly
sub add_species {
  my $self = shift;
  my %sp = @_;
  
  # Check parameters
  my @needed_args = qw(production_name taxon_id binomial_name strain assembly);
  for my $arg (@needed_args) {
    croak "Species has no $arg" if not exists $sp{$arg};
  }
  # Optional missing parameters
  my @optional_args = qw(assembly_accession sample_location);
  for my $arg (@optional_args) {
    $logger->info("Species has no $arg (optional but recommended)") if not exists $sp{$arg};
  }
  
  # First find or create the species_id
  my $species = $self->resultset('Species')->find_or_create({
    taxon_id      => $sp{taxon_id},
    binomial_name => $sp{binomial_name},
  });
  
  # Check that the strain doesn't already exists
  my $existing_strain = $self->resultset('Strain')->find({
      production_name => $sp{production_name}
  });
  if ($existing_strain) {
    croak("Strain already exists: $sp{production_name}");
    return;
  }

  # Add the strain + assembly
  my $strain = {
    species_id      => $species->species_id,
    production_name => $sp{production_name},
    strain          => $sp{strain},
    assemblies      => [
    {
      assembly           => $sp{assembly},
      assembly_accession => $sp{assembly_accession},
      sample_location    => $sp{sample_location},
    }
    ],
  };
  $self->resultset('Strain')->create($strain);
  $logger->info("Added NEW STRAIN: $sp{production_name} ($sp{assembly})");
}

sub add_new_assembly {
  my $self = shift;
  my %sp = @_;
  
  # Check parameters
  my @needed_args = qw(assembly);
  for my $arg (@needed_args) {
    croak "Assembly has no $arg" if not exists $sp{$arg};
  }
  # Optional missing parameters
  my @optional_args = qw(assembly_accession sample_location);
  for my $arg (@optional_args) {
    $logger->info("Assembly has no $arg (optional but recommended)") if not exists $sp{$arg};
  }
  
  # TODO
  
  # Get the previous latest assembly
  my $last_assembly = $self->resultset('Assembly')->search({
      'strain.production_name' => $sp{production_name}
    },
    {
      prefetch => 'strain'
    })->single();
  croak "Can't add new assembly without existing strain" if not $last_assembly;
  
  # Inactivate the previous assembly
  $last_assembly->update({ latest => 0 });
  
  # Create a new assembly row
  my $insert_assembly = $self->resultset('Assembly')->create({
      strain_id          => $last_assembly->strain_id,
      assembly           => $sp{assembly},
      assembly_accession => $sp{assembly_accession},
      sample_location    => $sp{sample_location},
  });
  
  # Last step: replicate all the tracks from the previous assembly
  # TODO
}

1;

=head1 DESCRIPTION

Bio::EnsEMBL::RNAseqDB::Species - Species and taxonomy role for the RNAseq DB.

=head1 INTERFACE

=over
 
=item add_species(%species)

  function       : add rows to the species, sample and assembly tables.
                   WARNING: only one assembly per strain can be added this way.
                   To add another assembly, use add_assembly().
  arg            : hash with the following keys:
  
    production_name
    binomial_name
    taxon_id
    strain
    assembly
    assembly_accession [optional GCA id, necesseary for the Track Hub Registry]
    sample_location    [optional, needed for activation links]
  
  usage:

    my %species = (
      production_name => 'anopheles_stephensiI',
      binomial_name   => 'Anopheles stephensi',
      taxon_id        => 30069,
      strain          => 'Indian',
      assembly        => 'AsteI2',
      assembly_accession  => 'GCA_000300775.2',
    );
    $rdb->add_species( %species );

=item add_new_assembly(%assembly)

  function       : add a new assembly for a strain.
                   This function also updates the tracks list, so that new
                   tracks need to be aligned along the new assembly.
  arg            : hash with the following keys:
  
    production_name [used as key to find a given strain]
    assembly
    assembly_accession [optional GCA id, necesseary for the Track Hub Registry]
    sample_location    [optional, needed for activation links]
  
  usage:

    my %assembly = (
      production_name => 'anopheles_stephensiI',
      assembly        => 'AsteI2',
      assembly_accession  => 'GCA_000300775.2',
    );
    $rdb->add_new_assembly( %assembly );

    
=back

