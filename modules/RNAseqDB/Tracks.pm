use utf8;
package RNAseqDB::Tracks;
use Moose::Role;

use strict;
use warnings;
use Log::Log4perl qw( :easy );
use List::MoreUtils qw(uniq);

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
  
  # Also create a drupal node for this track
  $self->_add_drupal_node_from_track($track_id);
  
  return;
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
  
  my $track_req = $self->resultset('SraTrack')->search({
      'track.file_id' => undef,
      'track.status'  => 'ACTIVE',
      'run.run_sra_acc' => { '!=', undef },
    },
    {
    prefetch    => ['track', { 'run' => { 'sample' => { 'strain' => 'species' } } } ],
  });
  
  my @res_tracks = $track_req->all;
  
  #$track_req->result_class('DBIx::Class::ResultClass::HashRefInflator');
  
  if (defined $species) {
    @res_tracks = grep { $_->run->sample->strain->production_name eq $species } @res_tracks;
  }
  
  my %new_track = ();
  for my $track (@res_tracks) {
    my $track_id = $track->track_id;
    my $run = $track->run;
    my $sample = $run->sample;
    my $strain = $sample->strain;
    my $production_name = $strain->production_name;
    my $taxon_id        = $strain->species->taxon_id;
    $new_track{$production_name}{taxon_id} = $taxon_id;
    
    push @{ $new_track{$production_name}{tracks}{ $track_id } }, $run->run_sra_acc;
  }
  return \%new_track;
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
  
  # Also create and link a drupal node to the track
  $self->_add_drupal_node_from_track($merged_track_id);

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

  # Also inactivate corresponding drupal_nodes
  $self->_inactivate_drupal_nodes($track_ids_aref);
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

RNAseqDB::Tracks - Tracks role for the RNAseq DB


=head1 VERSION

This document describes RNAseqDB::Tracks version 0.0.1


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
    $rdb->inactivate_tracks(trac_ids, 'MERGED');
    
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

