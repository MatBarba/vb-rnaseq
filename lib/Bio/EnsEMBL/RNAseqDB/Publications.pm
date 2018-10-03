package Bio::EnsEMBL::RNAseqDB::Publications;
use strict;
use warnings;
use Carp;
use Moose::Role;

use JSON qw(decode_json);
use Data::Dumper;
use Readonly;
use LWP::Simple qw( get );

use Log::Log4perl qw( :easy );
my $logger = get_logger();

use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);


sub add_study_publication_from_sra {
  my ($self, $sra_id, $pubmed_id) = @_;
  
  # Get the study id for the sra
  my $study_id = $self->_sra_to_study_id($sra_id);
  
  # Add the publication
  $self->add_study_publication($study_id, $pubmed_id);
}

sub _sra_to_study_id {
  my $self = shift;
  my ($sra_id) = @_;
  
  # Take one run_id to find the study
  my $run_id = $self->_sra_to_run_ids([$sra_id]);
  
  my $study_req = $self->resultset('Study')->search({
      'runs.run_id' => $run_id->[0]
    },
    {
      prefetch => { experiments => 'runs' }
  });
  
  my ($study) = $study_req->all;
  
  return $study->study_id;
}

sub add_study_publication {
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
  
  if ($pub_data) {
      my $pub_insert = $self->resultset('Publication')->create( $pub_data );
      $logger->debug("ADD publication $pubmed_id");
      return $pub_insert->id;
  } else {
      $logger->warn("No publication retrieved: skipped");
  }
}

sub _get_pubmed_data {
  my ($pubmed_id) = @_;
  return () if not defined $pubmed_id;
  
  my %data = (pubmed_id => $pubmed_id);
  
  my $REST_URL = 'https://www.ebi.ac.uk/europepmc/webservices/rest/search?resultType=core&format=json&query=ext_id:';
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

sub get_publications {
  my $self = shift;
  
  my $pub_request = $self->resultset('Publication')->search({},
    {
      prefetch => 'study_publications',
  });
  return $pub_request->all;
}

1;

=head1 DESCRIPTION

Bio::EnsEMBL::RNAseqDB::Publications - Publication role for the RNAseq DB.

This module is a role to interface the publications part of the Bio::EnsEMBL::RNAseqDB object.

=head1 INTERFACE

=over

=item add_study_publication

  function       : add a publication linked to a study
  arguments      :
    1= study_id (table id)
    2= pubmed_id

=item add_study_publication_from_sra

  function       : add a publication linked to a study identified by an sra accession
  arguments      :
    1= sra_id (study, experiment, run or sample id)
    2= pubmed_id

=item get_publications

  function       : Retrieve all current publications from the DB
  arguments      : none
  return         : array of Publication resultsets

=back

=cut

