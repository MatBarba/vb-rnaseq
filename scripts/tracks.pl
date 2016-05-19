#!/usr/bin/env perl

use 5.10.0;
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
#Log::Log4perl->easy_init($DEBUG);
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

my $data = $db->get_new_runs_tracks( $opt{species} );
if (keys %$data == 0) {
  die "No track to extract";
}

open my $OUT, '>', $opt{output};
if ($opt{format} eq 'json') {
  my $json = JSON->new->allow_nonref;
  print $OUT $json->pretty->encode($data) . "\n";
}
elsif ($opt{format} eq 'pipeline') {
  my $command_lines = tracks_for_pipeline($data, \%opt);
  print $OUT join("\n", @$command_lines) if @$command_lines;
}
else {
  warn "Unsupported format: $opt{format}\n";
}


###############################################################################
# SUBS

sub tracks_for_pipeline {
  my ($data, $opt) =  @_;
  
  my @command_lines;
  
  # The start of the command line is the same for every track
  my $commandline_start = create_command_line_start($opt);
  my $pipeline_command = 'RNASEQ_PIPELINE';
  push @command_lines, "$pipeline_command=\"$commandline_start\"";
  
  # Create the command line for each new track
  my @tracks_lines;
  foreach my $species (sort keys %$data) {
    $logger->info("Export new tracks for $species");
    my $species_line = "-species $species";
    
    #  all tracks
    my $tracks = $data->{$species};
    my %merged_runs;
    foreach my $track_id (keys %$tracks) {
      my $track = $tracks->{$track_id};
      my $run_accs = $track->{run_accs};
      my $fastqs = $track->{fastqs};
      my $merge_level = $track->{merge_level};
      my $merge_id = $track->{merge_id};
      
      if ($run_accs) {
        # Push in merge_levels if any
        if (defined $merge_level and $merge_level ne 'taxon') {
          push @{ $merged_runs{$merge_level} }, @$run_accs;
        } else {
          # Create a command line for this track
          push @tracks_lines, create_track_command(
              species_line     => $species_line,
              run_accs         => $run_accs,
              merge_level      => 'taxon',
              merge_id         => $merge_id,
            );
        }
      }
      elsif ($fastqs) {
        if (defined $opt{fastq_dir}) {
          push @tracks_lines, create_track_command_private(
              species_line     => $species_line,
              fastqs           => $fastqs,
              fastq_dir        => "$opt{fastq_dir}/$species",
              merge_id         => $merge_id,
            );
        } else {
          warn "Can't write private data commands without the path to the fastq dir";
        }
      }
      else {
        $logger->warn("No tracks to align for $species");
      }
    }
    
    # Group by merge_level
    foreach my $merge_level (keys %merged_runs) {
          push @tracks_lines, create_track_command(
              species_line     => $species_line,
              run_accs         => $merged_runs{$merge_level},
              merge_level      => $merge_level,
            );
    }
  }
  push @command_lines, "commands=()";
  push @command_lines, map { 'commands+=("' . $_ . '")' } @tracks_lines;
  
  return \@command_lines;
}

sub create_track_command {
  my %arg = @_;
  
  my @line;
  push @line, (
    $arg{species_line},
    "-merge_level $arg{merge_level}",
  );
  push @line, "-merge_id $arg{merge_id}" if defined $arg{merge_id};
  push @line, map { "-run $_" } @{$arg{run_accs}};
  my $command = join ' ', @line;
  return $command;
}

sub create_track_command_private {
  my %arg = @_;
  $arg{merge_level} //= 'taxon';
  
  my @line;
  push @line, (
    $arg{species_line},
    "-merge_level $arg{merge_level}",
  );
  push @line, "-merge_id $arg{merge_id}" if defined $arg{merge_id};
  
  # Fastq: is it a pair? -> seq_file_pair
  my @files = @{$arg{fastqs}};
  if (@files == 2) {
    push @line, "-seq_file_pair " . join(',', map { "$arg{fastq_dir}/$_" } @{$arg{fastqs}});
  }
  # Not a pair: simply seq_file
  else {
    push @line, map { "-seq_file $arg{fastq_dir}/$_" } @{$arg{fastqs}};
  }
  my $command = join ' ', @line;
  return $command;
}

sub create_command_line_start {
  my ($opt) = @_;
  my @main_line = ();
  push @main_line, 'init_pipeline.pl';
  push @main_line, 'Bio::EnsEMBL::EGPipeline::PipeConfig::ShortReadAlignment_conf';
  push @main_line, '$(mysql-hive-ensrw details script)';
  #####################################################################################################
  push @main_line, "-registry $opt->{registry}";
  push @main_line, "-pipeline_dir $opt{pipeline_dir}";
  push @main_line, "-results_dir $opt{results_dir}";
  #####################################################################################################
  push @main_line, '-aligner bowtie2';
  push @main_line, '-bigwig 1';
  push @main_line, '-hive_force_init 1';
  return join(" ", @main_line);
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
    --results_dir <path>  : Path to a directory where the pipeline will store its results
    
    Output:
    --output <path>   : path to the output file
    --format <str>    : output format: json (default), pipeline.
    --fastq_dir <str> : path to the fastq dir (with one directory per production_name).
    
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
    "results_dir=s",
    "species=s",
    "output=s",
    "format=s",
    "fastq_dir=s",
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
  $opt{format} ||= 'json';
  $opt{password} ||= '';
  if ($opt{format} eq 'pipeline') {
    usage("Need --registry") if not $opt{registry};
    usage("Need --pipeline_dir") if not $opt{pipeline_dir};
    usage("Need --results_dir") if not $opt{results_dir};
  }
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

