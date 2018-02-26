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

Readonly my $run_info_template => 'http://www.ebi.ac.uk/ena/data/warehouse/search?query="tax_eq(%d) AND library_source="TRANSCRIPTOMIC""&result=read_run&display=xml';
Readonly my $run_info_date_template => 'http://www.ebi.ac.uk/ena/data/warehouse/search?query="tax_eq(%d) AND first_public>=%s AND library_source="TRANSCRIPTOMIC""&result=read_run&display=xml';
Readonly my $fastq_size_template => 'http://www.ebi.ac.uk/ena/data/warehouse/filereport?accession=%s&result=read_run&fields=fastq_bytes,submitted_bytes,tax_id';

Readonly my @fields => qw(
  species
  creation
  update
  status
  accession
  PMID
  exps
  runs
  samps
  center
  comment
  title
  abstract
);

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
my %db_study = map { ($_->study_sra_acc || $_->study_private_acc) => $_->date } @db_studies;

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
    $species_search{'-not'} = [ map { { "strains.production_name" => $_ } } @anti ];
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
  $species_search{'strain.production_name'} = $opt->{species} if $opt->{species};
  if ($opt->{antispecies}) {
    my @anti = split ',', $opt->{antispecies};
    $species_search{'-not'} = [ map { { "strain.production_name" => $_ } } @anti ];
  }
  my @studies = $db->resultset('Study')->search(\%species_search, 
    {
      prefetch => { 'experiments' => { 'runs' => { 'sample' => 'strain' } } }
    }
  );
}

sub search {
  my ($list, $db_study, $opt) = @_;

  my %completed_studies;
  for my $species (@$list) {
    search_taxon($species, $db_study, \%completed_studies, $opt);
  }

  # Find studies from DB that were not found
  if (not $opt->{pub_date}) {
      my %not_found;
      for my $study (keys %$db_study) {
          $not_found{$study}++ if not exists $completed_studies{$study};
      }

      for my $missing_study (keys %not_found) {
          say STDERR "MISSING STUDY: $missing_study";
      }
  }
}

sub search_taxon {
  my ($species, $db_study, $completed, $opt) = @_;
  
  say STDERR "Searching for RNAseq studies for " . $species->binomial_name . "... ";
  
  my @strains = $species->strains;
  my @studies = get_studies_for_taxon($species->taxon_id, $opt);
  
  say STDERR (@studies+0) . " studies found";
  
  # Only print the studies that are not in the DB
  map { print_study($_, $species, format_date($db_study{$_->accession})) } grep { $db_study{$_->accession} } @studies;
  map { print_study($_, $species, 'NEW ') } grep { not $db_study{$_->accession} } @studies;
  
  # Mark those studies as completed
  for my $study (@studies) {
    $completed->{ $study->accession }++;
  }
}

sub format_date {
  my ($date) = @_;
  $date =~ s/^(\d{4}-\d{2}-\d{2}).+$/$1/;
  return $date;
}

sub print_study {
  my ($st, $species, $category) = @_;
  
  my $experiments = $st->experiments;
  my $runs        = $st->runs;
  my $samples     = $st->samples;
  my $abstract    = $st->abstract // '';
  $abstract =~ s/ *\R+/ /g;  # Change newlines to spaces
  my $pubmed_id = get_pubmed_id($st) // '';
  
  my %line_data = (
    species       => $species->binomial_name,
    status        => $category,
    accession     => $st->accession,
    exps          => scalar(@$experiments),
    runs          => scalar(@$runs),
    samps         => scalar(@$samples),
    PMID          => $pubmed_id,
    center        => $st->center_name,
    title         => $st->title,
    abstract      => $abstract,
    creation      => $st->{first_public},
    update        => $st->{last_update},
  );
  my @line = map { $line_data{$_} // "" } @fields;
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
  
  my $url;
  if ($opt->{pub_date}) {
      $url = sprintf($run_info_date_template, $taxon_id, $opt->{pub_date});
  } else {
      $url = sprintf($run_info_template, $taxon_id);
  }
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
    my $study_id;
    XREF : foreach my $xref ($xrefs->get_nodelist) {
      my $DB = $xref->findnodes('./DB')->shift()->textContent;
      if ($DB eq 'ENA-STUDY') {
        $study_id = $xref->findnodes('./ID')->shift()->textContent;
        
        # Save the count for the study
        $study{$study_id}{run_count}++;
        
        if (++$count % 10 == 0) {
          sleep 1;
        }
      }
    }
    
    my $attributes = $run->findnodes('.//RUN_ATTRIBUTE');
    ATTR : foreach my $attr ($attributes->get_nodelist) {
      my $tag = $attr->findnodes('.//TAG')->shift()->textContent;
      if ($tag eq 'ENA-LAST-UPDATE') {
        my $value = $attr->findnodes('.//VALUE')->shift()->textContent;
        $study{$study_id}{last_update} = $value;
      } elsif ($tag eq 'ENA-FIRST-PUBLIC') {
        my $value = $attr->findnodes('.//VALUE')->shift()->textContent;
        $study{$study_id}{first_public} = $value;
      }
    }
  }
  
  my @studies;
  for my $study_id (keys %study) {
    my $study = get_study($study_id);
    
    # Proportion of runs with data in the study
    #$study{$study_id}{fastq_complete} = "$study{$study_id}{complete}/$study{$study_id}{run_count}";
    
    my $run_study = $study{$study_id};
    %$study = (%$study, %$run_study);
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
    --search          : search for new RNA-Seq studies
    
    Options:
    --species <str>     : production_name to only search for one species
    --antispecies <str> : production_name of species to exclude
    --pub_date          : Date of first publication of the runs (to find recent ones)
    
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
    "pub_date=s",
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
  usage("Need an action") if not( $opt{list_species} xor $opt{search});
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

