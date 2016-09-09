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
use File::Path qw(make_path);
use File::Copy;
use Data::Dumper;

use Bio::EnsEMBL::RNAseqDB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

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

my $data = $db->get_new_runs_tracks( $opt{species} );
if (keys %$data == 0) {
  die "No track to extract";
}

if ($opt{run_pipeline}) {
  run_pipeline($db, $data, \%opt);
}

if (defined $opt{output}) {
  open my $OUT, '>', $opt{output};
  if ($opt{format} eq 'json') {
    my $json = JSON->new->allow_nonref;
    print $OUT $json->pretty->encode($data) . "\n";
  }
  elsif ($opt{format} eq 'pipeline') {
    my $command_lines = tracks_for_pipeline($data, \%opt);
    print $OUT join("\n", @$command_lines) if @$command_lines;
  }
  elsif ($opt{run_pipeline}) {
    say "TODO: run pipeline";
  }
  else {
    warn "Unsupported format: $opt{format}\n";
  }
}


###############################################################################
# SUBS

sub run_pipeline {
  my ($db, $data, $opt) =  @_;
  
  # First, create the common init_pipeline command part
  my $start_cmd = create_start_cmd($opt);

  # Don't reinit hivedb on the first run, but do it on the following runs
  my $reinit_hivedb = '';
  
  # Align the tracks of every species in order
  SPECIES: foreach my $species (sort keys %$data) {
    my $tracks = $data->{$species};
    my @track_ids = keys %$tracks;
    $logger->info("$species has " . @track_ids . " tracks to align");
    
    # Create the species specific command part
    my $species_cmd = "-species $species";
    
    # Get the list of commands to run the pipeline
    my $track_cmds = create_track_cmds($species, $tracks, $opt);
    
    $logger->info(@$track_cmds . " pipeline sessions to run for $species");
    
    # Run the pipeline!
    SESSION: foreach my $track_cmd (@$track_cmds) {
      
      # Complete the init_pipeline command for this track
      my $pipeline_cmd = join ' ', ($start_cmd, $species_cmd, $track_cmd, $reinit_hivedb);
      $logger->info($pipeline_cmd);
      
      # Set the hivedb to be reinitialized on the following runs
      $reinit_hivedb = '-hive_force_init';
      
      # Execute
      my $pipe_log = 'rnaseqdb_pipeline_init.log';
      my $init_msg = `$pipeline_cmd 2> $pipe_log`;
      my $pipe_log_msg = slurp $pipe_log;
      
      # Prepare to get the beekeeper commands
      my $beekeeper_cmd;
      my $toredo = 0;
      
      # Check that the initialization happened correctly
      if ($init_msg =~ /\[Useful commands\]/) {
        $logger->debug("Init complete");

        # Capture the beekeeper commands
        my @init_lines = split /[\r\n]+/, $init_msg;
        $beekeeper_cmd = first { /-run/ } grep { /beekeeper.pl / } @init_lines;
        $beekeeper_cmd =~ s/-run\s*//;
        $beekeeper_cmd =~ s/#.*$//;
      }
      # Not complete because there is already a hive DB!
      elsif ($pipe_log_msg =~ /Can't create database '(\w+)'; database exists/) {
        my $dbname = $1;
        
        # Extract the beekeeper command
        if ($pipe_log_msg =~ /-url (mysql:\/\/\w+:\w+@[\w\-\.]+:\d+\/\w+) -sql 'CREATE DATABASE'/) {
          $logger->info("A Hive DB already exists ($dbname): We will first finish it before continuing");
          my $hive_url = $1;
          
          # Create the beekeeper commands
          $beekeeper_cmd = "beekeeper.pl -url $hive_url -reg_conf $opt{registry}";
          $logger->info($pipe_log_msg);
          
          # Flag to rerun the current track when the previously unfinished one is completed
          $toredo = 1;
        } else {
          $logger->error($pipe_log_msg);
          $logger->error($init_msg);
          die "A Hive DB already exists ($dbname), but I can't find its url. Aborting.";
        }
      }
      else {
        $logger->error("PIPELINE STDERR: {\n$pipe_log_msg}");
        $logger->error("PIPELINE STDOUT: {\n$init_msg}");
        die "Pipeline initialization failed";
      }
      
      # First sync
      `$beekeeper_cmd -sync &> $pipe_log`;
      
      # Keep hive logs
      $beekeeper_cmd .= " -hive_log_dir $opt->{pipeline_dir}/hive";
      
      # RUN!
      `$beekeeper_cmd -run &> $pipe_log`;
      $logger->info("$beekeeper_cmd -run");
      my $status = 'running';
      my $prev_status_line = '';
      
      while ($status eq 'running') {
        # Get status
        my %status;
        my $status_line = '';
        my $run_msg = slurp $pipe_log;
        if ($run_msg =~ /(total over .+ total\))/) {
          # Get status line
          $status_line = $1;
          if ($status_line =~ /total over (?<analyses>\d+) analyses :\s+(?<completeness>[0-9\.]+)% complete \(<\s+(?<cpu_hrs>[0-9\.]+)\s+CPU_hrs\) \((?<to_do>\d+) to_do \+ (?<done>\d+) done \+ (?<failed>\d+) failed = (?<total>\d+) total\)/) {
            %status = %+;
          }
          
          # Try to get the current running modules
          my @lines = split /[\r\n]+/, $run_msg;
          my (@working, @ready);
          for my $line (@lines) {
            if ($line =~ /^(?<module>\w+)\s*\(.+, jobs\([^\)]+(?<num_jobs>\d+)i[^\)]+\)/) {
              push @working, "$+{module} ($+{num_jobs})";
            }
            if ($line =~ /^(?<module>\w+)\s*\(.+, jobs\([^\)]+(?<num_jobs>\d+)r[^\)]+\)/) {
              push @ready, "$+{module} ($+{num_jobs})";
            }
          }
          $status_line .= '    ' . join(', ', (@working ? @working : @ready));
        } else {
          $logger->error("FAILED!\nLast pipeline output: {\n$run_msg}");
          die "Pipeline failed without finishing. Can't find the status line?";
        }
        
        if ($status{failed}) {
          $logger->error("FAILED!\nLast pipeline output: {\n$run_msg}");
          die "Pipeline failed without finishing. Failed jobs found.";
        }
        elsif ($status{completeness} == 100) {
          print STDERR "\n";
          $logger->info("Pipeline finished");
          
          $status = 'done';
        }
        else {
          sleep 60;
          `$beekeeper_cmd -run &> $pipe_log`;
          
          # Print the status, but only if the status changed
          if ($status_line ne $prev_status_line) {
            $logger->info("$status_line");
            $prev_status_line = $status_line;
          }
        }
      }
      # Copy the newly created files
      copy_files($species, $opt);
      
      # Redo or continue
      if ($toredo) {
        $logger->info("We just finished an aborted pipeline. We need to restart the command line generation to take this finished job into account.");
        redo SPECIES;
      } else {
        next SESSION;
      }
    }
    # Copy any uncopied files (e.g. if the pipeline had to be finished by hand)
    copy_files($species, $opt);
  }
}

sub copy_files {
  my ($species, $opt) = @_;
  
  my $res_dir  = "$opt->{results_dir}/$opt->{aligner}/$species";
  return if not -e $res_dir;
  my $ini_dir  = "$opt->{final_dir}/ini/$species";
  my $big_dir  = "$opt->{final_dir}/bigwig/$species";
  my $bam_dir  = "$opt->{final_dir}/bam/$species";
  my $json_dir = "$opt->{final_dir}/cmds/$species";
  
  make_path $ini_dir  if not -d $ini_dir;
  make_path $big_dir  if not -d $big_dir;
  make_path $bam_dir  if not -d $bam_dir;
  make_path $json_dir if not -d $json_dir;
  
  # Prepare the list of files to copy
  opendir(my $res_dh, $res_dir);
  
  my @res_files = readdir $res_dh;
  closedir $res_dh;
  my @ini_files  = grep { /\.ini$/        } @res_files;
  my @big_files  = grep { /\.bw$/         } @res_files;
  my @bam_files  = grep { /\.bam$/        } @res_files;
  my @json_files = grep { /\.cmds\.json$/ } @res_files;
  
  # Copy bigwig, bam file and index, and json cmds (As long as the files do not already exist!)
  $logger->info("Copy files from $species in the final dir $opt->{final_dir}... ");
  map { copy "$res_dir/$_",        "$ini_dir/$_"        if not -s "$ini_dir/$_"        } @ini_files;
  map { copy "$res_dir/$_",        "$big_dir/$_"        if not -s "$big_dir/$_"        } @big_files;
  map { copy "$res_dir/$_",        "$bam_dir/$_"        if not -s "$bam_dir/$_"        } @bam_files;
  map { copy "$res_dir/$_".'.bai', "$bam_dir/$_".'.bai' if not -s "$bam_dir/$_".'.bai' } @bam_files;
  map { copy "$res_dir/$_",        "$json_dir/$_"       if not -s "$json_dir/$_"       } @json_files;
  
  # Make sure that the files are read-only
  chmod 0444, glob "$big_dir/*.bw";
  chmod 0444, glob "$bam_dir/*.bam";
  chmod 0444, glob "$bam_dir/*.bai";
  chmod 0444, glob "$json_dir/*.cmds.json";
  chmod 0444, glob "$ini_dir/*.ini";
  
  $logger->info("done");
  
  return;
}

sub add_tracks_results {
  my ($db, $results_href) = @_;
  
  $logger->info("Importing " . (keys %$results_href) . " tracks");
  
  for my $merge_id (sort keys %$results_href) {
    $logger->info("Importing data for $merge_id");
    my $track_data = $results_href->{$merge_id};
    $logger->debug("Data:" . Dumper($track_data));
    
    # First, get the track_id
    my ($track) = $db->get_tracks(merge_ids => [$merge_id]);
    my $track_id = $track->track_id;
    
    if ($track_id) {
      # Then, add the data
      my @files = (
        $track_data->{bw_file},
        $track_data->{bam_file},
      );
      $db->add_track_results($track_id, $track_data->{cmds}, \@files);
    }
  }
}

sub tracks_for_pipeline {
  my ($data, $opt) =  @_;
  
  my @command_lines;
  
  # The start of the command line is the same for every track
  my $commandline_start = create_start_cmd($opt);
  my $pipeline_command = 'RNASEQ_PIPELINE';
  push @command_lines, "$pipeline_command=\"$commandline_start\"";
  
  # Create the command line for each new track
  my @tracks_cmds;
  foreach my $species (sort keys %$data) {
    
    $logger->info("Export new tracks for $species");
    my $species_line = "-species $species";
    
    my @tracks_lines;
    
    #  all tracks
    my $tracks = $data->{$species};
    my %merged_runs;
    TRACK: foreach my $track_id (keys %$tracks) {
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
              run_accs         => $run_accs,
              merge_level      => 'taxon',
              merge_id         => $merge_id,
            );
        }
      }
      elsif ($fastqs) {
        if (defined $opt{fastq_dir}) {
          push @tracks_lines, create_track_command_private(
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
              run_accs         => $merged_runs{$merge_level},
              merge_level      => $merge_level,
            );
    }
    
    push @tracks_cmds, map { "$species_line $_" } @tracks_lines;
  }
  push @command_lines, map { '$' . "$pipeline_command $_" } @tracks_cmds;
  
  return \@command_lines;
}

sub is_already_aligned {
  my ($species, $merge_id, $opt) = @_;
  
  my $dir = "$opt->{final_dir}/cmds/$species";
  my $path = "$dir/$merge_id*.json";
  my @files = glob($path);
  
  return @files;
}

sub is_already_finished {
  my ($species, $merge_id, $opt) = @_;
  
  my $dir = "$opt->{results_dir}/$opt->{aligner}/$species";
  my $path = "$dir/$merge_id*.json";
  my @files = glob($path);
  
  return @files;
}

sub create_track_cmds {
  my ($species, $tracks, $opt) = @_;

  my @track_cmds;
  
  # Group tracks with the same merge_level (but not taxon)
  my %merged_runs;
  
  TRACK: foreach my $track_id (keys %$tracks) {
    my $track       = $tracks->{$track_id};
    my $run_accs    = $track->{run_accs};
    my $fastqs      = $track->{fastqs};
    my $merge_level = $track->{merge_level};
    my $merge_id    = $track->{merge_id};
    
    # Check if the track has already been created (json file exists)
    if (is_already_aligned($species, $merge_id, $opt)) {
      $logger->warn("Track $merge_id from $species is already aligned and copied");
      next TRACK;
    }
    elsif (is_already_finished($species, $merge_id, $opt)) {
      $logger->warn("Track $merge_id from $species is already aligned, but the files were not copied");
      next TRACK;
    } else {
      $logger->info("Track $merge_id from $species will be aligned");
    }

    # Normal track with SRA accessions
    if ($run_accs) {
      
      # If the merge_level is not taxon (study or sample), group the tracks
      if (defined $merge_level and $merge_level ne 'taxon') {
        push @{ $merged_runs{$merge_level} }, @$run_accs;
      
        # Otherwise, create this one track individually
      } else {
        $merge_level = 'taxon';
        push @track_cmds, create_track_command(
          merge_level      => $merge_level,
          merge_id         => $merge_id,
          run_accs         => $run_accs,
        );
      }
    }
    
    # Track not defined with SRA accession = private data with fastq files
    elsif ($fastqs) {
      if (defined $opt{fastq_dir}) {
        push @track_cmds, create_track_command_private(
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

  # Create commands for tracks grouped by merge_level
  foreach my $merge_level (keys %merged_runs) {
    push @track_cmds, create_track_command(
      run_accs         => $merged_runs{$merge_level},
      merge_level      => $merge_level,
    );
  }
  return \@track_cmds;
}

sub create_track_command {
  my %arg = @_;
  
  my @line;
  push @line, (
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

sub create_start_cmd {
  my ($opt) = @_;
  my @main_line = ();
  push @main_line, 'init_pipeline.pl';
  push @main_line, 'Bio::EnsEMBL::EGPipeline::PipeConfig::ShortReadAlignment_conf';
  push @main_line, '$(mysql-hive-ensrw details script)';
  #####################################################################################################
  push @main_line, "-registry $opt->{registry}";
  push @main_line, "-pipeline_dir $opt->{pipeline_dir}";
  push @main_line, "-results_dir $opt->{results_dir}";
  #####################################################################################################
  push @main_line, "-aligner $opt->{aligner}";
  push @main_line, '-run_mode local' if $opt->{aligner} eq 'bowtie2';
  push @main_line, '-bigwig 1';
  push @main_line, '-threads 8';
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
    
    Tracks filter:
    --species <str>   : only outputs tracks for a given species (production_name)
    
    The script can either output the list of tracks to create in json format or a list of commands,
    or run the pipelines themselves.
    
    FILES OUTPUT
    --format <str>    : output format: json (default), pipeline.
    --output <path>   : path to the output file
    
    Pipeline config (both for the list of commands and running):
    --registry <path>     : Path a registry file for the pipeline
    --pipeline_dir <path> : Path to a directory where the pipeline will store its work files
    --results_dir <path>  : Path to a directory where the pipeline will store its results
    --fastq_dir <path>    : path to the fastq dir (with one directory per production_name).
    --aligner <str>       : aligner to use ([bowtie2], star, bwa).
    
    RUN PIPELINE
    --run_pipeline        : run the pipeline for all new tracks with the config defined above
    --final_dir <path>    : path to the directory where the final files will be moved
    
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
    "pipeline_dir=s",
    "results_dir=s",
    "fastq_dir=s",
    "final_dir=s",
    "aligner=s",
    "species=s",
    "output=s",
    "format=s",
    "run_pipeline",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  $opt{aligner} //= 'bowtie2';
  $opt{password} //= '';
  if (defined $opt{format}) {
    usage("Need --output") if not $opt{output};
  }
  if (($opt{format} and $opt{format} eq 'pipeline') or $opt{run_pipeline}) {
    usage("Need --registry") if not $opt{registry};
    usage("Need --pipeline_dir") if not $opt{pipeline_dir};
    usage("Need --results_dir") if not $opt{results_dir};
  }
  if ($opt{run_pipeline}) {
      usage("Need --final_dir") if not $opt{final_dir};
  }
  usage("Need --format or --run_pipeline") if not $opt{format} and not $opt{run_pipeline};
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

