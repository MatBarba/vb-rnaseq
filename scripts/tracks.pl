#!/usr/bin/env perl

use strict;
use warnings;
use Readonly;
use Carp;
use autodie;
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use JSON;
use Data::Dumper;

use RNAseqDB::DB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

###############################################################################
# MAIN
# Get command line args
my %opt = %{ opt_check() };

# Connect to the database schema
my $db = RNAseqDB::DB->connect(
  "dbi:mysql:host=$opt{host}:port=$opt{port}:database=$opt{db}",
  $opt{user},
  $opt{password}
);

my $data = $db->get_new_sra_tracks( $opt{species} );
open my $OUT, '>', $opt{output};
if ($opt{format} eq 'json') {
  print $OUT encode_json($data) . "\n";
}
elsif ($opt{format} eq 'pipeline') {
  my $command_line = tracks_for_pipeline($data, \%opt);
  print $OUT $command_line if defined $command_line;
}
else {
  warn "Unsupported format: $opt{format}\n";
}

sub tracks_for_pipeline {
  my ($data, $opt) =  @_;
  
  my  @params = ();
  
  # Common values of the command-line
  
  my @main_line = ();
  push @main_line, 'init_pipeline.pl';
  push @main_line, 'Bio::EnsEMBL::EGPipeline::PipeConfig::ShortReadAlignment_conf';
  push @main_line, '$(mysql-hive-ensrw details script)';
  #####################################################################################################
  push @main_line, "-registry $opt->{registry}";
  push @main_line, "-pipeline_dir $opt{pipeline_dir}";
#  push @main_line, "-json_summary $opt{pipeline_dir}/summary.json";
  #####################################################################################################
  push @main_line, '-aligner star';
  push @main_line, '-bigwig 1';
  push @params, join(" \\\n\t", @main_line);
  
  my $n = 0;
  foreach my $species (sort keys %$data) {
    my @species_line = ();
    
    # Species production_name
    push @species_line, "-species $species";
    
    # Species taxon_id
    my $taxon_id = $data->{$species}->{taxon_id};
    push @species_line, "-taxids $species=$taxon_id";
    
    # Species sras
    my @uniq_sras;
    my $tracks_sra = $data->{$species}->{tracks};
    foreach my $track_id (keys %$tracks_sra) {
      my $sra_ids = $tracks_sra->{ $track_id };
      if (scalar @$sra_ids == 1) {
        push @uniq_sras, @$sra_ids;
        $n += scalar @$sra_ids;
      } else {
        $logger->warn("Merged tracks not yet implemented (for track $track_id)");
      }
    }
    
    # Add all the tracks with a unique sample id in one go
    if (scalar @uniq_sras) {
      push @params, join(' ', @species_line);
      push @params, "\t-sra_species $species=" . join(",", @uniq_sras);
    } else {
        $logger->warn("No tracks to align for $species");
    }
  }
  
  if ($n > 0) {
    return join " \\\n", @params;
  } else {
    $logger->warn("WARNING: no new tracks found");
    return;
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
    This script export the list of tracks to create from an RNAseq DB in a JSON format.

    Database connection:
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    Pipeline config:
    --registry <path>     : Path a registry file for the pipeline
    --pipeline_dir <path> : Path to a directory where the pipeline will store its work files
    
    Output:
    --output <path>   : path to the output file
    --format <str>    : output format: json (default), pipeline.
    
    Other:
    --species <str>   : only outputs tracks for a given species (production_name)
    
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
    "pipeline_dir=s",
    "species=s",
    "output=s",
    "format=s",
    "help",
    "verbose",
    "debug",
  );

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --output") if not $opt{output};
  $opt{format} ||= 'json';
  $opt{password} ||= '';
  if ($opt{format} eq 'pipeline') {
    usage("Need --registry") if not $opt{registry};
    usage("Need --pipeline_dir") if not $opt{pipeline_dir};
  }
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

