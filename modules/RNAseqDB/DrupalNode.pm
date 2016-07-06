use utf8;
package RNAseqDB::DrupalNode;
use Moose::Role;

use strict;
use warnings;
#use List::Util qw( first );
#use JSON;
#use Perl6::Slurp;
use Log::Log4perl qw( :easy );
use File::Spec;

my $logger = get_logger();
use Data::Dumper;
use Readonly;
#use Try::Tiny;

Readonly my $GROUP_PREFIX,  'RNAseq_group_';
Readonly my $TRACK_PREFIX,  'RNAseq_track_';
Readonly my $SOLR_CHILDREN, '_childDocuments_';
Readonly my $PUBMED_ROOT,   'http://europepmc.org/abstract/MED/';
Readonly my $SRA_URL_ROOT,   'http://www.ebi.ac.uk/ena/data/view/';

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
            { analyses => 'analysis_description' },
            {
              'sra_tracks' => {
                run => [
                  { sample => { strain => 'species' } },
                  { experiment => {
                      study => { study_publications => 'publication' },
                    },
                  },
                ]
              }, 
            }, 
          ],
        }
      }
    });
  DRU: for my $drupal ($groups->all) {
    my %group = (
      site            => 'General',
      bundle_name     => 'Rna seq experiment',
      id              => $GROUP_PREFIX . $drupal->drupal_id,
      label           => $drupal->manual_title // $drupal->autogen_title,
      description     => $drupal->manual_text // $drupal->autogen_text,
    );
    
    # Get the data associated with every track
    my $drupal_tracks = $drupal->drupal_node_tracks;
    
    # Get the species data
    my $strain = $drupal_tracks->first->track->sra_tracks->first->run->sample->strain;
    my %species = (
      species  => $strain->species->binomial_name,
      strain_s => $strain->strain,
      assembly => $strain->assembly,
    );
    %group = ( %group, %species );
    my %publications;
    
    # Add the tracks data
    foreach my $drupal_track ($drupal_tracks->all) {
      my $track = $drupal_track->track;
      
      my %track_data = (
        #title       => $track->title,
        #description => $track->description,
        id => $TRACK_PREFIX . $track->track_id,
      );
      
      foreach my $file ($track->files->all) {
        if ($file->type eq 'bigwig' or $file->type eq 'bam') {
          my @path = (
            $file->type, 
            $strain->production_name,
            $file->path
          );
          unshift @path, $opt->{files_dir} if defined $opt->{files_dir};
          $track_data{$file->type . '_url'} = ''. join '/', @path;
          $track_data{$file->type . '_s'} = ''.$file->path;
          $track_data{type} = $file->type;
          $track_data{type} =~ s/bigwig/bigWig/;
          
          # Define aligner
          $track_data{aligner} = _determine_aligner($track->analyses);
        }
      }
      
      # Get the SRA accessions
      my (%runs, %experiments, %studies, %samples);
      my @track_runs = $track->sra_tracks->all;
      my $private = 0;
      for my $track_run (@track_runs) {
        my $run = $track_run->run;
        
        # Accessions
        my $run_acc    = $run->run_sra_acc                      // $run->run_private_acc;
        my $exp_acc    = $run->experiment->experiment_sra_acc   // $run->experiment->experiment_private_acc;
        my $study_acc  = $run->experiment->study->study_sra_acc // $run->experiment->study->study_private_acc;
        my $sample_acc = $run->sample->sample_sra_acc           // $run->sample->sample_private_acc;
        
        $runs{        $run_acc    }++;
        $experiments{ $exp_acc    }++;
        $studies{     $study_acc  }++;
        $samples{     $sample_acc }++;
        $private = 1 if $run_acc =~ /^VB/;
        
        # Associated publications
        my @study_pubs = $run->experiment->study->study_publications->all;
        my %track_publications = _format_publications(\@study_pubs);
        %publications = (%publications, %track_publications);
      }
      my $accession_name = $private ? 'private_accessions' : 'sra_accessions';
      my %accessions = (
        run_accessions_ss        => [sort keys %runs],
        experiment_accessions_ss => [sort keys %experiments],
        study_accessions_ss      => [sort keys %studies],
        sample_accessions_ss     => [sort keys %samples],
      );
      %track_data = (%track_data, %accessions);
      if (not $private) {
        my %accessions_urls = (
          run_accessions_ss_urls        => [map { $SRA_URL_ROOT . $_ } sort keys %runs],
          experiment_accessions_ss_urls => [map { $SRA_URL_ROOT . $_ } sort keys %experiments],
          study_accessions_ss_urls      => [map { $SRA_URL_ROOT . $_ } sort keys %studies],
          sample_accessions_ss_urls     => [map { $SRA_URL_ROOT . $_ } sort keys %samples],
        );
        %track_data = (%track_data, %accessions_urls);
      }
      
      # Add all collected publications
      %group = (%group, %publications);
      
      push @{$group{$SOLR_CHILDREN}}, \%track_data;
    }
    
    push @groups, \%group;
  }
  
  return \@groups;
}

sub _determine_aligner {
  my @analyses = @_;
  
  my @alignments = grep { $_->analysis_description->type eq 'aligner' } @analyses;
  
  if (@alignments == 1) {
    my $aligner = $alignments[0]->analysis_description->name;
    my $version = $alignments[0]->version;
    return "$aligner $version";
  } else {
    return "(undefined aligner)";
  }
}

sub _format_publications {
  my ($study_pubs_aref) = @_;
  
  my %pub_links;
  for my $study_pub (@$study_pubs_aref) {
    my $pub     = $study_pub->publication;
    my $authors = $pub->authors;
    my $title   = sprintf "%s, %s (%d)", $pub->title, $authors, $pub->year;
    my $url     = $PUBMED_ROOT . $pub->pubmed_id;
    
    $pub_links{ $title } = $url;
  }
  
  my @titles = keys %pub_links;
  my @urls   = map { $pub_links{$_} } @titles;
  my %publications = (
    publications_ss      => \@titles,
    publications_ss_urls => \@urls,
  );
  
  return %publications;
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
    
=item get_track_groups()

  function       : returns an array of groups of tracks.
  arg[1]         : hash ref with key 'species' defined [optional] to filter groups by species
  returntype     : ref array of hashes
  
  Usage:
  
    my $groups = $rdb->get_track_groups();
    
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

