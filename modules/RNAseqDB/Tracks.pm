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
  my ($self, $sample_id) = @_;
  
  # Does the track already exists?
  my $track_req = $self->resultset('Track')->search({
      'sra_tracks.sample_id' => $sample_id,
  },
  {
    prefetch    => 'sra_tracks',
  });

  my @res_tracks = $track_req->all;
  my $num_tracks = scalar @res_tracks;
  if ($num_tracks > 0) {
    $logger->warn("WARNING: Track already exists for sample $sample_id");
    return;
  }
  
  # Insert a new track and a link sra_track
  # NB: the default is a merging at the sample level
  $logger->info("ADDING track for $sample_id");
  
  # Add the track itself
  my $track_insertion = $self->resultset('Track')->create({});
  
  # Add the link from the sample to the track
  my $track_id = $track_insertion->id;
  $self->_add_sra_track($sample_id, $track_id);
  
  # Also create a drupal node for this track
  $self->_add_drupal_node_from_track($track_id);
  
  return;
}

sub _add_sra_track {
  my ($self, $sample_id, $track_id) = @_;
  
  # First, check that the link doesn't already exists
  my $sra_track_search = $self->resultset('SraTrack')->search({
      sample_id    => $sample_id,
      track_id  => $track_id,
  });
  my $links_count = $sra_track_search->all;
  if ($links_count > 0) {
    $logger->warn("There is already a link between sample $sample_id and track $track_id");
    return;
  }
  
  my $sra_track_insertion = $self->resultset('SraTrack')->create({
      sample_id    => $sample_id,
      track_id  => $track_id,
  });
  return;
}

sub get_new_sra_tracks {
  my ($self, $species) = @_;
  
  my $track_req = $self->resultset('SraTrack')->search({
      'track.file_id' => undef,
      'track.status'  => 'ACTIVE',
      'sample.sample_sra_acc' => { '!=', undef },
    },
    {
    prefetch    => ['track', { 'sample' => { 'strain' => 'species' } } ],
  });

  my @res_tracks = $track_req->all;
  
  #$track_req->result_class('DBIx::Class::ResultClass::HashRefInflator');
  
  if (defined $species) {
    @res_tracks = grep { $_->sample->strain->production_name eq $species } @res_tracks;
  }
  
  my %new_track = ();
  for my $track (@res_tracks) {
    my $track_id = $track->track_id;
    my $sample = $track->sample;
    my $strain = $sample->strain;
    my $production_name = $strain->production_name;
    my $taxon_id        = $strain->species->taxon_id;
    $new_track{$production_name}{taxon_id} = $taxon_id;
    
    push @{ $new_track{$production_name}{tracks}{ $track_id } }, $sample->sample_sra_acc;
  }
  return \%new_track;
}

sub merge_tracks_by_sra_ids {
  my ($self, $sra_accs) = @_;
  
  # Merging means:
  # - Creation of a new track
  # - Inactivation of the constitutive, merged tracks (status=MERGED)
  # - Creation of a new sra_track link between the samples and the track
  
  # Get the list of SRA samples from the list of SRA_ids
  my $sample_ids = $self->_sra_to_sample_ids($sra_accs);
  if (not defined $sample_ids) {
    $logger->warn("Abort merging: can't find all the members to merge");
    return;
  }
  
  # Get the list of tracks associated with them
  my $old_track_ids = $self->_get_tracks_for_samples($sample_ids);

  # Check that there are multiple tracks to merge, abort otherwise
  if (scalar @$old_track_ids == 1) {
    $logger->warn("Trying to merge tracks, but there is already one track for them");
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
  
  # Then, create a link for each sample to the new merged track
  map { $self->_add_sra_track($_, $merged_track_id) } @$sample_ids;
  
  # Also create and link a drupal node to the track
  $self->_add_drupal_node_from_track($merged_track_id);

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

sub _get_tracks_for_samples {
  my ($self, $sample_ids) = @_;
  
  my @samples_conds = map { { 'sra_tracks.sample_id' => $_ } } @$sample_ids;
  
  my $tracks_req = $self->resultset('Track')->search({
      -or => \@samples_conds,
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
    if ($sra_acc =~ /$sra_regex->{study}/) {
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
    $rdb->get_new_sra_tracks();

=head1 DESCRIPTION

This module is a role to interface the tracks part of the RNAseqDB::DB object.

=head1 INTERFACE

=over
 
=item get_new_sra_tracks()

  function       : get a hash representing the sra tracks
  returntype     : hash of the form:
  
    production_name => {
      taxon_id        => 0,
      sra             => [ '' ],
    }
  
    Where the array sra includes a list of SRA accessions
  
  usage:
    my $new_tracks = $rdb->get_new_sra_tracks();
    
=item merge_tracks_by_sra_ids()

  function       : merge several tracks in a single one
  arg            : a ref array of a list of SRA accessions
  
  usage:
    my $sras = [ 'SRS000001', 'SRS000002' ];
    $rdb->merge_tracks_by_sra_ids($sras);
    
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

