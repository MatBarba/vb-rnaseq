use utf8;
package Bio::EnsEMBL::RNAseqDB::Publications;
use Moose::Role;

use strict;
use warnings;
use Log::Log4perl qw( :easy );

my $logger = get_logger();
use Data::Dumper;
use Readonly;
use Try::Tiny;
use LWP::Simple qw( get );
use JSON;

use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);

sub _add_study_publication {
  my ($self, $study_id, $pubmed_id) = @_;
  if (not defined $pubmed_id) {
    $logger->debug("No pubmed defined for study $study_id");
    return 0;
  }
  
  # Get publication id
  my $pub_id = $self->_get_publication_id($pubmed_id);
  
  if (not defined $pub_id) {
    $logger->warn("WARNING: can't get a publication id for pubmed $pubmed_id");
    return 0;
  }
  
  # See if a link already exists
  my $link_check = $self->resultset('StudyPublication')->search({
      study_id => $study_id,
      publication_id => $pub_id
  });

  my @pubs_results = $link_check->all;
  my $num_pubs = scalar @pubs_results;
  if ($num_pubs == 1) {
    $logger->debug("$pubmed_id is already linked to study $study_id");
    return 0;
  }
  elsif ($num_pubs > 1) {
    $logger->warn("WARNING: several links between $pubmed_id and study $study_id");
    return 0;
  }
  
  # Ok, insert the link
  my $link_insert = $self->resultset('StudyPublication')->create({
      study_id => $study_id,
      publication_id => $pub_id
  });
  $logger->debug("ADD publication link $study_id - $pubmed_id");
  return 1;
}

sub _get_publication_id {
  my ($self, $pubmed_id) = @_;
  
  # Get the publication id, if it already exists
  my $pubid_request = $self->resultset('Publication')->search({
      pubmed_id => $pubmed_id
  });

  my @res_pubids = $pubid_request->all;
  my $num_pubid = scalar @res_pubids;
  if ($num_pubid == 1) {
    return $res_pubids[0]->get_column('publication_id');
  }
  elsif ($num_pubid > 1) {
    $logger->warn("WARNING: several publications with the same pubmed_id? $pubmed_id");
    return;   
  }
  
  # No publication with this pubmed_id: let's insert it
  my $pub_data = _get_pubmed_data($pubmed_id);
  
  my $pub_insert = $self->resultset('Publication')->create( $pub_data );
  $logger->debug("ADD publication $pubmed_id");
  return $pub_insert->id;
}

sub _get_pubmed_data {
  my ($pubmed_id) = @_;
  return () if not defined $pubmed_id;
  
  my %data = (pubmed_id => $pubmed_id);
  
  my $REST_URL = 'http://www.ebi.ac.uk/europepmc/webservices/rest/search?resulttype=core&format=json&query=ext_id:';
  my $url = $REST_URL . $pubmed_id;
  $logger->debug( "Get data from $url" );
  my $pub_content = get $url;
  
  if (not defined $pub_content) {
    $logger->warn("WARNING: can't fetch publication data from Europe PMC ($pubmed_id)");
    return ();
  }
  
  my $pub_data = decode_json($pub_content);
  my $res_list = $pub_data->{resultList}->{result};
  my $num_res = scalar @$res_list;
  
  if ($num_res == 0) {
    $logger->warn("WARNING: no publication found with id=$pubmed_id");
    return ();
  } elsif ($num_res > 1) {
    $logger->warn("WARNING: several publications found with id=$pubmed_id");
    return ();
  }
  
  my $pub = shift @$res_list;
  $data{doi}      = $pub->{doi};
  $data{year}     = $pub->{journalInfo}->{yearOfPublication};
  $data{title}    = $pub->{title};
  $data{abstract} = $pub->{abstractText};
  $data{authors}  = join(', ', map { $_->{fullName} } @{ $pub->{authorList}->{author} });
  
  return \%data;
}

1;


=head1 NAME

Bio::EnsEMBL::RNAseqDB::Publications - Publication role for the RNAseq DB

=head1 DESCRIPTION

This module is a role to interface the publications part of the Bio::EnsEMBL::RNAseqDB object.

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

