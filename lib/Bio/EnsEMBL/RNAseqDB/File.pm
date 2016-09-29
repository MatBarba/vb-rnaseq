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
  my $big   = $self->_get_all_files('bigwig');
  my $bam   = $self->_get_all_files('bam');
  my @bai   = map {
      my $bai = {
        path => $_->{path} . '.bai',
        production_name => $_->{production_name}
      }; $bai
    } @$bam;
  my $fastq = $self->_get_private_files;
  
  $logger->info(@$big . " bigwig files");
  $logger->info(@$bam . " bam files");
  $logger->info(@bai . " bai files");
  $logger->info(@$fastq . " private fastq files");
  
  # Check each file
  $self->_check_files_in_dir($big,   "$dir/bigwig", $update_md5);
  $self->_check_files_in_dir($bam,   "$dir/bam",    $update_md5);
  $self->_check_files_in_dir(\@bai,  "$dir/bam",    $update_md5);
  $self->_check_files_in_dir($fastq, "$dir/fastq",  $update_md5, 'private');
  
  return 1;
}

sub _get_all_files {
  my $self = shift;
  my ($type) = @_;
  
  my $files_req = $self->resultset('File')->search({
      type => $type,
    },
    {
      prefetch  => { track_analyses => { track => { sra_tracks => { run => { sample => { strain => 'species' } } } } } },
  });
  
  my @files;
  foreach my $file ($files_req->all) {
    my @sra_tracks = $file->track->sra_tracks;
    my $file_obj = {
      path            => $file->path,
      production_name => $sra_tracks[0]->run->sample->strain->production_name,
      file_id         => $file->file_id,
      md5             => $file->md5,
    };
    push @files, $file_obj;
  }
  return \@files;
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
  return \@files;
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
    
=back

=cut

