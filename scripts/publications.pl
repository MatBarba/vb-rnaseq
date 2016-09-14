#!/usr/bin/env perl

use 5.10.0;
use strict;
use warnings;
use Readonly;
use Carp;
use autodie qw(:all);
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use JSON;
use Perl6::Slurp;
use List::Util qw( first );
use File::Spec qw(cat_file);
use File::Path qw(make_path);
use File::Copy;
use Data::Dumper;

use aliased 'Bio::EnsEMBL::RNAseqDB';

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

###############################################################################
# MAIN
# Get command line args
my %opt = %{ opt_check() };

# Connect to the database schema
my $db = RNAseqDB->connect(
  "dbi:mysql:host=$opt{host}:port=$opt{port}:database=$opt{db}",
  $opt{user},
  $opt{password}
);

# Add publications
if ($opt{pubmed_id}) {
  if ($opt{publication_id}) {
    $db->add_study_publication($opt{publication_id}, $opt{pubmed_id});
  } elsif ($opt{sra_id}) {
    $db->add_study_publication_from_sra($opt{sra_id}, $opt{pubmed_id});
  }
}
elsif ($opt{file}) {
  my @mapping = get_mapping($opt{file});
  foreach my $map (@mapping) {
    $db->add_study_publication_from_sra($map->{sra_id}, $map->{pubmed_id});
  }
}

# Retrieve publications
if ($opt{list}) {
  my @publications = $db->get_publications();
  
  for my $pub (@publications) {
    my $pub_id = $pub->publication_id;
    my @studies = $pub->study_publications->all;
    my @study_ids  = map { $_->study_id } @studies;
    say "Publication: $pub_id";
    say "\tStudies: " . join(', ', @study_ids);
  }
}

###############################################################################
# SUB

sub get_mapping {
  my ($path) = @_;
  
  open my $FILE, '<', $path;
  my @map;
  while (my $line = readline $FILE) {
    next if $line =~ /(^#|^\s*$)/;
    chomp $line;
    my ($sra_id, $pubmed_id) = split /\s+/, $line;
    push @map, { sra_id => $sra_id, pubmed_id => $pubmed_id };
  }
  close $FILE;
  
  return @map;
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
    This script allows to review and add publications to studies.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Filter:
    --species <str>   : filter outputs tracks for a given species (production_name)
    
    Actions
    --list            : List every publications for all studies
    
    Add a publication to a study:
    --pubmed_id       : pubmed accession (integer)
    --sra_id          : an SRA accession from the study (study, experiment, run)
    OR
    --file <path>     : file with to columns: 1 sra accession, 1 pubmed_id
    
    Other:
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
    "list",
    "pubmed_id=s",
    "sra_id=s",
    "file=s",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need one action") if not ($opt{list} xor ($opt{pubmed_id} and $opt{sra_id}) xor $opt{file});
  $opt{password} //= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

