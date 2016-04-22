use utf8;
package RNAseqDB::DrupalNode;
use Moose::Role;

use strict;
use warnings;
#use List::Util qw( first );
#use JSON;
#use Perl6::Slurp;
use Log::Log4perl qw( :easy );

my $logger = get_logger();
use Data::Dumper;
use Readonly;
#use Try::Tiny;

sub _add_drupal_node_from_track {
  my ($self, $track_id) = @_;
  
  # Does the drupal node already exists?
  my $drupal_req = $self->resultset('DrupalNode')->search({
      'drupal_node_tracks.track_id' => $track_id,
  },
  {
    prefetch    => 'drupal_node_tracks',
  });

  my @res_drupals = $drupal_req->all;
  my $num_drupals = scalar @res_drupals;
  if ($num_drupals > 0) {
    $logger->warn("WARNING: Drupal node already exists for track $track_id");
    return;
  }
  
  # Insert a new drupal node and a link drupal_node_tracks
  $logger->info("ADDING drupal_node for $track_id");
  
  # Add the drupal_node itself
  my $drupal_insertion = $self->resultset('DrupalNode')->create({});
  
  # Add the link from the drupal_node to the track
  my $drupal_id = $drupal_insertion->id;
  $self->_add_drupal_node_track($track_id, $drupal_id);
  $logger->debug("ADDED drupal_node $drupal_id");
  
  return;
}

sub _add_drupal_node_track {
  my ($self, $drupal_id, $track_id) = @_;
  
  # First, check that the link doesn't already exists
  $logger->debug("ADDING drupal_node_track link from $drupal_id to $track_id");
  my $drupal_track_search = $self->resultset('DrupalNodeTrack')->search({
      drupal_id => $drupal_id,
      track_id  => $track_id,
  });
  my $links_count = $drupal_track_search->all;
  if ($links_count > 0) {
    $logger->warn("There is already a link between drupal_node $drupal_id and track $track_id");
    return;
  }
  
  my $drupal_track_insertion = $self->resultset('DrupalNodeTrack')->create({
      drupal_id => $drupal_id,
      track_id  => $track_id,
  });
  $logger->debug("ADDED drupal_node_track " . $drupal_track_insertion->id);
  return;
}

sub _get_drupal_tracks_links {
  my ($self, $conditions) = @_;
  $conditions ||= {};
  
  my $drupal_track_search = $self->resultset('DrupalNodeTrack')->search($conditions);
  my @links = $drupal_track_search->all;
  return \@links;
}

sub _inactivate_drupal_nodes {
  my ($self, $track_ids_aref) = @_;
  
  # 1) Get the tracks-drupal_nodes links
  my @conditions = map { { 'track_id' => $_ } } @$track_ids_aref;
  my $links = $self->_get_drupal_tracks_links(\@conditions);
  
  # 2) Inactivate the corresponding drupal nodes
  my @drupal_ids = map { { 'drupal_id' => $_->drupal_id } } @$links;
  my $tracks_update = $self->resultset('DrupalNode')->search(\@drupal_ids)->update({
    status => 'RETIRED',
  });
}

1;

__END__


=head1 NAME

RNAseqDB::DrupalNode - Drupal node role for the RNAseq DB


=head1 SYNOPSIS

    # Update a drupal node given a list of its SRA elements
    $db->update_drupal_node(@sra_ids, $description, $title, $drupal_node_id)

=head1 DESCRIPTION

This module is a role to interface the drupal_node part of the RNAseqDB::DB object.

=head1 INTERFACE

=over
 
=item update_drupal_node()

  function       : 
  returntype     : 
    
=back


=head1 CONFIGURATION AND ENVIRONMENT

This module requires no configuration files or environment variables.


=head1 DEPENDENCIES

 * Log::Log4perl
 * DBIx::Class
 * Moose::Role


=head1 BUGS AND LIMITATIONS

...

=head1 AUTHOR

Matthieu Barba  C<< <mbarba@ebi.ac.uk> >>
