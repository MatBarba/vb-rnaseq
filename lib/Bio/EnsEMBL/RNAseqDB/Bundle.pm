package Bio::EnsEMBL::RNAseqDB::Bundle;
use strict;
use warnings;
use Carp;
use Moose::Role;

use File::Spec;
use Data::Dumper;
use Readonly;
use File::Path qw(make_path);

use Log::Log4perl qw( :easy );
my $logger = get_logger();

###############################################################################
use Bio::EnsEMBL::RNAseqDB::Common;
my $common = Bio::EnsEMBL::RNAseqDB::Common->new();
Readonly my $PREFIX => $common->get_project_prefix();

# Name of the bundles
Readonly my $GROUP_PREFIX => $PREFIX . 'RNAseq_group_';
Readonly my $TRACK_PREFIX => $PREFIX . 'RNAseq_track_';

# Solr specific constants
Readonly my $SOLR_CHILDREN => '_childDocuments_';
Readonly my $SEARCH_ROOT   => '/vbsearch/details/';
Readonly my $PUBMED_ROOT   => 'https://www.ncbi.nlm.nih.gov/pubmed/';
Readonly my $SRA_URL_ROOT  => 'http://www.ebi.ac.uk/ena/data/view/';

###############################################################################
sub _add_bundle_from_track {
  my ($self, $track_id) = @_;
  
  # Does the bundle already exist?
  my $bundle_req = $self->resultset('Bundle')->search({
      'bundle_tracks.track_id' => $track_id,
  },
  {
    prefetch    => 'bundle_tracks',
  });

  my @res_bundles = $bundle_req->all;
  my $num_bundles = scalar @res_bundles;
  if ($num_bundles > 0) {
    $logger->warn("WARNING: Bundle already exists for track $track_id");
    return;
  }
  
  # Insert a new bundle and a link bundle_tracks
  my $bundle_id = $self->create_bundle_from_track_ids($track_id);
  
  return $bundle_id;
}

sub _add_bundle_track {
  my ($self, $bundle_id, $track_id) = @_;
  
  # First, check that the link doesn't already exists
  $logger->debug("ADDING bundle_track link from $bundle_id to $track_id");
  my $bundle_track_search = $self->resultset('BundleTrack')->search({
      bundle_id => $bundle_id,
      track_id  => $track_id,
  });
  my $links_count = $bundle_track_search->all;
  if ($links_count > 0) {
    $logger->warn("There is already a link between bundle $bundle_id and track $track_id");
    return;
  }
  
  my $bundle_track_insertion = $self->resultset('BundleTrack')->create({
      bundle_id  => $bundle_id,
      track_id   => $track_id,
  });
  $logger->debug("ADDED bundle_track " . $bundle_track_insertion->id);
  return;
}

# INSTANCE METHOD
# Purpose   : insert a bundle in the DB given a list of track_ids
# Parameters: array of track_ids
# Returns   : int bundle_id that was just created
sub create_bundle_from_track_ids {
  my $self = shift;
  my @track_ids = @_;
  
  my $bundle_data = {};
  
  if (@track_ids == 1)  {
    $logger->debug("Bundle: copy data from track " . $track_ids[0]);
    # Retrieve the tracks data to copy to the bundle (auto fields)
    my $tracks = $self->resultset('Track')->search({
        track_id  => $track_ids[0],
      });
    my $track = $tracks->first;
    $bundle_data = {
      title_auto => $track->title_manual || $track->title_auto,
      text_auto  => $track->text_manual  || $track->text_auto,
    };
    $logger->debug("Bundle title = $bundle_data->{title_auto}") if $bundle_data and $bundle_data->{title_auto};
  }
  
  # Add the bundle itself
  my $bundle_insertion = $self->resultset('Bundle')->create($bundle_data);
  
  my $bundle_id = $bundle_insertion->id;
  
  # Add the link from the bundle to the tracks
  for my $track_id (@track_ids) {
    $self->_add_bundle_track($bundle_id, $track_id);
  }
  $logger->debug("ADDED bundle $bundle_id");
  return $bundle_id;
}

sub _get_bundle_tracks_links {
  my ($self, $conditions) = @_;
  $conditions //= {
    'bundle.status' => 'ACTIVE',
  };
  
  my $bundle_track_search = $self->resultset('BundleTrack')->search($conditions,
    {
      prefetch  => 'bundle'
    });
  my @links = $bundle_track_search->all;
  return \@links;
}

sub _inactivate_bundles_for_tracks {
  my ($self, $track_ids_aref) = @_;
  
  # 1) Get the tracks-bundles links
  my @conditions = map { { 'track_id' => $_ } } @$track_ids_aref;
  my $links = $self->_get_bundle_tracks_links(\@conditions);
  
  # 2) Inactivate the corresponding bundles
  my @bundle_ids = map { $_->bundle_id } @$links;
  $self->inactivate_bundles(@bundle_ids);
}

# INSTANCE METHOD
# Purpose   : Inactivate a list of bundles
# Parameters: array of bundle_ids
sub inactivate_bundles {
  my $self = shift;
  my @bundle_ids = @_;
  
  my %bundles_hash = map { $_ => 1 } @bundle_ids;
  @bundle_ids = sort keys %bundles_hash;
  $logger->debug("Inactivate the bundles: " . join(',', @bundle_ids));
  my @bundle_searches = map { { bundle_id => $_ } } @bundle_ids;
  my $tracks_update = $self->resultset('Bundle')->search(
      \@bundle_searches
    )->update({
      status => 'RETIRED',
    });
}

sub get_bundle_id_from_track_id {
  my ($self, $track_id) = @_;
  
  my $links = $self->_get_bundle_tracks_links({
      track_id => $track_id,
      'bundle.status' => 'ACTIVE'
    });
  my @bundle_ids = map { $_->bundle_id } @$links;
  return \@bundle_ids;
}

sub update_bundle {
  my ($self, $bundle_id, $node_content) = @_;
  
  $logger->debug("Update bundle $bundle_id");
  my $bundle_update = $self->resultset('Bundle')->search({
      bundle_id => $bundle_id,
  })->update($node_content);
}

# INSTANCE METHOD
# Purpose   : Merge a list of bundles into one
# Parameters: array of bundle_ids
sub merge_bundles {
  my $self = shift;
  my @bundle_ids = @_;
  
  # Get the track_ids associated with the bundles
  my @track_ids;
  for my $bundle_id (@bundle_ids) {
    push @track_ids, $self->get_bundle_tracks($bundle_id);
  }
  
  # Make a new bundle from the tracks of all the bundles
  $logger->debug("Merge bundles : " . join(",", @bundle_ids));
  my $new_bundle_id = $self->create_bundle_from_track_ids(@track_ids);
  
  # Inactivate the merged bundles, leaving only the merged result
  $self->inactivate_bundles(@bundle_ids);
  
  return $new_bundle_id;
}

# INSTANCE METHOD
# Purpose   : Get the list of tracks contained by a given bundle
# Parameters: one bundle_id
sub get_bundle_tracks {
  my $self = shift;
  my ($bundle_id) = @_;
  
  my $req = $self->resultset('BundleTrack')->search({
      bundle_id => $bundle_id,
  });
  
  my @track_ids = map { $_->track_id } $req->all;
  return @track_ids;
}

# INSTANCE METHOD
# Purpose   : Get the list of all samples metadata for every species
# Parameters: none
# Returns   : Hash ref of samples
sub get_samples {
  my $self = shift;
  
  my %samples;
  my $strains_req = $self->resultset('Strain')->search({
    'assemblies.latest' => 1,
  },
  {
    prefetch  => 'assemblies',
  });
  for my $strain ($strains_req->all) {
    my $name   = $strain->production_name;
    my $sample = $strain->assemblies->next->sample_location;
    $samples{$name} = $sample;
  }
  return \%samples;
}

sub _prepare_hub_activation_link {
  my $self = shift;
  my ($hubs_root, $group) = @_;
  my $samples = $self->get_samples();
  if ($hubs_root and $group) {
    my $hub_url = $hubs_root . '/' . $group->{production_name} . '/' . $group->{trackhub_id} . '/hub.txt';
    my $activation_url = '/' . ucfirst($group->{production_name}) . '/Location/View?'
    . 'r=' . $samples->{$group->{production_name}} . ';'
    . 'contigviewbottom=url:' . $hub_url . ';'
    . 'format=TRACKHUB;'
    . 'menu=' . $group->{label} . ';'
    ;
    return $activation_url;
  }
  return;
}

sub _prepare_track_activation_link {
  my $self = shift;
  my ($hubs_root, $group, $file) = @_;
  my $samples = $self->get_samples();
  if ($hubs_root and $group and $file) {
    my $activation_url = '/' . ucfirst($group->{production_name}) . '/Location/View?'
    . 'r=' . $samples->{$group->{production_name}} . ';'
    . 'contigviewbottom=url:' . $file->{url} . ';'
    ;
    return $activation_url;
  }
  return;
}

sub format_bundles_for_solr {
  my $self = shift;
  my ($opt) = @_;
  
  my $groups  = $opt->{bundles};
  
  my @solr_groups;
  
  # Alter the structure and names to create a valid Solr json for indexing
  for my $group (@$groups) {
    # Select the latest assembly data
    my $as_data = $group->{assemblies};
    my $assembly;
    for my $name (keys %$as_data) {
      if ($as_data->{$name}->{latest}) {
        $assembly = $as_data->{$name};
        $assembly->{name} = $name;
      }
    }
    
    my %solr_group = (
      id                   => $group->{trackhub_id},
      label                => $group->{label},
      description          => $group->{description},
      species              => $group->{species},
      strain_s             => $group->{strain},
      assembly             => $assembly->{name},
      site                 => 'Expression',
      bundle_name          => 'RNA-seq track groups',
      #pubmed_ids_ss        => $group->{publications_pubmeds},
      publications_ss      => $group->{publications},
      publications_ss_urls => $group->{publications_urls},
      hash                 => 'parentDocument',
    );
    
    # Create the activation url
    my $activation_link = $self->_prepare_hub_activation_link($opt->{hubs_url}, $group);
    if ($activation_link) {
      $solr_group{activation_link_s_url} = $activation_link;
      $solr_group{activation_link_s} = '<img src="/sites/default/files/ftp/images/browse_genome.png">';
    } else {
      $logger->warn("No hubs_url defined: can't create activation");
    }
    
    foreach my $track (@{ $group->{tracks} }) {
      my $assembly_data = $track->{assemblies}->{ $assembly->{name} };
      my %solr_track = (
        id                            => $track->{id},
        site                          => 'Expression',
        bundle_name                   => 'RNA-seq tracks',
        species                       => $group->{species},
        label                         => $track->{title},
        description                   => $track->{description},
        url                           => $SEARCH_ROOT . $group->{trackhub_id},
        
        run_accessions_ss             => $track->{runs},
        experiment_accessions_ss      => $track->{experiments},
        study_accessions_ss           => $track->{studies},
        sample_accessions_ss          => $track->{samples},
        
        aligner_s                     => $assembly_data->{aligner},
      );
      
      $solr_track{run_accessions_ss_urls} = $track->{runs_urls} if $track->{runs_urls};
      $solr_track{experiment_accessions_ss_urls} = $track->{experiments_urls} if $track->{experiments_urls};
      $solr_track{study_accessions_ss_urls} = $track->{studies_urls} if $track->{studies_urls};
      $solr_track{sample_accessions_ss_urls} = $track->{samples_urls} if $track->{samples_urls};
      
      # Add associated files
      for my $file (@{ $assembly_data->{files} }) {
        if ($file->{type} eq 'bigwig') {
          $solr_track{bigwig_s} = defined $opt->{human_dir} ? $file->{human_name} : $file->{name};
          $solr_track{bigwig_s_url} = $file->{url};
        }
        elsif ($file->{type} eq 'bam') {
          $solr_track{bam_s} = defined $opt->{human_dir} ? $file->{human_name} : $file->{name};
          $solr_track{bam_s_url} = $file->{url};
        }
        
        # Create the activation url
        if ($file->{type} eq 'bam' or $file->{type} eq 'bigwig') {
          my $activation_link = $self->_prepare_track_activation_link($opt->{hubs_url}, $group, $file);
          if ($activation_link) {
            $solr_track{'activation_link_'. $file->{type} .'_s_url'} = $activation_link;
            $solr_track{'activation_link_'. $file->{type} .'_s'} = 'Load '. $file->{type} .' in Genome Browser';
          } else {
            $logger->warn("Can't create activation link for track");
          }
        }
      }
      
      # Add keywords
      my @keywords;
      for my $type (keys %{ $track->{keywords} }) {
        my $list = $track->{keywords}->{$type};
        push @keywords, @$list;
      }
      $solr_track{keywords_ss} = \@keywords;
      
      push @{ $solr_group{$SOLR_CHILDREN} }, \%solr_track;
    }
    
    push @solr_groups, \%solr_group;
  }
  
  return \@solr_groups;
}
 
sub get_bundles {
  my $self = shift;
  my ($opt) = @_;
  
  my @groups;
  
  my $bundles = $self->_get_bundles($opt);
  
  DRU: for my $bundle ($bundles->all) {
    my %group = (
      id              => $GROUP_PREFIX . $bundle->bundle_id,
      label           => $bundle->title_manual || $bundle->title_auto,
      description     => $bundle->text_manual  || $bundle->text_auto,
    );
    $group{description} ||= $group{label};
    if (not defined $group{label}) {
      $logger->warn("WARNING: bundle $group{id} has no label (no auto or manual title). Using the id as label.");
      $group{label} = $group{id};
    }
    if (not defined $group{description}) {
      $logger->warn("WARNING: bundle $group{id} has no description.");
    }
    
    # Get the data associated with every track
    my $bundle_tracks = $bundle->bundle_tracks;
    
    # Get the species data
    my $strain = $bundle_tracks->first->track->sra_tracks->first->run->sample->strain;
    my %species = (
      species            => $strain->species->binomial_name,
      strain             => $strain->strain,
      production_name    => $strain->production_name,
    );
    %group = ( %group, %species );
    my %publications;
    
    # Use a better label if possible
    $group{trackhub_id} = $group{id};
    if ( $bundle_tracks->all == 1 ) {
      my ($track) = $bundle_tracks->all;
      $group{trackhub_id} = $track->track->merge_text;
      
      # Simplify name if it has more than 2 elements
      $group{trackhub_id} =~ s/^([^_]+)_.+_([^-]+)$/$1-$2/;
      $group{trackhub_id} = $GROUP_PREFIX . $group{trackhub_id};
    }
    
    # Add the tracks data
    TRACK: foreach my $bundle_track ($bundle_tracks->all) {
      my $track = $bundle_track->track;
      my $track_id = $track->track_id;
      
      # Define title
      my $title = $track->title_manual // $track->title_auto;
      if (not $title) {
        my $merge = $track->merge_text;
        
        if ($merge =~ /_/) {
          my ($first) = split /_/, $merge;
          $title = "$first-...";
        } else {
          $title = $merge;
        }
      }
      
      # Define description
      my @description_list;
      my $track_description = $track->text_manual || $track->text_auto;
      
      # warn if no default description for this track
      if ($track_description) {
        push @description_list, $track_description;
      } else {
        my $track_name = $TRACK_PREFIX . $track->id;
        $logger->warn("WARNING: Track '$track_name' with title '$title' has no description");
      }
      
      # Add the list of SRA ids to the description anyway
      my $merge = $track->merge_text;
      $merge =~ s/(.R[PXRS]\d{6,8})/<a href="http:\/\/www.ebi.ac.uk\/ena\/data\/view\/$1">$1<\/a>/g;
      if ($merge =~ s/_/, /g) {
        push @description_list, "Merged RNA-seq data from: $merge";
      } else {
        push @description_list, "RNA-seq data from $merge";
      }
      my $description = join("<br>", @description_list);
      
      my %track_data = (
        title       => $title,
        description => $description,
        id          => $TRACK_PREFIX . $track->track_id,
        merge_text  => $track->merge_text,
      );
      
      my %assemblies;
      foreach my $track_analysis ($track->track_analyses) {
        my $assembly = $track_analysis->assembly->assembly;
        my @files;
        FILE: foreach my $file ($track_analysis->files) {
          my @url_path = (
            $file->type eq 'bai' ? 'bam' : $file->type,
            $strain->production_name,
          );
          my $human_dir = $opt->{human_dir};
          if ($human_dir) {
            my @path = split /\//, $human_dir;
            my $human_dir_name = pop @path;
            unshift @url_path, $human_dir_name;
            push @url_path, $file->human_name;
          } else {
            push @url_path, $file->path;
          }
          unshift @url_path, $opt->{files_url} if defined $opt->{files_url};
          my $url  = ''. join('/', @url_path);

          my %file_data = (
            'name'       => $file->path,
            'human_name' => $file->human_name,
            'url'        => $url,
            'type'       => ''. $file->type,
          );
          push @files, \%file_data;
        }
        my %track_assembly_data = (
          files    => \@files,
          aligner  => _determine_aligner($track_analysis->analyses),
        );
        $assemblies{$assembly} = \%track_assembly_data;
        
        # Also add this information for the whole bundle
        my $ass_accession = $track_analysis->assembly->assembly_accession;
        if (not exists $group{assemblies}->{$assembly}) {
          my %bundle_assembly_data = (
            accession => $ass_accession,
            latest    => $track_analysis->assembly->latest,
          );
          $group{assemblies}->{$assembly} = \%bundle_assembly_data;
        }
      }
      $track_data{assemblies} = \%assemblies;
      
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
        $private = 1 if $run_acc =~ /^$PREFIX/;
        
        # Associated publications
        my @study_pubs = $run->experiment->study->study_publications->all;
        my %track_publications = _format_publications(\@study_pubs);
        %publications = (%publications, %track_publications);
      }
      
      my $accession_name = $private ? 'private_accessions' : 'sra_accessions';
      my %accessions = (
        runs        => [sort keys %runs],
        experiments => [sort keys %experiments],
        studies     => [sort keys %studies],
        samples     => [sort keys %samples],
      );
      %track_data = (%track_data, %accessions);
      if (not $private) {
        my %accessions_urls = (
          runs_urls        => [map { $SRA_URL_ROOT . $_ } sort keys %runs],
          experiments_urls => [map { $SRA_URL_ROOT . $_ } sort keys %experiments],
          studies_urls     => [map { $SRA_URL_ROOT . $_ } sort keys %studies],
          samples_urls     => [map { $SRA_URL_ROOT . $_ } sort keys %samples],
        );
        %track_data = (%track_data, %accessions_urls);
      }
      
      # Finally, get the keywords
      my $keywords = $self->get_vocabulary_for_track_id($track_id);
      $track_data{keywords} = $keywords;
      
      # Save the track in the bundle
      push @{ $group{tracks} }, \%track_data;
      
      # Add all collected publications
      %group = (%group, %publications);
    }
    @{ $group{tracks} } = sort { $a->{title} cmp $b->{title} } @{ $group{tracks} };
    
    push @groups, \%group;
  }
  @groups = sort { $a->{species} cmp $b->{species} } @groups;
  
  return \@groups;
}

sub _get_bundles {
  my $self = shift;
  my ($opt) = @_;
  
  # First, retrieve all the groups data
  my $search = {
      'me.status'    => 'ACTIVE',
      'track.status' => 'ACTIVE',
  };
  $search->{'strain.production_name'} = $opt->{species} if $opt->{species};
  my $bundles = $self->resultset('Bundle')->search(
    $search,
    {
      order_by    => { -asc => 'me.bundle_id' },
      prefetch    => {
        bundle_tracks => {
          track => [
            {
             'track_analyses' => [
              'files',
              { analyses => 'analysis_description' }
              ],
            },
            { vocabulary_tracks => 'vocabulary' },
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
    }
  );
  
  return $bundles;
}

sub create_human_symlinks {
  my $self = shift;
  my ($groups, $human_dir) = @_;
  
  return if not $groups;
  return if not defined $human_dir;
  
  # Create symlinks...
  for my $group (@$groups) {
    for my $track (@{ $group->{tracks} }) {
      for my $assembly (keys %{ $track->{assemblies} }) {
        my $assembly_data = $track->{assemblies}->{ $assembly };
        for my $file (@{ $assembly_data->{files} }) {
          my $type = $file->{type};
          $type = 'bam' if $type eq 'bai';
          my $species      = $group->{production_name};
          my $sym_dir      = "$human_dir/$type/$species";
          make_path $sym_dir;
          my $relative_dir = "../../../$type/$species";
          my $sym_file    = "$sym_dir/" . $file->{human_name};
          my $actual_file = "$relative_dir/" . $file->{name};
          symlink $actual_file, $sym_file;
        }
      }
    }
  }
}

sub _determine_aligner {
  my @analyses = @_;
  
  my @alignments = grep { $_->analysis_description->type eq 'aligner' } @analyses;
  
  if (@alignments) {
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
  
  my @titles  = keys %pub_links;
  my @urls    = map { $pub_links{$_} } @titles;
  my @pubmeds = map { $_->publication->pubmed_id } @$study_pubs_aref;
  my @pubmed_abbrevs = map { _make_publication_abbrev($_->publication) } @$study_pubs_aref;
  my %publications = (
    publications         => \@titles,
    publications_urls    => \@urls,
    publications_pubmeds => \@pubmeds,
    publications_abbrevs => \@pubmed_abbrevs,
  );
  
  return %publications;
}

sub _make_publication_abbrev {
  my ($pub) = @_;
  
  my @authors = split /,/, $pub->authors;
  
  # Get first author and only keep surname
  my $first_author = shift @authors;
  $first_author =~ s/\s[A-Z]{1,2}$//;
  
  $first_author .= ' et al.' if @authors;
  my $year = $pub->year;
  
  return sprintf "$first_author $year";
}

1;

__END__

=head1 DESCRIPTION

Bio::EnsEMBL::RNAseqDB::Bundle - Bundle role for the RNAseq DB.

=head1 INTERFACE

=over

=item create_bundle_from_track_ids

  function       : Create a new bundle of tracks
  args           : array of track_ids
  returns        : the bundle_id of the bundle that was just created

  Usage:
    $rdb->create_bundle_from_track_ids(1, 2, 3);
 
=item update_bundle()

  function       : update one bundle data
  arg[1]         : bundle_id
  arg[2]         : hash with new content
  
  Usage:
  
    my $bundle_id = 1;
    my $content = {
      title => 'Foobar',
    };
    $rdb->update_bundle($bundle_id, $content);
    
=item get_bundle_id_from_track_id

  function       : returns track_ids from bundle_ids
  arg            : ref array of track_ids
  returntype     : ref array of bundle_ids
  
  Usage:
  
    my $track_ids = [1, 2];
    my $bundle_ids = $rdb->get_bundle_id_from_track_id($track_ids);
    
=item get_bundles

  function       : returns an array of groups of tracks.
  arg[1]         : hash ref with key 'species' defined [optional] to filter groups by species
  returntype     : ref array of hashes
  
  Usage:
  
    my $groups = $rdb->get_bundles();
    
=item format_bundles_for_solr

  function       : returns groups of track in a data structure suuitable for Solr.
  arg[1]         : hash ref with key 'species' defined [optional] to filter groups by species
  returntype     : ref array of hashes
  
  Usage:
  
    my $groups = $rdb->get_bundles_for_solr();

=item get_bundle_tracks

  function       : Get the list of tracks contained by a given bundle
  arg[1]         : one bundle_id
  returns        : array of track_ids
  
  Usage:
    
    my @track_ids = $rdb->get_bundle_tracks(2);

=item get_samples

  function       : Get a list of samples metadata
  args           : none
  returns        : hash ref of samples:
  
  {
    'production_name' => DBix Sample object ref,
  }
  
  Usage:
    
    my $samples_data = $rdb->get_samples();

=item inactivate_bundles

  function       : inactivate a list of bundles
  args           : an array of bundle_ids
  
  Usage:
  
    $rdb->inactivate_bundles(3, 4);

=item merge_bundles

  function       : merge a list of bundles into 1
  args           : an array of bundle_ids
  returns        : integer bundle_id
  
  NB: all the bundles in the list are inactivated.
  
  Usage:
  
    my $merged_bundle_id = $rdb->merge_bundles(3, 4, 5);
    
=item create_human_symlinks

  function       : create symlinks to human readable versions of the files
  arg[1]         : A bundle resultset
  arg[2]         : A directory where the symlinks will be created
  returns        : none
  
  NB: the directory structure contains dirs for each file type, with the same
  structure as the main dirs.
  
  Usage:
  
    $rdb->create_human_symlinks($bundle, './human_names');
    
=back

=cut

