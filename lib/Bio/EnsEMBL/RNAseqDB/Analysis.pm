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
## Purpose   : insert a list of alignment commands for a track
## Parameters:
# 1) track_id
# 2) array ref of commands
# 3) Aligner version
sub add_commands {
  my $self = shift;
  my ($track_an, $commands, $version) = @_;
  my $track_an_id = $track_an->track_analysis_id;
  
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

1;

__END__

=head1 DESCRIPTION

Bio::EnsEMBL::RNAseqDB::Analysis - Analysis role for the RNAseq DB.

Only one important method to add the commands created from the alignment of
a track.

=head1 INTERFACE

=over

=item add_commands

  function       : add and link commands for a given track
  arguments      :
    1) track_id
    2) array ref of command strings
    4) version of the aligner used
  

=back

=cut

