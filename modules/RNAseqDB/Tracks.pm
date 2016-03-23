use utf8;
package RNAseqDB::Tracks;
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
  #warn Dumper(\%new_track);
  return \%new_track;
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

