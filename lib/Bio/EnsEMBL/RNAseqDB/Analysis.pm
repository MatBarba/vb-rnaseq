package Bio::EnsEMBL::RNAseqDB::Analysis;
use 5.10.00;
use strict;
use warnings;
use Carp;
use Moose::Role;

use List::MoreUtils qw(uniq);
use File::Spec;
use Digest::MD5::File qw(file_md5_hex);
use Digest::MD5 qw(md5_hex);
use Try::Tiny;
use Memoize;
use Readonly;
use Data::Dumper;

use Log::Log4perl qw( :easy );
my $logger = get_logger();

###############################################################################
## ANALYSIS METHODS
#
## INSTANCE METHOD
## Purpose   : add commands and files for a track
## Parameters:
# 1) track_id
# 2) array ref of command strings
# 3) array ref of alignment files created
# 4) version of the aligner used
sub add_track_results {
  my $self = shift;
  my ($track_an_id, $commands, $files, $version) = @_;
  
  $logger->debug("Add data for track analysis $track_an_id");
  
  # Add commands
  my $cmds_ok = $self->_add_commands($track_an_id, $commands, $version);
  return if not $cmds_ok;
  
  # Add files
  my $files_ok = $self->_add_files($track_an_id, $files);
  return if not $files_ok;
  
  return 1;
}

## PRIVATE METHOD
## Purpose   : insert a list of alignment commands for a track
## Parameters:
# 1) track_id
# 2) array ref of commands
# 3) Aligner version
sub _add_commands {
  my $self = shift;
  my ($track_an_id, $commands, $version) = @_;
  
  # First, check that there is no command for this track already
  my $cmd_req = $self->resultset('Analysis')->search({
      track_analysis_id => $track_an_id,
    });
  my @cmds = $cmd_req->all;
  
  # Some commands: skip
  if (@cmds) {
    $logger->warn("WARNING: the track $track_an_id already has commands. Skip addition.");
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
        track_analysis_id       => $track_an_id,
        command                 => $command,
        analysis_description_id => $an_id,
        version                 => $an_version
      });
  }
  
  return 1;
}

## PRIVATE METHOD
## Purpose   : find the name of the aligner program used
## Parameters: a command-line string
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

## PRIVATE METHOD
## Purpose   : load the programs descriptions from the DB
## Parameters: none
sub _load_analysis_descriptions {
  my $self = shift;
  
  my $req = $self->resultset('AnalysisDescription');
  my @descriptions = $req->all;
  
  return @descriptions;
}

## PRIVATE METHOD
## Purpose   : insert a list of files for a track
## Parameters:
# 1) track_id
# 2) array ref of files paths
sub _add_files {
  my $self = shift;
  my ($track_an_id, $paths) = @_;
  
  # First, check that there is no files for this track already
  # (Except for fastq files)
  my $file_req = $self->resultset('File')->search({
      track_analysis_id => $track_an_id,
    });
  my @files = $file_req->all;
  
  # Some files: skip
  if (@files) {
    $logger->warn("WARNING: the track $track_an_id already has files. Skip addition.");
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
        track_analysis_id => $track_an_id,
        path     => $file,
        type     => $type,
        md5      => $file_md5,
      });
  }
  
  return 1;
}

1;

__END__

=head1 DESCRIPTION

Bio::EnsEMBL::RNAseqDB::Analysis - Analysis role for the RNAseq DB.

Only one important method to add the commands and the files created from the
alignment of the track.

=head1 INTERFACE

=over

=item add_track_results

  function       : add and link commands and files for a given track
  arguments      :
    1) track_id
    2) array ref of command strings
    3) array ref of alignment files created
    4) version of the aligner used
  

=back

=cut

