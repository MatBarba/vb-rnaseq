package Bio::EnsEMBL::RNAseqDB::Analysis;
use 5.10.0;
use utf8;
use Moose::Role;

use strict;
use warnings;
use Carp;
use Log::Log4perl qw( :easy );
use List::MoreUtils qw(uniq);
use File::Spec;
use Digest::MD5::File qw(file_md5_hex);
use Digest::MD5 qw(md5_hex);
use Try::Tiny;
use Memoize;

my $logger = get_logger();
use Data::Dumper;
use Readonly;

###############################################################################
## TRACKS PRIVATE METHODS
#
## PRIVATE METHOD
## Purpose   : insert a new track in the database for a given SRA run
## Parameters: a run table run_id

## INSTANCE METHOD
## Purpose   : for all active tracks, compute their merge_ids
## Parameters: force (bool) to force the change even if the merge_id exists
sub add_track_results {
  my $self = shift;
  my ($track_id, $commands, $files, $version) = @_;
  
  $logger->debug("Add data for track $track_id");
  
  # Add commands
  my $cmds_ok = $self->_add_commands($track_id, $commands, $version);
  return if not $cmds_ok;
  
  # Add files
  my $files_ok = $self->_add_files($track_id, $files);
  return if not $files_ok;
  
  return 1;
}

sub _add_commands {
  my $self = shift;
  my ($track_id, $commands, $version) = @_;
  
  # First, check that there is no command for this track already
  my $cmd_req = $self->resultset('Analysis')->search({
      track_id => $track_id,
    });
  my @cmds = $cmd_req->all;
  
  # Some commands: skip
  if (@cmds) {
    $logger->warn("WARNING: the track $track_id already has commands. Skip addition.");
    return;
  }
  
  # Add the commands!
  my @commands = map { split /\s*;\s*/ } @cmds;
  for my $command (@$commands) {
    my $desc = $self->_guess_analysis_program($command);
    my ($an_id, $an_version);
    if (not $desc) {
      carp "No analysis description found for command $command";
    } else {
      $an_id   = $desc->analysis_description_id;
      $an_version = $version if ($desc->type eq 'aligner' and defined $version),
    }
    my $cmd = $self->resultset('Analysis')->create({
        track_id                => $track_id,
        command                 => $command,
        analysis_description_id => $an_id,
        version                 => $an_version
      });
  }
  
  return 1;
}

sub _guess_analysis_program {
  my $self = shift;
  my ($command) = @_;
  
  my @descriptions = $self->_load_analysis_descriptions;
  
  foreach my $desc (@descriptions) {
    my $pattern = $desc->pattern;
    if ($command =~ /$pattern/) {
      return $desc;
    }
  }
  return;
}

#memoize('_load_analysis_descriptions');
sub _load_analysis_descriptions {
  my $self = shift;
  
  my $req = $self->resultset('AnalysisDescription');
  my @descriptions = $req->all;
  
  return @descriptions;
}

sub _add_files {
  my $self = shift;
  my ($track_id, $paths) = @_;
  
  # First, check that there is no files for this track already
  # (Except for fastq files)
  my $file_req = $self->resultset('File')->search({
      track_id => $track_id,
    });
  my @files = $file_req->all;
  
  # Some files: skip
  if (@files) {
    $logger->warn("WARNING: the track $track_id already has files. Skip addition.");
    return;
  }
  
  # Add the files!
  for my $path (@$paths) {
    # Only keep the filename, not the path
    my ($vol, $dir, $file) = File::Spec->splitpath($path);
    
    # Determine the type of the file from its extension
    my $type;
    if ($file =~ /\.bw$/) {
      $type = 'bigwig';
    }
    elsif ($file =~ /\.bam$/) {
      $type = 'bam';
      push @$paths, $path . '.bai';
    }
    elsif ($file =~ /\.bam.bai$/) {
      $type = 'bai';
    }
    
    # Get md5sum file
    my $file_md5;
    #try {
    #  $file_md5 = file_md5_hex($path);
    #}
    #catch {
    #  warn "Can't find file for md5sum: $path";
    #};
    
    my $cmd = $self->resultset('File')->create({
        track_id => $track_id,
        path     => $file,
        type     => $type,
        md5      => $file_md5,
      });
  }
  
  return 1;
}

1;

__END__


=head1 NAME

Bio::EnsEMBL::RNAseqDB::Analysis - Analysis role for the RNAseq DB

=head1 DESCRIPTION

Private subroutines to help populate analysis and files tables. They are used
by the tracks methods.

