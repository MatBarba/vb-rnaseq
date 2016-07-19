package RNAseqDB::Track;
use 5.10.0;
use utf8;
use Moose::Role;

use strict;
use warnings;
use Carp;
use Log::Log4perl qw( :easy );
use List::MoreUtils qw(uniq);
use File::Spec;
use Digest::MD5::File qw(file_md5_hex);
use Digest::MD5 qw(md5_hex);
use Try::Tiny;
use Memoize;

my $logger = get_logger();
use Data::Dumper;
use Readonly;
use RNAseqDB::Common;
my $common = RNAseqDB::Common->new();
my $sra_regex = $common->get_sra_regex();

sub _add_track {
  my ($self, $run_id) = @_;
  
  # Does the track already exists?
  my $track_req = $self->resultset('Track')->search({
      'sra_tracks.run_id' => $run_id,
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
  
  # Insert a new track and a link sra_track
  $logger->info("ADDING track for $run_id");
  
  # Add the track itself
  my $track_insertion = $self->resultset('Track')->create({});
  
  # Add the link from the run to the track
  my $track_id = $track_insertion->id;
  $self->_add_sra_track($run_id, $track_id);
  
  # Also create a bundle for this track
  $self->_add_bundle_from_track($track_id);
  
  # Finally, try to create a title + description for the track
  $self->guess_track_text($track_id);
  
  return;
}

sub get_track {
  my $self = shift;
  my ($track_id) = @_;
  
  return if not defined $track_id;
  
  my $track_req = $self->resultset('Track')->search({
      'track_id' => $track_id,
  });
  my $track = $track_req->first;
  return $track;
}

sub update_track {
  my $self = shift;
  my ($track_id, $track_data) = @_;
  
  $self->resultset('Track')->search({
      'track_id'  => $track_id,
    })->update($track_data);
}

sub get_track_ids {
  my $self = shift;
  my ($species) = @_;
  
  my %search;
  $search{production_name} = $species if $species;
  my $track_req = $self->resultset('SraToActiveTrack')->search(\%search);
  my @track_ids = uniq map { $_->track_id } $track_req->all;
  return @track_ids;
}

sub guess_track_text {
  my $self = shift;
  my @track_ids = @_;
  
  for my $track_id (@track_ids) {
    my $req = $self->resultset('Track')->search({
        'me.track_id' => $track_id,
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
        title_auto        => $title,
        description_auto  => $description,
      });
  }
  
  return 1;
}

sub _add_sra_track {
  my ($self, $run_id, $track_id) = @_;
  
  # First, check that the link doesn't already exists
  my $sra_track_search = $self->resultset('SraTrack')->search({
      run_id    => $run_id,
      track_id  => $track_id,
  });
  my $links_count = $sra_track_search->all;
  if ($links_count > 0) {
    $logger->warn("There is already a link between run $run_id and track $track_id");
    return;
  }
  
  my $sra_track_insertion = $self->resultset('SraTrack')->create({
      run_id    => $run_id,
      track_id  => $track_id,
  });
  return;
}

sub get_new_runs_tracks {
  my $self = shift;
  my ($species) = @_;
  
  my $search_href = {
    'track.status' => 'ACTIVE',
  };
  $search_href->{'strain.production_name'} = $species if defined $species;
  
  my $track_req = $self->resultset('SraTrack')->search(
    $search_href,
    {
    prefetch    => [ 'track', { 'run' => { 'sample' => { 'strain' => 'species' } } } ],
  });
  
  my @res_tracks = $track_req->all;
  
  if (defined $species) {
    @res_tracks = grep { $_->run->sample->strain->production_name eq $species } @res_tracks;
  }
  $logger->debug((@res_tracks+0) . " tracks to consider as new");
  
  my %new_track = ();
  for my $track (@res_tracks) {
    my $track_id = $track->track_id;
    $logger->debug("Checking track $track_id");
    
    # Check if this track has any file already (bigwig and bam)
    my $files_req = $self->resultset('File')->search({
        'track_id' => $track_id,
      });
    my @files = $files_req->all;
    
    # We do have some files!
    if (@files) {
      $logger->debug("The track $track_id already has files: no need to align");
    }
    else {
      $logger->debug("The track $track_id has no files: to align");
      # Is this a private data? In that case, get the fastq files
      if (defined $track->run->run_private_acc) {
        my $fastq_req = $self->resultset('PrivateFile')->search({
            run_id  => $track->run->run_id
        });
        my @fastq = $fastq_req->get_column('path')->all;
        $self->_add_new_runs_track(\%new_track, $track, \@fastq);
      }
      # Otherwise, the SRA accessions will suffice
      else {
        $self->_add_new_runs_track(\%new_track, $track);
      }
    }
  }
  return \%new_track;
}
   
sub _add_new_runs_track {
  my $self = shift;
  my ($track_list, $track, $fastqs) = @_;

  my $track_id = $track->track_id;
  $logger->debug("Generating track to add ($track_id)");
  my $run = $track->run;
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

sub get_track_id_from_merge_id {
  my $self = shift;
  my ($merge_id) = @_;
  
  $logger->debug("Retrieve track_id for merge_id $merge_id");
  
  my $track_req = $self->resultset('Track')->search({
      merge_id => $merge_id,
    });
  my $track = $track_req->first;
  
  if ($track) {
    return  $track->track_id;
  }
  else {
    $logger->warn("Can't get a track with merge_id = $merge_id");
    return;
  }
}

sub add_track_results {
  my $self = shift;
  my ($track_id, $commands, $files, $version) = @_;
  
  $logger->debug("Add data for track $track_id");
  
  # Add commands
  my $cmds_ok = $self->_add_commands($track_id, $commands, $version);
  return if not $cmds_ok;
  
  # Add files
  my $files_ok = $self->_add_files($track_id, $files);
  return if not $files_ok;
  
  return 1;
}

sub _add_commands {
  my $self = shift;
  my ($track_id, $commands, $version) = @_;
  
  # First, check that there is no command for this track already
  my $cmd_req = $self->resultset('Analysis')->search({
      track_id => $track_id,
    });
  my @cmds = $cmd_req->all;
  
  # Some commands: skip
  if (@cmds) {
    $logger->warn("WARNING: the track $track_id already has commands. Skip addition.");
    return;
  }
  
  # Add the commands!
  my @commands = map { split /\s*;\s*/ } @cmds;
  for my $command (@$commands) {
    my $desc = $self->_guess_analysis_program($command);
    my ($an_id, $an_version);
    if (not $desc) {
      carp "No analysis description found for command $command";
    } else {
      $an_id   = $desc->analysis_description_id;
      $an_version = $version if ($desc->type eq 'aligner' and defined $version),
    }
    my $cmd = $self->resultset('Analysis')->create({
        track_id                => $track_id,
        command                 => $command,
        analysis_description_id => $an_id,
        version                 => $an_version
      });
  }
  
  return 1;
}

sub _guess_analysis_program {
  my $self = shift;
  my ($command) = @_;
  
  my @descriptions = $self->_load_analysis_descriptions;
  
  foreach my $desc (@descriptions) {
    my $pattern = $desc->pattern;
    if ($command =~ /$pattern/) {
      return $desc;
    }
  }
  return;
}

#memoize('_load_analysis_descriptions');
sub _load_analysis_descriptions {
  my $self = shift;
  
  my $req = $self->resultset('AnalysisDescription');
  my @descriptions = $req->all;
  
  return @descriptions;
}

sub _add_files {
  my $self = shift;
  my ($track_id, $paths) = @_;
  
  # First, check that there is no files for this track already
  # (Except for fastq files)
  my $file_req = $self->resultset('File')->search({
      track_id => $track_id,
    });
  my @files = $file_req->all;
  
  # Some files: skip
  if (@files) {
    $logger->warn("WARNING: the track $track_id already has files. Skip addition.");
    return;
  }
  
  # Add the files!
  for my $path (@$paths) {
    # Only keep the filename, not the path
    my ($vol, $dir, $file) = File::Spec->splitpath($path);
    
    # Determine the type of the file from its extension
    my $type;
    if ($file =~ /\.bw$/) {
      $type = 'bigwig';
    }
    elsif ($file =~ /\.bam$/) {
      $type = 'bam';
      push @$paths, $path . '.bai';
    }
    elsif ($file =~ /\.bam.bai$/) {
      $type = 'bai';
    }
    
    # Get md5sum file
    my $file_md5;
    #try {
    #  $file_md5 = file_md5_hex($path);
    #}
    #catch {
    #  warn "Can't find file for md5sum: $path";
    #};
    
    my $cmd = $self->resultset('File')->create({
        track_id => $track_id,
        path     => $file,
        type     => $type,
        md5      => $file_md5,
      });
  }
  
  return 1;
}

sub merge_tracks_by_sra_ids {
  my ($self, $sra_accs) = @_;
  
  # Merging means:
  # - Creation of a new track
  # - Inactivation of the constitutive, merged tracks (status=MERGED)
  # - Creation of a new sra_track link between the runs and the track
  
  # Get the list of SRA runs from the list of SRA_ids
  my $run_ids = $self->_sra_to_run_ids($sra_accs);
  if (not defined $run_ids) {
    warn "Abort merging: can't find all the members to merge";
    return;
  }
  
  # Get the list of tracks associated with them
  my $old_track_ids = $self->_get_tracks_for_runs($run_ids);

  # Check that there are multiple tracks to merge, abort otherwise
  my $n_tracks = scalar @$old_track_ids;
  if ($n_tracks == 0) {
    warn "No tracks found to merge!";
    return;
  }
  elsif ($n_tracks == 1) {
    $logger->warn("Trying to merge tracks, but there is only one track to merge");
    return;
  } else {
    $logger->debug(sprintf "Can merge %d tracks", scalar @$old_track_ids);
    # Inactivate tracks as MERGED
    $self->inactivate_tracks($old_track_ids, 'MERGED');
  }
  
  # Create a new merged track
  my $merger_track = $self->resultset('Track')->create({});
  my $merged_track_id = $merger_track->track_id;
  $logger->debug(sprintf "Merged in track %d", $merged_track_id);
  
  # Then, create a link for each run to the new merged track
  map { $self->_add_sra_track($_, $merged_track_id) } @$run_ids;
  
  # Also create and link a bundle to the track
  $self->_add_bundle_from_track($merged_track_id);

  return;
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

sub inactivate_tracks_by_sra_ids {
  my ($self, $sra_accs) = @_;
  
  # Get the list of SRA runs from the list of SRA_ids
  my $run_ids = $self->_sra_to_run_ids($sra_accs);
  if (not defined $run_ids) {
    $logger->warn("Abort inactivation: can't find all the members listed");
    return;
  }
  
  # Get the list of tracks associated with them
  my $track_ids = $self->_get_tracks_for_runs($run_ids);
  
  # Check that the number of tracks is the same as the number of provided accessions
  my $n_tracks = scalar @$track_ids;
  my $n_sras   = scalar @$sra_accs;
  if ($n_tracks != $n_sras) {
    $logger->warn("Not the same number of tracks ($n_tracks) and SRA accessions ($n_sras). Abort inactivation.");
    return;
  }
  
  # All is well: inactivate
  $self->inactivate_tracks($track_ids, 'RETIRED');

  return;
}

sub inactivate_tracks {
  my ($self, $track_ids_aref, $status) = @_;
  $status ||= 'RETIRED';
  
  my @tracks = map { { track_id => $_ } } @$track_ids_aref;
  $logger->debug(sprintf "Inactivated tracks: %s", join(',', @$track_ids_aref));
  my $tracks_update = $self->resultset('Track')->search(\@tracks)->update({
    status => $status,
  });

  # Also inactivate corresponding bundles
  $self->_inactivate_bundles($track_ids_aref);
}

sub _get_tracks_for_runs {
  my ($self, $run_ids) = @_;
  
  my @runs_conds = map { { 'sra_tracks.run_id' => $_ } } @$run_ids;
  
  my $tracks_req = $self->resultset('Track')->search({
      -or => \@runs_conds,
      -and => { status => 'ACTIVE' },
    },
    {
      prefetch  => 'sra_tracks',
  });
  
  my @tracks = map { $_->track_id } $tracks_req->all;
  
  return \@tracks;
}

sub _get_active_tracks {
  my ($self) = @_;
  
  my $track_search = $self->resultset('Track')->search({
    status  => 'ACTIVE',
  });
  my $tracks = $track_search->all;
  return $tracks;
}

sub get_tracks_from_sra {
  my ($self, $sras_aref) = @_;
  
  # Format sra ids
  my $sras_search = $self->_format_sras_for_search($sras_aref);
  
  $logger->debug("Get tracks for " . join( ',',  @$sras_aref));
  my $tracks_get = $self->resultset('SraToActiveTrack')->search($sras_search);
  
  my @tracks = $tracks_get->all;
  my @track_ids = uniq map { $_->track_id } @tracks;
  $logger->debug("Tracks found: @track_ids");
  return \@track_ids;
}

sub _format_sras_for_search {
  my ($self, $sras_aref) = @_;
  
  my @sras;
  for my $sra_acc (@$sras_aref) {
    if ($sra_acc =~ /$sra_regex->{vb_study}/) {
      push @sras, { study_private_acc => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{vb_experiment}/) {
      push @sras, { experiment_private_acc => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{vb_run}/) {
      push @sras, { run_private_acc => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{vb_sample}/) {
      push @sras, { 'sample_private_acc' => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{study}/) {
      push @sras, { study_sra_acc => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{experiment}/) {
      push @sras, { experiment_sra_acc => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{run}/) {
      push @sras, { run_sra_acc => $sra_acc };
    }
    elsif ($sra_acc =~ /$sra_regex->{sample}/) {
      push @sras, { 'sample_sra_acc' => $sra_acc };
    }
     else {
       $logger->warn("Can't identify SRA accession: $sra_acc");
     }
  }
  return \@sras;
}

1;

__END__


=head1 NAME

RNAseqDB::Track - Track role for the RNAseq DB


=head1 VERSION

This document describes RNAseqDB::Track version 0.0.1


=head1 SYNOPSIS

    # Get the list of new SRA tracks to create
    $rdb->get_new_runs_tracks();

=head1 DESCRIPTION

This module is a role to interface the tracks part of the RNAseqDB::DB object.

=head1 INTERFACE

=over
 
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
    
=item get_tracks_from_sra

  function       : retrieve a list of tracks
  arg            : a ref array of SRA accessions
  return         : a ref array of track_ids
  
  usage:
    my $sras = [ 'SRS000001', 'SRS000002' ];
    my $track_ids = $rdb->get_tracks_from_sras($sras);
    
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
    
=item get_track_id_from_merge_id()

  function       : map a merge_id to a track_id
  arg[1]         : merge_id
  
  usage:
    my $track_id = $rdb->get_track_id_from_merge_id('SRS260844_SRS260845');
    
=item add_track_results()
  
  function       : import a list of commands and files for a given track
  arg[1]         : track_id
  arg[2]         : array ref to a list of commands used to create the files
  arg[3]         : array ref to a list of generated files
  
  Note: only the filenames will be used.
  
  usage:
  $rdb->add_track_results($track_id, $commands_aref, $files_aref);
  
=item regenerate_merge_ids

  function       : scans the tracks tables and add merge_id and merge_level to each track.
  arg[1]         : boolean to force recreating the merge_id/level even when it already exists.
  
  usage:
  $rdb->regenerate_merge_ids;
    
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

