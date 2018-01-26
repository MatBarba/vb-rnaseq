package Bio::EnsEMBL::RNAseqDB::File;
use strict;
use warnings;
use Carp;
use Moose::Role;

use Digest::MD5::File qw(file_md5_hex);
use Data::Dumper;
use Readonly;

use Log::Log4perl qw( :easy );
my $logger = get_logger();


sub check_files {
  my $self = shift;
  my ($dir, $update_md5) = @_;
  
  # Retrieve the list of all the files from the DB
  my @big   = $self->get_all_files('bigwig');
  my @bam   = $self->get_all_files('bam');
  my @bai   = map {
      my $bai = {
        path => $_->{path} . '.bai',
        production_name => $_->{production_name}
      }; $bai
    } @bam;
  my @fastq = $self->_get_private_files;
  
  $logger->info(@big . " bigwig files");
  $logger->info(@bam . " bam files");
  $logger->info(@bai . " bai files");
  $logger->info(@fastq . " private fastq files");
  
  # Check each file
  $self->_check_files_in_dir(\@big,   "$dir/bigwig", $update_md5);
  $self->_check_files_in_dir(\@bam,   "$dir/bam",    $update_md5);
  $self->_check_files_in_dir(\@bai,   "$dir/bam",    $update_md5);
  $self->_check_files_in_dir(\@fastq, "$dir/fastq",  $update_md5, 'private');
  
  return 1;
}

sub get_all_files {
  my $self = shift;
  my ($type) = @_;
  
  my %search;
  $search{type} = $type if $type;
  
  my $files_req = $self->resultset('File')->search(\%search,
    {
      prefetch  => { track_analysis => 'assembly' },
    },
  );
  
  my @files;
  foreach my $file ($files_req->all) {
    my $assembly = $file->track_analysis->assembly;
    my $file_obj = {
      path            => $file->path,
      production_name => $assembly->production_name,
      file_id         => $file->file_id,
      md5             => $file->md5,
      human_name      => $file->human_name,
    };
    push @files, $file_obj;
  }
  return @files;
}

sub _get_private_files {
  my $self = shift;
  my ($type) = @_;
  
  my $files_req = $self->resultset('PrivateFile')->search({},
    {
      prefetch  => { run => { sample => 'strain' } },
  });
  
  my @files;
  foreach my $file ($files_req->all) {
    my $file_obj = {
      path            => $file->path,
      production_name => $file->run->sample->strain->production_name,
      file_id         => $file->private_file_id,
    };
    push @files, $file_obj;
  }
  return @files;
}

sub _check_files_in_dir {
  my $self = shift;
  my ($files, $dir, $update_md5, $private) = @_;
  
  my $table    = $private ? 'PrivateFile' : 'File';
  my $table_id = $private ? 'private_file_id' : 'file_id';
  
  for my $file (@$files) {
    my $path = sprintf "%s/%s/%s", $dir, $file->{production_name}, $file->{path};
    if (not -s $path) {
      $logger->warn("Can't find file '$file->{path}' in '$dir' ($path)");
    } elsif ($update_md5) {
      if (defined $file->{file_id}) {
        # Get md5sum for this file
        my $digest = file_md5_hex($path);

        # Update DB
        $logger->debug("MD5SUM\t$path = $digest");
        $self->resultset($table)->search({
            $table_id => $file->{file_id},
          })->update({
            md5 => $digest,
          });
      } else {
        $logger->debug("No file_id for $path");
      }
    } else {
      if (defined($file->{md5})) {
        # Get md5sum for this file
        my $digest = file_md5_hex($path);
        
        # Compare it
        if ($digest ne $file->{md5}) {
          $logger->warn("Warning: file $file->{path} has wrong md5sum: $digest (expected: $file->{md5})");
        }
      } else {
        $logger->warn("Warning: file $file->{path} has no md5sum in the database.");
      }
    }
  }
}

## PRIVATE METHOD
## Purpose   : insert a list of files for a track
## Parameters:
# 1) track_id
# 2) array ref of files paths
sub add_files {
  my $self = shift;
  my ($track_an, $paths) = @_;
  my $track_an_id = $track_an->track_analysis_id;
  
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
  my $nadded;
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
        path       => $file,
        human_name => $self->make_human_readable_name($track_an, $file),
        type       => $type,
        md5        => $file_md5,
      });
    $nadded++;
  }
  
  return $nadded;
}

sub make_human_readable_name {
  my $self = shift;
  my ($track_an, $filename) = @_;
  
  my $name = '';
  
  my $track    = $track_an->track;
  #my $strain   = $track->sra_tracks->first->run->sample->strain;
  my $assembly = $track_an->assembly;
  my $title    = $track->title_manual // $track->title_auto;
  if ($title) {
    $title =~ s/ /_/g;
  } else {
    $logger->warn("No title defined for $filename");
  }
  
  my $file_extension = '';
  if ($filename =~ /\.(bam|bam\.bai|bw|cram)$/) {
    $file_extension = '.' . $1;
  } else {
    carp "No extension for file $filename";
    return '';
  }
  
  my $merge_text = $track->merge_text;
  $merge_text =~ s/^([^_]+)_.+_([^_]+)$/$1-$2/;
  
  my @name_list = ($merge_text);
  push @name_list, $title if $title;
  push @name_list, $assembly->assembly;
  $name = join('_', @name_list) . $file_extension;
  
  return $name;
}

sub update_file_names {
  my $self = shift;
  
  my @tracks = $self->get_tracks();

  my $nupdates;
  for my $track (@tracks) {
    my @track_analyses = $track->track_analyses;
    for my $track_an (@track_analyses) {
      for my $file ($track_an->files) {
        my $name = $self->make_human_readable_name($track_an, $file->path);
        $file->update({ human_name => $name});
        $nupdates++;
      }
    }
  }
  $logger->info("$nupdates file names updated");
}


1;

__END__


=head1 DESCRIPTION

Bio::EnsEMBL::RNAseqDB::File - File role for the RNAseq DB

This module is a role to search the file and private_file tables.

=head1 INTERFACE

=over
 
=item check_files()

  function       : Check that the files from the DB are in their designated directory
  arg[1]         : string = path to the directory
  
  Usage:
  
    $db->check_files($dir);

=item get_all_files

  function       : retrieve all available files
  returns        : Array of File resultsets
  arguments      : (optional) type of the files to retrieve (string = bam...)
  
  Usage:
  
    my @files = $db->get_all_files('bam');

=item add_files

  function       : add and link files for a given track
  arguments      :
    1) track_analysis_id
    2) array ref of file names

=item make_human_readable_name

  function       : create a human readable name for a given file
  arguments      :
    1) track_analysis_id
    2) a file name
  returns        : a string
  
  This subroutine is mostly used internally and the result stored in the file table.

=item update_file_names

  function       : update the human_name field of the files
  arguments      : None
    
=back

=cut

