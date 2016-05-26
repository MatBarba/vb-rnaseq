use utf8;
package RNAseqDB::File;
use Moose::Role;

use strict;
use warnings;
#use List::Util qw( first );
#use JSON;
#use Perl6::Slurp;
use Log::Log4perl qw( :easy );

my $logger = get_logger();
use Data::Dumper;
use Readonly;
#use Try::Tiny;

sub check_files {
  my $self = shift;
  my ($dir) = @_;
  
  # Retrieve the list of all the files from the DB
  my $big   = $self->_get_all_files('bigwig');
  my $bam   = $self->_get_all_files('bam');
  my @bai   = map { $_->{path} = $_->{path} . '.bai'; $_ } @$bam;
  my $fastq = $self->_get_private_files;
  
  $logger->info(@$big . " bigwig files");
  $logger->info(@$bam . " bam files");
  $logger->info(@bai . " bai files");
  $logger->info(@$fastq . " private fastq files");
  
  # Check each file
  $self->_check_files_in_dir($big, "$dir/bigwig");
  $self->_check_files_in_dir($bam, "$dir/bam");
  $self->_check_files_in_dir(\@bai, "$dir/bam");
  $self->_check_files_in_dir($fastq, "$dir/fastq");
}

sub _get_all_files {
  my $self = shift;
  my ($type) = @_;
  
  my $files_req = $self->resultset('File')->search({
      type => $type,
    },
    {
      prefetch  => { track => { sra_tracks => { run => { sample => { strain => 'species' } } } } },
  });
  
  my @files;
  foreach my $file ($files_req->all) {
    my @sra_tracks = $file->track->sra_tracks;
    my $file_obj = {
      path            => $file->path,
      production_name => $sra_tracks[0]->run->sample->strain->production_name,
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
    };
    push @files, $file_obj;
  }
  return \@files;
}

sub _check_files_in_dir {
  my $self = shift;
  my ($files, $dir) = @_;
  
  for my $file (@$files) {
    my $path = sprintf "%s/%s/%s", $dir, $file->{production_name}, $file->{path};
    if (not -s $path and not -s "$path.gz") {
      $logger->warn("Can't find file '$file->{path}' in '$dir' ($path)");
    }
  }
}

1;

__END__


=head1 NAME

RNAseqDB::File - File role for the RNAseq DB


=head1 SYNOPSIS

    # Check current files
    $db->check_files($dir);

=head1 DESCRIPTION

This module is a role to search the file and private_file tables.

=head1 INTERFACE

=over
 
=item check_files()

  function       : Check that the files from the DB are in their designated directory
  arg[1]         : string = path to the directory
  
  Usage:
  
    $db->check_files($dir);
    
=back


=head1 CONFIGURATION AND ENVIRONMENT

This module requires no configuration files or environment variables.


=head1 DEPENDENCIES

 * Log::Log4perl
 * DBIx::Class
 * Moose::Role


=head1 BUGS AND LIMITATIONS

...

=head1 AUTHOR

Matthieu Barba  C<< <mbarba@ebi.ac.uk> >>

