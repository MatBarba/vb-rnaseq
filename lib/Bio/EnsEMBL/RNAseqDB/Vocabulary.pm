use utf8;
package Bio::EnsEMBL::RNAseqDB::Vocabulary;
use Moose::Role;

use strict;
use warnings;
use Log::Log4perl qw( :easy );

my $logger = get_logger();
use Data::Dumper;
use Readonly;
use Try::Tiny;

###############################################################################
# Cache attributes
has vocabulary => (
  is  => 'rw',
  isa => 'HashRef[HashRef[Str]]',
);

has formatted_voc => (
  is      => 'rw',
  isa     => 'ArrayRef[HashRef[Str]]',
  lazy    => 1,
  builder => '_format_voc',
);

###############################################################################
# ATTRIBUTES BUILDERS

# Purpose   : format the vocabulary
# Parameters: none
# Returns   : ref array of ref hashes in the following form:
# {
#   pattern => 'regex_pattern',
#   type    => 'foo',
#   name    => 'bar'
# }
# The pattern is used on a string to identify one vocabulary term with a given name.
sub _format_voc {
  my $self = shift;
  my $voc = $self->vocabulary;
  
  my @formatted_voc;
  
  for my $type (keys %$voc) {
    my $type_href = $voc->{$type};
    
    for my $name (keys %$type_href) {
      my $pattern = $type_href->{$name};
      
      my %synonym_group = (
        pattern   => $pattern,
        type      => $type,
        name      => $name
      );
      push @formatted_voc, \%synonym_group;
    }
  }
  $logger->debug(Dumper \@formatted_voc);
  
  return \@formatted_voc;
}
###############################################################################
# VOCABULARY INSTANCE METHODS

## INSTANCE METHOD
## Purpose   : analyze the title of all tracks to search for specific vocabulary words
## Parameters: [optional] A production_name
## Returns   : a hash ref of vocabulary in the form:
# { track_id => [ { type => '', name => '' } ] }
sub analyze_tracks_vocabulary {
  my ($self, $species) = shift;
  
  my @tracks = $self->get_tracks(species => $species);
  my $vocabulary = $self->formatted_voc;
  
  my %tracks_vocabulary;
  foreach my $track (@tracks) {
    my $title0 = $track->title_manual // $track->title_auto;
    next if not $title0;
    my $title = $title0;
    $title =~ s/\([^\)]*\)//g;
    my %track_voc;
    
    # Check patterns
    for my $voc (@$vocabulary) {
      my $pattern = $voc->{pattern};
      if ($title =~ s/([^-]|^)\b($pattern)\b([^-]|$)/$1$3/i) {
        $track_voc{$pattern} = {
          type  => $voc->{type},
          name  => $voc->{name},
        };
      }
    }
    
    # Store keywords
    $tracks_vocabulary{$track->track_id} = [values %track_voc];
    $logger->debug($track->merge_id . "\n\t" . $title0  . "\n\t" . $title ."\n\t". Dumper(\%track_voc));
    
    # Logging...
    if ($title =~ /[^ ]/) {
      $logger->info("Incomplete: $title");
    }
  }
  
  return \%tracks_vocabulary;
}

## INSTANCE METHOD
## Purpose   : Remove all data from the vocabulary tables
## Parameters: none
sub purge_vocabulary {
  my $self = shift;
  
  my $delete_link = $self->resultset('VocabularyTrack')->delete_all;
  my $delete_voc  = $self->resultset('Vocabulary')->delete_all;
}

## INSTANCE METHOD
## Purpose   : Link vocabulary terms to tracks
## Parameters: a track_vocabulary hash ref produced by analyze_tracks_vocabulary
sub add_vocabulary_to_tracks {
  my $self = shift;
  my ($tracks_voc) = @_;
  
  # We don't want doubles: purge
  $self->purge_vocabulary;
  
  for my $track_id (sort keys %$tracks_voc) {
    my $voc_aref = $tracks_voc->{$track_id};
    foreach my $voc (@$voc_aref) {
      $self->add_vocabulary_to_track(
        track_id  => $track_id,
        name      => $voc->{name},
        type      => $voc->{type},
      );
    }
  }
}

## INSTANCE METHOD
## Purpose   : Link a vocabulary term to a track
## Parameters:
# track_id = int track_id
# name     = vocabulary name to link to the track
# type     = vocabulary type
sub add_vocabulary_to_track {
  my $self = shift;
  my %pars = @_;
  my $track_id = $pars{track_id};
  my $voc_type = $pars{type};
  my $voc_name = $pars{name};
  
  if (not ($track_id and $voc_type and $voc_name)) {
    $logger->warn("Missing data to add vocabulary to track");
    return;
  }
  
  # First, add the controlled vocabulary and/or get its id
  my $voc_id = $self->_get_vocabulary_id($voc_type, $voc_name);
  
  # Second, link the track to the vocabulary
  my $link_insert = $self->resultset('VocabularyTrack')->create({
      track_id       => $track_id,
      vocabulary_id  => $voc_id,
  });
  $logger->debug("ADD vocabulary link $track_id - $voc_id");
}

## PRIVATE METHOD
## Purpose   : get the id of a vocabulary; create it if it doesn't exist
## Parameters:
# 1) vocabulary type
# 2) vocabulary name
sub _get_vocabulary_id {
  my $self = shift;
  my ($voc_type, $voc_name) = @_;
  
  # Get the id if it exists
  my $voc_res = $self->resultset('Vocabulary')->search({
      voc_type  => $voc_type,
      voc_name  => $voc_name
  });
  
  my $voc_id;
 
  my $voc_result = $voc_res->first;
  
  # No id? Create a new one
  if (not defined $voc_result) {
    my $voc_create = $self->resultset('Vocabulary')->create({
        voc_type  => $voc_type,
        voc_name  => $voc_name
      });
    $voc_id = $voc_create->id;
  } else {
    $voc_id = $voc_result->vocabulary_id;
  }
  
  return $voc_id;
}

# INSTANCE METHOD
# Purpose   : Get all vocabulary terms linked to a track
# Parameters: int track_id
# Returns   : Hash ref with keys = type and value an array of names
sub get_vocabulary_for_track_id {
  my $self = shift;
  my ($track_id) = @_;
  
  my $voc_req = $self->resultset('VocabularyTrack')->search({
      track_id  => $track_id,
    },
    {
      prefetch  => 'vocabulary',
    });
  
  # Put data in a hash[array]
  my %vocabulary;
  for my $voc ($voc_req->all) {
    my $type = $voc->vocabulary->voc_type;
    my $name = $voc->vocabulary->voc_name;
    push @{ $vocabulary{$type} }, $name;
  }
  
  return \%vocabulary;
}

1;


=head1 NAME

Bio::EnsEMBL::RNAseqDB::Vocabulary - Vocabulary role for the RNAseq DB


=head1 SYNOPSIS
    

=head1 DESCRIPTION

This module is a role to interface the controlled vocabular part of the Bio::EnsEMBL::RNAseqDB object.

=head1 INTERFACE

=over

=item analyze_tracks_vocabulary

  function       : compute a list of controlled terms used in the title fields of tracks
  args           : [optional] a production_name
  returns        : A hash ref of the following form:
  
  {
    track_id =>
      [
        {
          type => '',
          name => ''
        }
      ]
  }
  
  usage:
  my $voc = $rdb->analyze_tracks_vocabulary();
 
=item purge_vocabulary

  function       : Clean the vocabulary table and its links
  args           : none
  
  usage:
  $rdb->purge_vocabulary();

=item add_vocabulary_to_tracks

  function       : Link vocabulary terms to tracks
  args           : the hash produced by analyze_tracks_vocabulary
  
  usage:
  my $voc = $rdb->analyze_tracks_vocabulary();
  $rdb->add_vocabulary_to_tracks($voc);

=item add_vocabulary_to_track

  function       : Link one vocabulary term to one track
  args           :
    Int track_id
    String type of the term
    String name of the term
  
  usage:
  $rdb->add_vocabulary_to_track(
    track_id  => 100,
    name      => 'foo',
    type      => 'bar',
  );

=item get_vocabulary_for_track_id

  function       : Retrieve all terms linked to a track
  args           : a track_id
  returns        : hash ref with keys = type and value = array ref of names
  
  usage:
  my $voc = $rdb->get_vocabulary_for_track_id(100);
 
=back

=cut

