package Bio::EnsEMBL::RNAseqDB::Track;
use 5.10.0;
use strict;
use warnings;
use Carp;
use Moose::Role;

use List::MoreUtils qw(uniq);
use File::Spec;
use Digest::MD5::File qw(file_md5_hex);
use Digest::MD5 qw(md5_hex);
use Try::Tiny;
use Memoize;
use Data::Dumper;
use Readonly;

use Log::Log4perl qw( :easy );
my $logger = get_logger();

use Bio::EnsEMBL::RNAseqDB::Common;
my $common = Bio::EnsEMBL::RNAseqDB::Common->new();
my $sra_regex = $common->get_sra_regex();

###############################################################################
## TRACKS PRIVATE METHODS
#
## PRIVATE METHOD
## Purpose   : insert a new track in the database for a given SRA run
## Parameters: a run table run_id
sub _add_track {
  my ($self, $run_id) = @_;
  
  # Does the track already exists?
  my $track_req = $self->resultset('Track')->search({
      'sra_tracks.run_id' => $run_id,
      status  => 'ACTIVE',
  },
  {
    prefetch    => 'sra_tracks',
  });

  my @res_tracks = $track_req->all;
  my $num_tracks = scalar @res_tracks;
  if ($num_tracks > 0) {
    $logger->warn("WARNING: Track already exists for run $run_id");
    return;
  }
  
  # Get the latest assembly for these runs
  # NB: we're only going to align tracks against the latest version
  my $ass_req = $self->resultset('Assembly')->search({
    'runs.run_id' => $run_id,
    latest => 1
  },
  {
    prefetch  => { 'strain' => { 'samples' => 'runs' } }
  });
  my $assembly_id = $ass_req->next->assembly_id;
  
  # Insert a new track and a link sra_track
  $logger->info("ADDING track for $run_id");
  
  # Add the track itself
  my $track_insertion = $self->resultset('Track')->create({
      sra_tracks => [
        {
          run_id => $run_id,
        }
      ],
      track_analyses  => [
        {
          assembly_id => $assembly_id
        }
      ]
  });
  
  # Add the link from the run to the track
  my $track_id = $track_insertion->id;
  
  # Also create a bundle for this track
  #$self->_add_bundle_from_track($track_id);
  
  # Finally, try to create a title + description for the track
  $self->guess_track_text($track_id);
  
  return 1;
}

###############################################################################
## TRACKS INSTANCE METHODS

# INSTANCE METHOD
## Purpose   : retrieve an array of track objects given some conditions
## Parameters:
# Filters
# * species = string
# * aligned = 0/1
# * status  = string 'ACTIVE', 'RETIRED', 'MERGED', ''
# Selection
# * merge_ids, track_ids, sra_ids = array of strings/ids
sub get_tracks {
  my $self = shift;
  my %pars = @_;
  
  my %filter;
  my $me = 'me';
  
  my @allowed_args = qw(
    species
    status
    aligned
    merge_ids
    track_ids
    sra_ids
    assembly
    all_assemblies
  );
  my %allowed = map { $_ => 1 } @allowed_args;
  for my $arg (keys %pars) {
    croak "Can't use argument '$arg'" if not defined $allowed{$arg};
  }
  
  # Return active tracks by default
  # (To get all tracks: status='')
  $pars{status} //= 'ACTIVE';
  $filter{$me.'.status'} = uc($pars{status}) if $pars{status};
  
  # Species
  $filter{'strain.production_name'} = $pars{species} if $pars{species};
  
  # Assemblies: one, latest, or all?
  if ($pars{assembly}) {
    $filter{'assembly.assembly'} = $pars{assembly};
  } elsif (not $pars{all_assemblies}) {
    $filter{'assembly.latest'} = 1;
  }

  # Already aligned (with files) or not
  if (defined $pars{aligned}) {
    if ($pars{aligned}) {
      $filter{'files.file_id'} = { '!=', undef };
    } else {
      $filter{'files.file_id'} = undef;
    }
  }

  # List of possibilities
  my @or;
  if ($pars{merge_ids}) {
    push @or, map { { merge_id => $_ } } @{$pars{merge_ids}};
  }
  if ($pars{track_ids}) {
    push @or, map { { $me.'.track_id' => $_ } } @{$pars{track_ids}};
  }
  if ($pars{sra_ids}) {
    push @or, $self->_format_sras_for_search(@{$pars{sra_ids}});
  }
  
  my %search;
  
  if (@or) {
    $search{'-or'}  = \@or;
    $search{'-and'} = \%filter if %filter;
  } else {
    %search = %filter if %filter;
  }
  use Data::Dumper;
  #$logger->debug(Dumper \%pars);
  #$logger->debug(Dumper \%search);
  
  # Actual request with filters
  my $track_req = $self->resultset('Track')->search(\%search,
    {
      prefetch => [
        { 'track_analyses' => ['files', 'assembly'] },
        { 'bundle_tracks' => 'bundle' },
        { 'sra_tracks' =>
          { 'run' => [
              { 'sample' => 'strain' },
              { 'experiment' => 'study' },
              'private_files',
            ]
          }
        }
      ],
    }
  );
  my @tracks = $track_req->all;
  
  return @tracks;
}

## INSTANCE METHOD
## Purpose   : update a table row
## Parameters: a track table track_id, a ref hash with new data
sub update_track {
  my $self = shift;
  my ($track_id, $track_data) = @_;
  
  $self->resultset('Track')->search({
      'track_id'  => $track_id,
    })->update($track_data);
}

## INSTANCE METHOD
## Purpose   : populate title_auto and text_auto for tracks
## Parameters: an array of track_ids
sub guess_track_text {
  my $self = shift;
  my @track_ids = @_;
  
  my $me = 'me';
  
  for my $track_id (@track_ids) {
    my $req = $self->resultset('Track')->search({
        $me.'.track_id' => $track_id,
      }, 
      {
        prefetch  => {
          sra_tracks => {
            run => 'sample',
          }
        }
      });
    
    my $track      = $req->first;
    my @track_runs = $track->sra_tracks->all;
    my (@titles, @descriptions);
    for my $track_run (@track_runs) {
      my $sample = $track_runs[0]->run->sample;
      push @titles, $sample->title if $sample->title;
      push @descriptions, $sample->description if $sample->description;
    }

    # Only keep one of each
    @titles       = uniq (sort @titles);
    @descriptions = uniq (sort @descriptions);

    # Next: concat titles and descriptions
    my $title       = join(', ', @titles);
    my $description = join('<br>', @descriptions);
    
    if (not $title) {
      $title = $track->merge_text;
    }

    $self->resultset('Track')->search({
        'track_id'  => $track_id,
      })->update({
        title_auto  => $title,
        text_auto   => $description,
      });
  }
  
  return 1;
}

## INSTANCE METHOD
## Purpose   : retrieve meta information about tracks that needs to be aligned
## Parameters: a species string (optional)
## Returns   : a hash in the form
#              {production_name => { taxon_id => 0, sra => ['']} }
sub get_new_runs_tracks {
  my $self = shift;
  my ($species) = @_;
  
  my @tracks = $self->get_tracks(
    species => $species,
    aligned => 0,
    all_assemblies => 1,
  );
  $logger->debug((@tracks+0) . " tracks to consider as new");
  
  my %new_track = ();
  for my $track (@tracks) {
    my $track_id = $track->track_id;
    $logger->debug("Check track $track_id as new run track");

    for my $sra_track ($track->sra_tracks) {
      my $run = $sra_track->run;
      
      # Private file?
      if (defined $run->run_private_acc) {
        my @fastq = map { $_->path } $run->private_files->all;
        $self->_add_new_runs_track(\%new_track, $track_id, $run, \@fastq);
      }
      # Otherwise, the SRA accessions will suffice
      else {
        $self->_add_new_runs_track(\%new_track, $track_id, $run);
      }
    }
  }
  return \%new_track;
}

## PRIVATE METHOD
## Purpose   : populate the new runs hash with a track data
## Parameters:
# 1 = hash ref of the new runs hash
# 2 = track_id
# 3 = run object
# 4 = (optional) array ref of fastq paths (for private runs only)
sub _add_new_runs_track {
  my $self = shift;
  my ($track_list, $track_id, $run, $fastqs) = @_;

  $logger->debug("Generating track to add ($track_id)");
  my $strain = $run->sample->strain;
  my $production_name = $strain->production_name;
  my $taxon_id        = $strain->species->taxon_id;

  my $track_data = $track_list->{$production_name}->{$track_id};

  # Add several runs for the same track
  if (defined $track_data) {
    push @{ $track_data->{run_accs} }, $run->run_sra_acc if defined $run->run_sra_acc;
  } else {
    my ($merge_level, $merge_id) = $self->get_track_level($track_id);
    my $run_accs = defined $run->run_sra_acc ? [$run->run_sra_acc] : undef;
    $track_data = {
      run_accs => $run_accs,
      merge_level => $merge_level,
      merge_id => $merge_id,
      taxon_id => $taxon_id,
      fastqs => $fastqs
    };
  }
  $track_list->{$production_name}->{$track_id} = $track_data;
}

## INSTANCE METHOD
## Purpose   : returns the merge level of a track
## Parameters: a track_id
## Returns   : 1) merge_level 2) merge_id
sub get_track_level {
  my $self = shift;
  my ($track_id) = @_;

  my $track_data = $self->resultset('SraToActiveTrack')->search({
      'track_id' => $track_id,
  });
  my $track = $track_data->first;
  
  if (defined $track->merge_level and defined $track->merge_id) {
    return ($track->merge_level, $track->merge_id);
  }
  else {
    return;
  }
}

## PRIVATE METHOD
## Purpose   : guess the merge level of a track
## Purpose   : returns the merge_level
## Returns   : 1) merge_level 2) merge_id 3) merge_text
# Detail:
#   * If the track can be summarised as 1 SRA accession at a given level, then
#   the merge_text will be this accession
#   * If the track is a combination of several SRA accession of the same level (e.g.
#   several studies or several samples), then the merge_text is the sorted list of SRA
#   accessions separated by _ (e.g. "SRP000001_SRP000002")
#   * The merge_id is the md5sum of the merge_text if it is more than one SRA accession
sub _compute_track_level {
  my $self = shift;
  my ($track_id) = @_;
  
  my $track_data = $self->resultset('SraToActiveTrack')->search({
      'track_id' => $track_id,
  });
  my $track = $track_data->first;
  
  my @track_samples = uniq sort $track_data->get_column('sample_id')->all;
  $logger->debug('Samples: ' . Dumper(@track_samples));

  my ($merge_id, $merge_level);
  
  # Study?
  my @studies = uniq $track_data->get_column('study_id')->all;
  $logger->debug('studies: ' . Dumper(@studies));
  if (@studies > 1) {
    $logger->debug("Track $track_id has several studies: merge at taxon level");
    my $study = $self->resultset('Study')->search({
        study_id => \@studies,
      });
    my @study_accs = sort map { $_->study_sra_acc // $_->study_private_acc } $study->all;
    $merge_id = join '_', @study_accs;
    $merge_level = 'taxon';
  }
  elsif (@studies == 1) {
    # One study, but is it all the samples of the study?
    my $study_id = shift @studies;
    my $study_data = $self->resultset('SraToActiveTrack')->search({
        'study_id' => $study_id,
      });
    my @study_samples = uniq sort $study_data->get_column('sample_id')->all;
    
    $logger->debug("study vs track samples for track=$track_id, study=$study_id: " . @study_samples . ' vs ' . @track_samples);
    if (@study_samples == @track_samples) {
      $logger->debug(Dumper @studies);
      my $study = $self->resultset('Study')->search({
          study_id => $study_id
        })->first;
      $merge_id = $study->study_sra_acc // $study->study_private_acc;
      $merge_level = 'study';
    }
    else {
      $logger->debug("Study $study_id has more samples than the track: can't merge at study level for track $track_id");
      # Use the samples list as merge id
      my $samples = $self->resultset('Sample')->search({
          sample_id => \@track_samples,
        });
      my @sample_accs = sort map { $_->sample_sra_acc // $_->sample_private_acc } $samples->all;
      $merge_id = join '_', @sample_accs;
      $merge_level = @sample_accs == 1 ? 'sample' : 'taxon';
    }
  }
  else {
    # Sample?
    if (@track_samples == 1) {
      my $sample = $self->resultset('Sample')->search({
          sample_id => $track_samples[0]
        })->first;
      $merge_id = $sample->sample_sra_acc // $sample->sample_private_acc;
      $merge_level = 'sample';
    }
  }
  
  # Hash the merge_id if it contains several identifiers
  my $merge_text = $merge_id;
  if ($merge_id =~ /_/) {
    $merge_id = 'merged_' . md5_hex($merge_id);
  }
  
  return ($merge_level, $merge_id, $merge_text);
}

## INSTANCE METHOD
## Purpose   : for all active tracks, compute their merge_ids
## Parameters: force (bool) to force the change even if the merge_id exists
sub regenerate_merge_ids {
  my $self = shift;
  my ($force) = @_;
  
  my $search = {
      'status' => 'ACTIVE',
  };
  
  if (not $force) {
    $search->{merge_id} = undef;
  }
  
  my $track_data = $self->resultset('Track')->search($search);
  my @track_ids = $track_data->get_column('track_id')->all;
  
  for my $track_id (@track_ids) {
    my ($merge_level, $merge_id, $merge_text) = $self->_compute_track_level($track_id);
    
    my $track_update = $self->resultset('Track')->search({
        track_id  => $track_id,
      })->update({
        merge_level => $merge_level,
        merge_id    => $merge_id,
        merge_text  => $merge_text,
    });
  }
  
  return scalar @track_ids;
}

## INSTANCE METHOD
## Purpose   : Merge several tracks together
## Parameters: an array ref of SRA accessions
sub merge_tracks_by_sra_ids {
  my ($self, $sra_accs) = @_;
  
  # Merging means:
  # - Creation of a new track
  # - Inactivation of the constitutive, merged tracks (status=MERGED)
  # - Creation of a new sra_track link between the runs and the track
  
  
  #$self->_add_bundle_from_track($merged_track_id);
  
  # Get the list of tracks associated with them
  my @old_tracks = $self->get_tracks(sra_ids => $sra_accs);
  my @old_track_ids = map { $_->track_id } @old_tracks;
  $logger->debug("Run_ids to merge: " . join(',', @old_track_ids));
  
  # Check that there are multiple tracks to merge, abort otherwise
  my $n_tracks = scalar @old_track_ids;
  if ($n_tracks == 0) {
    carp "No tracks found to merge!";
    return;
  }
  elsif ($n_tracks == 1) {
    $logger->debug("Trying to merge tracks, but there is only one track to merge ($old_track_ids[0])");
    return;
  } else {
    $logger->debug(sprintf "Can merge %d tracks", scalar @old_track_ids);
    # Inactivate tracks as MERGED
    $self->inactivate_tracks(\@old_track_ids, 'MERGED');
  }
  
  # Check that the tracks are in one and only one bundle
  # No bundle: don't care
  # Several bundles: try to merge de bundles
  my $bundle_id;
  my @bundles = $self->_get_common_bundles(@old_tracks);
  if (@bundles == 1) {
    $bundle_id = $bundles[0]->bundle_id;
  } elsif (@bundles > 1) {
    my @bundle_ids = map { $_->bundle_id } @bundles;
    $bundle_id = $self->merge_bundles(@bundle_ids);
  }

  # Prepare the track title
  my @track_titles = uniq map { $_->title_auto } @old_tracks;
  my $track_title = shift @track_titles;
  
  # Prepare the track text
  my @track_texts = uniq map { $_->text_auto } @old_tracks;
  my $track_text = shift @track_texts;
  
  # Create a new merged track
  my $assembly_id = $old_tracks[0]->sra_tracks->next->run->sample->strain->assemblies->next->assembly_id;
  my @run_ids = map { map { {run_id => $_->run->run_id} } $_->sra_tracks } @old_tracks;
  my $merger_track = $self->resultset('Track')->create({
      title_auto => $track_title,
      text_auto => $track_text,
      sra_tracks => \@run_ids,
      track_analyses  => [
        {
          assembly_id => $assembly_id
        }
      ]
  });
  my $merged_track_id = $merger_track->track_id;
  $logger->debug(sprintf "Merged in track %d", $merged_track_id);
  
  # Link the new track to the bundle if any
  if ($bundle_id) {
    $logger->info("Link new merger to corresponding bundle");
    $self->_add_bundle_track($bundle_id, $merged_track_id); 
  } else {
    $logger->warn("Merge tracks but not linked to a bundle");
  }

  return $merged_track_id;
}

# Input: array of tracks objects from get_tracks
sub _get_common_bundles {
  my $self = shift;
  my @tracks = @_;
  
  my %bundles_hash;
  for my $track (@tracks) {
    my @bundle_tracks = $track->bundle_tracks->all;
    for my $bt (@bundle_tracks) {
      $bundles_hash{ $bt->bundle_id } = $bt->bundle;
    }
  }
  
  # Check number of bundles
  my @bundles = values %bundles_hash;
  return @bundles;
}

sub _merge_sample_tracks {
  my $self = shift;
  my ($sra_acc) = @_;
  
  # Retrieve samples
  my $samples = $self->_get_samples_from($sra_acc);
  
  foreach my $sample_acc (@$samples) {
    $logger->debug("Merge tracks for sample $sample_acc");
    $self->merge_tracks_by_sra_ids([$sample_acc]);
  }
}

## INSTANCE METHOD
## Purpose   : Merge several tracks together with SRA accessions
## Parameters: an array ref of SRA accessions
sub inactivate_tracks_by_sra_ids {
  my ($self, $sra_accs) = @_;
  
  # Get the list of tracks associated with them
  my @track_ids = map { $_->track_id } $self->get_tracks(sra_ids => $sra_accs);
  
  # Check that the number of tracks is the same as the number of provided accessions
  my $n_tracks = scalar @track_ids;
  my $n_sras   = scalar @$sra_accs;
  if ($n_tracks != $n_sras) {
    $logger->warn("Not the same number of tracks ($n_tracks) and SRA accessions ($n_sras). Abort inactivation.");
    return;
  }
  
  # All is well: inactivate
  $self->inactivate_tracks(\@track_ids, 'RETIRED');

  return;
}

## INSTANCE METHOD
## Purpose   : Merge several tracks together
## Parameters:
# 1) array ref of track_id
# 2) status text (default = RETIRED)
sub inactivate_tracks {
  my ($self, $track_ids_aref, $status) = @_;
  $status ||= 'RETIRED';
  
  my @tracks = map { { track_id => $_ } } @$track_ids_aref;
  $logger->debug(sprintf "Inactivated tracks: %s", join(',', @$track_ids_aref));
  my $tracks_update = $self->resultset('Track')->search(\@tracks)->update({
    status => $status,
  });

  # Also inactivate corresponding bundles
  #$self->_inactivate_bundles_for_tracks($track_ids_aref);
}

## PRIVATE METHOD
## Purpose   : Given a list of various SRA accessions, prepare the DBIx search
# to use find all of them (=or list)
## Parameters: array ref of SRA accessions
sub _format_sras_for_search {
  my $self = shift;
  my @sras_list = @_;
  
  my @sras;
  # Guess what table needs to be searched for each accession
  for my $sra_acc (@sras_list) {
    if ($sra_acc =~ /$sra_regex->{vb_study}/) {
      push @sras, { 'study.study_private_acc' => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{vb_experiment}/) {
      push @sras, { 'experiment.experiment_private_acc' => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{vb_run}/) {
      push @sras, { 'run.run_private_acc' => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{vb_sample}/) {
      push @sras, { 'sample.sample_private_acc' => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{study}/) {
      push @sras, { 'study.study_sra_acc' => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{experiment}/) {
      push @sras, { 'experiment.experiment_sra_acc' => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{run}/) {
      push @sras, { 'run.run_sra_acc' => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{sample}/) {
      push @sras, { 'sample.sample_sra_acc' => $sra_acc };
    }
     else {
       $logger->warn("Can't identify SRA accession: $sra_acc");
     }
  }
  return @sras;
}

1;

__END__

=head1 DESCRIPTION

This module is a role to interface the tracks part of the Bio::EnsEMBL::RNAseqDB object.

=head1 INTERFACE

=over

=item update_track

  function       : Update the fields of a track row
  args           : 
    1) track_id
    2) hash ref where the keys are track table columns
  
  usage:
  $rdb->update_track(1, { title_manual => 'Foobar' });

=item get_tracks()

  function       : search and retrieve tracks
  returntype     : array of DBIx track objects
  arguments      : see below. If no argument is given, return all active tracks.
  
  Selection arguments:
    - track_ids = array ref of track_ids integers
    - sra_ids   = ............ sra accessions strings
    - merge_ids = ............ merge ids strings
  
  Filter arguments:
    - assembly  = assembly name
    - all_assemblies = get all assemblies. Default: only retrieve the latest
    - species   = production_name
    - aligned   = 1 (with alignment files) or 0
    - status    = 'ACTIVE' (default), 'RETIRED', 'MERGED', OR '' (=all)
  
  usage:
    my @tracks = $rdb->get_tracks();
    my @tracks = $rdb->get_tracks(sra_ids => ['SRS0000001']);
    my @tracks = $rdb->get_tracks(track_ids => [1, 2]);
    my @tracks = $rdb->get_tracks(species => 'aedes_aegypti');
    my @tracks = $rdb->get_tracks(aligned => 0);
 
=item get_new_runs_tracks()

  function       : get a hash representing the sra tracks
  returntype     : hash of the form:
  
    production_name => {
      taxon_id        => 0,
      sra             => [ '' ],
    }
  
    Where the array sra includes a list of SRA accessions
  
  usage:
    my $new_tracks = $rdb->get_new_runs_tracks();
    
=item merge_tracks_by_sra_ids()

  function       : merge several tracks in a single one
  arg            : a ref array of a list of SRA accessions
  
  usage:
    my $sras = [ 'SRS000001', 'SRS000002' ];
    $rdb->merge_tracks_by_sra_ids($sras);
    
=item inactivate_tracks_by_sra_ids()

  function       : inactivate tracks from a list of SRA accessions
  arg[1]         : array ref of track ids
  
  usage:
    my $sras = [ 'SRS000001', 'SRS000002' ];
    $rdb->inactivate_tracks_by_sra_ids($sras);
    
=item inactivate_tracks()

  function       : inactivate tracks
  arg[1]         : array ref of track ids
  arg[2]         : new status ('RETIRED' or 'MERGED') - default is 'RETIRED'
  
  usage:
    my $track_ids = [ 1, 2 ];
    $rdb->inactivate_tracks(track_ids, 'MERGED');
    
=item get_track_level()

  function       : return the merge_level of a track
  arg[1]         : track_id
  return         : A string 'sample', 'study' or undef
  
  usage:
    my $track_id = 1;
    my $merge_level = $rdb->get_track_level(track_id);
    
=item regenerate_merge_ids

  function       : scans the tracks tables and add merge_id and merge_level to each track.
  arg[1]         : boolean to force recreating the merge_id/level even when it already exists.
  
  usage:
  $rdb->regenerate_merge_ids;
  
=item merge_tracks_by_sra_ids

  function       : Merge tracks using SRA accessions.
  arg[1]         : array ref of SRA accessions
  
  This method takes a list of SRA accessions, gets the corresponding list of tracks,
  and merges them. That means that a new track is created, linked to all SRA accessions,
  and the old tracks status is changed to 'MERGED'. They remain in the database for
  history purposed, but they can be removed.
  
  usage:
  $rdb->merge_tracks_by_sra_ids(['SRS00001', 'SRS000002']);

=item inactivate_tracks_by_sra_ids

  function       : Inactivate tracks using SRA accessions.
  arg[1]         : array ref of SRA accessions
  
  This method takes a list of SRA accessions, gets the corresponding list of tracks,
  and change their status to 'RETIRED'.
  
  usage:
  $rdb->inactivate_tracks_by_sra_ids(['SRS00001', 'SRS000002']);

=item inactivate_tracks

  function       : Inactivate tracks using track ids.
  args           : 
    1) array ref of SRA accessions
    2) [optional] new status text (default = 'RETIRED')
  
  usage:
  $rdb->inactivate_tracks([1, 2], 'MERGED');
    
=item guess_track_text

  function       : populate title_auto and text_auto for a given list of tracks
  args           : an array of track ids
  
  usage:
  $rdb->guess_track_text(1, 2, 3);

=back

=cut

