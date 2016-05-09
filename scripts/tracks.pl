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
  print $OUT encode_json($data) . "\n";
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
  foreach my $species (sort keys %$data) {
    my $species_line = "-species $species";
    
    #  all tracks
    my $tracks = $data->{$species};
    my %merged_runs;
    foreach my $track_id (keys %$tracks) {
      my $track = $tracks->{$track_id};
      my $run_accs = $track->{run_accs};
      my $merge_level = $track->{merge_level};
      
      if (@$run_accs) {
        # Push in merge_levels if any
        if (defined $merge_level) {
          push @{ $merged_runs{$merge_level} }, @$run_accs;
        } else {
          # Create a command line for this track
          push @command_lines, create_track_command($pipeline_command, $species_line, $run_accs, 'taxon');
        }
      } else {
        $logger->warn("No tracks to align for $species");
      }
    }
    
    # Group by merge_level
    foreach my $merge_level (keys %merged_runs) {
      push @command_lines, create_track_command($pipeline_command, $species_line, $merged_runs{$merge_level}, $merge_level);
    }
  }
  
  return \@command_lines;
}

sub create_track_command {
  my ($pipeline_command, $species_line, $run_accs, $merge_level) = @_;
  
  my @line;
  push @line, (
    '$' . $pipeline_command,
    $species_line,
    "-merge_level $merge_level",
  );
  push @line, map { "-run_id $_" } @$run_accs;
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
#  push @main_line, "-json_summary $opt{pipeline_dir}/summary.json";
  #####################################################################################################
  push @main_line, '-aligner star';
  push @main_line, '-bigwig 1';
  #push @main_line, '-hive_force_init 1';
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

