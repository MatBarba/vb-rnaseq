#!/usr/bin/env perl
use 5.10.00;
use strict;
use warnings;
use Readonly;
use Carp;
use autodie;

use List::Util qw(sum);
use List::MoreUtils qw(uniq);
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;
use Readonly;
use LWP::Simple qw(get is_success);
use XML::LibXML;
use open qw(:std :utf8);

use Bio::EnsEMBL::RNAseqDB;
use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

Readonly my $run_info_template => 'http://www.ebi.ac.uk/ena/data/warehouse/search?query="tax_eq(%s) AND library_source="TRANSCRIPTOMIC""&result=read_run&display=xml';
Readonly my $fastq_size_template => 'http://www.ebi.ac.uk/ena/data/warehouse/filereport?accession=%s&result=read_run&fields=fastq_bytes,submitted_bytes';


###############################################################################
# MAIN
# Get command line args
my %opt = %{ opt_check() };

# Connect to the database schema
my $db = Bio::EnsEMBL::RNAseqDB->connect(
  "dbi:mysql:host=$opt{host}:port=$opt{port}:database=$opt{db}",
  $opt{user},
  $opt{password}
);

# Retrieve the list of species
my @species = get_species_from_db($db, \%opt);
my @db_studies = get_studies_from_db($db, \%opt);
my %db_study = map { ($_->study_sra_acc || $_->study_private_acc) => 1 } @db_studies;

# List the species
if ($opt{list_species}) {
  carp STDERR "No species in database" if not @species;
  for my $sp (@species) {
    for my $str ($sp->strains) {
      for my $ass ($str->assemblies) {
        my $latest = $ass->latest;
        my $last_flag = $latest ? '' : ' (old)';
        say STDERR sprintf("%s\t%s\t%s%s", $sp->taxon_id, $str->production_name, $ass->assembly, $last_flag);
      }
    }
  }
}

if ($opt{search}) {
  my @search_list = @species;
  say STDERR "Searching for " . (@search_list+0) . " taxa";
  
  my @fields = qw(
  species
  status
  accession
  exps
  runs
  samps
  fastq_bytes
  pubmed
  center
  title
  abstract
  );
  say join "\t", @fields;
  search(\@search_list, \%db_study, \%opt);
}

###############################################################################
# SUBS

sub get_species_from_db {
  my ($db, $opt) = @_;

  my %species_search;
  $species_search{'strains.production_name'} = $opt->{species} if $opt->{species};
  if ($opt->{antispecies}) {
    my @anti = split ',', $opt->{antispecies};
    $species_search{'-not'} = [ map { { production_name => $_ } } @anti ];
  }
  my @species = $db->resultset('Species')->search(
    \%species_search,
    { prefetch =>
      {
        'strains' => 
        [
        'assemblies',
        { 'samples' => { 'runs' => { 'experiment' => 'study' } } },
        ],
      } 
    }
  );
}

sub get_studies_from_db {
  my ($db, $opt) = @_;

  my %species_search;
  $species_search{'strains.production_name'} = $opt->{species} if $opt->{species};
  if ($opt->{antispecies}) {
    my @anti = split ',', $opt->{antispecies};
    $species_search{'-not'} = [ map { { production_name => $_ } } @anti ];
  }
  my @studies = $db->resultset('Study')->search({}, 
    {
      prefetch => { 'experiments' => { 'runs' => 'sample' } }
    }
  );
}

sub search {
  my ($list, $db_study, $opt) = @_;
  
  for my $species (@$list) {
    search_taxon($species, $db_study, $opt);
  }
}

sub search_taxon {
  my ($species, $db_study, $opt) = @_;
  
  say STDERR "Searching for RNAseq studies for " . $species->binomial_name . "... ";
  
  my @strains = $species->strains;
  my @studies = get_studies_for_taxon($species->taxon_id, $opt);
  
  say STDERR (@studies+0) . " studies found";
  
  # Only print the studies that are not in the DB
  map { print_study($_, $species, 'inDB') } grep { $db_study{$_->accession} } @studies;
  map { print_study($_, $species, 'NEW ') } grep { not $db_study{$_->accession} } @studies;
}

sub print_study {
  my ($st, $species, $category) = @_;
  
  my $experiments = $st->experiments;
  my $runs        = $st->runs;
  my $samples     = $st->samples;
  my $abstract    = $st->abstract // '';
  $abstract =~ s/ *\R+/ /g;  # Change newlines to spaces
  my $pubmed_id = get_pubmed_id($st) // '';
  my @line = (
    $species->binomial_name,
    $category,
    $st->accession,
    @$experiments+0,
    @$runs+0,
    @$samples+0,
    $st->{fastq_size} // 0,
    $pubmed_id,
    $st->center_name,
    $st->title,
    $abstract,
  );
  say join("\t", @line);
}

sub get_pubmed_id {
  my ($study) = @_;
  
  my @pubmed_links = grep {
    defined($_->{XREF_LINK}->{DB} )
      and $_->{XREF_LINK}->{DB} eq 'pubmed'
  } @{ $study->links() };

  my @pubmed_ids;
  foreach my $pubmed_link (@pubmed_links) {
    push @pubmed_ids, $pubmed_link->{XREF_LINK}->{ID};
  }
  #carp sprintf("WARNING: the study %s has several pubmed_ids: %s", $study->accession, join(',', @pubmed_ids)) if @pubmed_ids > 1;
  
  return join(',', @pubmed_ids);
}

sub get_studies_for_taxon {
  my ($taxon_id, $opt) = @_;
  $opt //= {};
  
  my $url = sprintf($run_info_template, $taxon_id);
  #say $url;
  my $xml = get $url or croak "Download failed for $url";
  my $dom = XML::LibXML->load_xml(string => $xml);
  
  # Extract study ids from the XML
  my %study;
  
  my $runs = $dom->findnodes('//RUN');
  my $count = 0;
  RUN : foreach my $run ($runs->get_nodelist) {
    my $run_id = $run->findnodes('.//PRIMARY_ID')->shift()->textContent;
    my $xrefs = $run->findnodes('.//XREF_LINK');
    XREF : foreach my $xref ($xrefs->get_nodelist) {
      my $DB = $xref->findnodes('./DB')->shift()->textContent;
      if ($DB eq 'ENA-STUDY') {
        my $study_id = $xref->findnodes('./ID')->shift()->textContent;
        
        # Commpute the size of the fasta
        my $run_fastq_size = exists $opt->{add_size} ? get_fastq_size($run_id, $study_id) : 0;
        
        # Save the count for the study
        $study{$study_id} += $run_fastq_size;
        if (++$count % 10 == 0) {
          sleep 1;
        }
      }
    }
  }
  
  my @studies;
  for my $study_id (keys %study) {
    my $study = get_study($study_id);
    my $size = $study{$study_id};
    $study->{fastq_size} = $size;
    push @studies, $study;
  }
  return @studies;
}

sub get_study {
  my $id = shift;
  
  my $adaptor = get_adaptor('study');
  my $study = $adaptor->get_by_accession($id);
  
  return $study->[0];
}

sub get_fastq_size {
  my ($run_id, $study_id) = @_;
  
  my $url = sprintf($fastq_size_template, $run_id);
  my $run_text = get $url or croak "Download failed for $url";
  sleep 0.5;
  
  # We only want the second line data
  my @lines = split /\R+/, $run_text;
  if (@lines == 1) {
    say STDERR "$study_id: No fastq data for $run_id";
    return 0;
  }
  
  # ena fastq or submitted fastq?
  my ($ena_fastq, $sub_fastq) = split /\t+/, $lines[1];
  my $sizes = $ena_fastq ? $ena_fastq : $sub_fastq;
  
  if ($sizes) {
    my $size = sum split(/;/, $sizes);
    return $size;
  } else {
    carp "No fastq size available for $run_id";
    return 0;
  }
}

###############################################################################
# Parameters and usage
# Print a simple usage note
sub usage {
  my $error = shift;
  my $help = '';
  if ($error) {
    $help = "[ $error ]\n";
  }
  $help .= <<'EOF';
    This simple script helps to find controlled vocabulary in tracks.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Actions:
    --list_species    : list the current species in the database
    
    --species <str>     : production_name to only search for one species
    --antispecies <str> : production_name of species to exclude
    --add_size        : retrieve total fastq size of files (takes longer)
    
    --help            : show this help message
    --verbose         : show detailed progress
    --debug           : show even more information (for debugging purposes)
EOF
  print STDERR "$help\n";
  exit(1);
}

# Get the command-line arguments and check for the mandatory ones
sub opt_check {
  my %opt = ();
  GetOptions(\%opt,
    "host=s",
    "port=i",
    "user=s",
    "password=s",
    "db=s",
    "species=s",
    "antispecies=s",
    "list_species",
    "add_size",
    "search",
    "help",
    "verbose",
    "debug",
  );

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  $opt{password} ||= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

