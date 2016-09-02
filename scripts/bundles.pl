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

use aliased 'Bio::EnsEMBL::TrackHub::Hub';
use aliased 'Bio::EnsEMBL::TrackHub::Hub::Genome';
use aliased 'Bio::EnsEMBL::TrackHub::Hub::Track';

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

# Retrieve track bundles
my $bundles;
if (not defined $opt{format}) {
  $bundles = $db->get_bundles({
      species     => $opt{species},
      files_dir   => $opt{files_dir},
    });
  
} elsif ($opt{format} eq 'solr') {
  $bundles = $db->get_bundles_for_solr({
      species     => $opt{species},
      files_dir   => $opt{files_dir},
      hubs_url    => $opt{hubs_url}
    });
  
} elsif ($opt{format} eq 'webapollo') {
  print STDERR "Format not yet implemented\n";
  exit;
}

# Check result and print
if (@$bundles == 0) {
  print STDERR "No bundle to extract\n";
} else {
  print_json($opt{output}, $bundles);
}

###############################################################################
# SUB
sub print_json {
  my ($output, $data) = @_;
  
  open my $OUT, '>', $output;
  my $json = JSON->new;
  $json->allow_nonref;  # Keep undef values as null
  $json->canonical;     # order keys
  $json->pretty;        # Beautify
  print $OUT $json->encode($data) . "\n";
  close $OUT;
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
    This script exports bundles of tracks in various json formats.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Filter:
    --species <str>   : filter outputs tracks for a given species (production_name)
    
    Json output:
    --files_dir <path>: root dir to use for the files paths
    --output <path>   : path to the output file in json
    --format <str>    : possible json formats (solr, webapollo)
                        If empty, defaults to a standard json with whole bundle data
    --hubs_url <path> : root url for the hubs files (needed for solr activation links)
    
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
    "registry=s",
    "species=s",
    "files_dir=s",
    "hubs_url=s",
    "output=s",
    "format=s",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --output") if not $opt{output};
  usage ("--hubs_url needed for solr output") if $opt{format} and $opt{format} eq 'solr' and not $opt{hubs_url};
  $opt{password} //= '';
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

