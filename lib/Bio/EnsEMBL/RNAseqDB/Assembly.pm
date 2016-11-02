package Bio::EnsEMBL::RNAseqDB::Assembly;
use 5.10.0;
use strict;
use warnings;
use Carp;
use Moose::Role;

use List::MoreUtils qw(uniq);
use Try::Tiny;
use Data::Dumper;
use Readonly;

use Log::Log4perl qw( :easy );
my $logger = get_logger();

###############################################################################
## ASSEMBLY INSTANCE METHODS

# INSTANCE METHOD
## Purpose   : add a new assembly to an existing species
## Parameters:
# * production_name = string
# * assembly        = string
sub add_assembly {
  my $self = shift;
  my %args = @_;
  
  my $species      = $args{species};
  my $assembly     = $args{assembly};
  my $assembly_acc = $args{assembly_accession};
  my $sample       = $args{sample};
  
  croak("Can't add assembly without a production_name") if not defined $species;
  croak("Can't add assembly without an assembly name")  if not defined $assembly;
  carp( "Adding assembly without an assembly accession (GCA)") if not defined $assembly_acc;
  carp( "Adding assembly without a sample region")      if not defined $sample;
  
  # Get the old latest assembly for this species
  my $old_latest = $self->resultset('Assembly')->search({
    'strain.production_name' => $species,
    'latest' => 1
  }, {
    prefetch => 'strain'
  })->first;
  croak("Can't find assembly for species '$species'") if not $old_latest;
  
  # Add the new assembly as "latest"
  my $new_latest = $self->resultset('Assembly')->find_or_create({
    assembly => $assembly,
    assembly_accession => $assembly_acc,
    sample_location => $sample,
    latest   => 0,
    strain_id => $old_latest->strain_id,
  });
  croak("Couldn't add the new assembly '$assembly' for '$species'") if not $old_latest;
  
  # Duplicate the track_analysis links to use the new assembly
  my @tracks = $self->get_tracks(species => $species);
  $logger->debug((@tracks+0) . " tracks for $species");
  my $nadded;
  for my $old_track (@tracks) {
    $self->resultset('TrackAnalysis')->find_or_create(
      {
        track_id    => $old_track->track_id,
        assembly_id => $new_latest->assembly_id,
      }
    );
    $nadded++;
  }

  # Retire the old latest assembly
  $old_latest->update({ latest => 0 });
  $new_latest->update({ latest => 1 });
  
  return $nadded;
}

sub get_assemblies {
  my $self = shift;
  my %args = @_;
  
  my %search;
  $search{'strain.production_name'} = $args{species} if $args{species};
  $search{'latest'} = 1 if not $args{all};
  
  my @list = $self->resultset('Assembly')->search(\%search,
  {
    prefetch => 'strain'
  });
  return @list;
}

1;

__END__

=head1 DESCRIPTION

This module is a role to interface the assembly part of the Bio::EnsEMBL::RNAseqDB object.

=head1 INTERFACE

=over

=item add_assembly

  function       : Add a new assembly to an existing species, and create empty
                   tracks for it. You will need to import new alignment
                   information (files and commands) against the new assembly.
  args           : 
    1) production_name of the species
    2) assembly name
  
  usage:
  $rdb->add_assembly('anopheles_gambiae', 'AgamP9');

=item get_assemblies

  function       : Retrieve all available assemblies
  args           : (all optional)
    1) "species": filter by production_name
    2) "all"    : retrieve all assemblies, not only the "latest"
  return         : Array of Assembly resultset objects
  
  usage:
  my @assemblies = $rdb->get_assemblies();
  my ($latest) = $rdb->get_assemblies(species => 'anopheles_gambiae');

=back

=cut

