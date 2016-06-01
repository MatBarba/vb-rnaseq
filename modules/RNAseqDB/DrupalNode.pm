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

sub get_drupal_id_from_track_id {
  my ($self, $track_id) = @_;
  
  my $links = $self->_get_drupal_tracks_links({ track_id => $track_id });
  my @drupal_ids = map { $_->drupal_id } @$links;
  return \@drupal_ids;
}

sub update_drupal_node {
  my ($self, $drupal_id, $node_content) = @_;
  
  $logger->debug("Update drupal node $drupal_id");
  my $drupal_update = $self->resultset('DrupalNode')->search({
      drupal_id => $drupal_id,
  })->update($node_content);
}

sub get_track_groups {
  my $self = shift;
  my ($opt) = @_;
  
  my @groups;
  
  # First, retrieve all the groups data
  my $search = {
      'track.status' => 'ACTIVE',
  };
  $search->{'strain.production_name'} = $opt->{species} if $opt->{species};
  my $groups = $self->resultset('DrupalNode')->search(
    $search,
    {
      prefetch    => {
        drupal_node_tracks => {
          track => [
            'files',
            'analyses',
            {
              'sra_tracks' => {
                run => [
                  { sample => { strain => 'species' } },
                  { experiment => 'study' },
                ]
              }, 
            }, 
          ],
        }
      }
    });
  DRU: for my $drupal ($groups->all) {
    my %group = (
      title  => $drupal->manual_title // $drupal->autogen_title,
      text  => $drupal->manual_text // $drupal->autogen_text,
    );
    
    my $drupal_tracks = $drupal->drupal_node_tracks;
    
    # Get the data associated with every track
    # We only want active tracks
    next DRU if $drupal_tracks->all == 0;
    
    # Get the species data
    my $strain = $drupal_tracks->first->track->sra_tracks->first->run->sample->strain;
    my %species = (
      production_name => $strain->production_name,
      strain          => $strain->strain,
      organism        => $strain->species->binomial_name,
    );
    $group{taxonomy} = \%species;
    
    # Add the tracks data
    foreach my $drupal_track ($drupal_tracks->all) {
      my $track = $drupal_track->track;
      
      my %track_data = (
        #title       => $track->title,
        #description => $track->description,
        track_id    => $track->track_id,
      );
      
      foreach my $file ($track->files->all) {
        if ($file->type eq 'bigwig' or $file->type eq 'bam') {
          my @path = (
            $file->type, 
            $species{production_name},
            $file->path
          );
          unshift @path, $opt->{files_dir} if defined $opt->{files_dir};
          $track_data{files}{$file->type} = join '/', @path;
        }
      }
      
      # Get the SRA accessions
      my (%runs, %experiments, %studies, %samples);
      my @runs = $track->sra_tracks->all;
      my $private = 0;
      for my $run (@runs) {
        if (defined $run->run->run_sra_acc) {
          $runs{ $run->run->run_sra_acc }++;
          $experiments{ $run->run->experiment->experiment_sra_acc }++;
          $studies{ $run->run->experiment->study->study_sra_acc }++;
          $samples{ $run->run->sample->sample_sra_acc }++;
        } else {
          $private = 0;
          $runs{ $run->run->run_private_acc }++;
          $experiments{ $run->run->experiment->experiment_private_acc }++;
          $studies{ $run->run->experiment->study->study_private_acc }++;
          $samples{ $run->run->sample->sample_private_acc }++;
        }
      }
      my $accession_name = $private ? 'private_accessions' : 'sra_accessions';
      $track_data{$accession_name} = {
        runs => [sort keys %runs],
        experiments => [sort keys %experiments],
        studies => [sort keys %studies],
        samples => [sort keys %samples],
      };
      
      push @{$group{tracks}}, \%track_data;
    }
    
    push @groups, \%group;
    #########
    #last DRU;
    #########
  }
  
  return \@groups;
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

  function       : update one drupal_node data
  arg[1]         : drupal_id
  arg[2]         : hash with new content
  
  Usage:
  
    my $drupal_id = 1;
    my $content = {
      title => 'Foobar',
    };
    $rdb->update_drupal_node($drupal_id, $content);
    
=item get_drupal_id_from_track_id()

  function       : returns track_ids from drupal_ids
  arg            : ref array of track_ids
  returntype     : ref array of drupal_ids
  
  Usage:
  
    my $track_ids = [1, 2];
    my $drupal_ids = $rdb->get_drupal_id_from_track_id($track_ids);
    
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

