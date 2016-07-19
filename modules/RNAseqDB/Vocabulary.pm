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

