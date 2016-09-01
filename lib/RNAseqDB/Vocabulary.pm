use utf8;
package RNAseqDB::Vocabulary;
use Moose::Role;

use strict;
use warnings;
use Log::Log4perl qw( :easy );

my $logger = get_logger();
use Data::Dumper;
use Readonly;
use Try::Tiny;

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

sub analyze_tracks_vocabulary {
  my ($self, $species) = shift;
  
  my @tracks = $self->get_active_tracks($species);
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

sub purge_vocabulary {
  my $self = shift;
  
  my $delete_link = $self->resultset('VocabularyTrack')->delete_all;
  my $delete_voc  = $self->resultset('Vocabulary')->delete_all;
}

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

sub add_vocabulary_to_track {
  my $self = shift;
  my %track_voc = @_;
  my $track_id = $track_voc{track_id};
  my $voc_type = $track_voc{type};
  my $voc_name = $track_voc{name};
  
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

RNAseqDB::Vocabulary - Vocabulary role for the RNAseq DB


=head1 VERSION

This document describes RNAseqDB::Vocabulary version 0.0.1


=head1 SYNOPSIS
    

=head1 DESCRIPTION

This module is a role to interface the controlled vocabular part of the RNAseqDB::DB object.

=head1 INTERFACE

=over
 
    
=back


=head1 CONFIGURATION AND ENVIRONMENT

Requires no configuration files or environment variables.


=head1 DEPENDENCIES

 * Log::Log4perl
 * DBIx::Class
 * Moose::Role


=head1 BUGS AND LIMITATIONS

...

=head1 AUTHOR

Matthieu Barba  C<< <mbarba@ebi.ac.uk> >>

