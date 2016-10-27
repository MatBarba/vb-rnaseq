#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
$Carp::Verbose = 1;
use autodie qw( :all );
use Test::More;
use Test::Exception;
use Test::Warnings;
use Data::Dumper;

use Log::Log4perl qw( :easy );
#Log::Log4perl->easy_init($DEBUG);
my $logger = get_logger();

use FindBin;
use lib $FindBin::Bin;
use lib $FindBin::Bin . '/../../lib';
use MockRNAseqDB qw( create_mock_db drop_mock_db );

# Get a mock DB (RNAseqBD::DB), create with the proper schema
my $db = create_mock_db();
my $DONT_DROP = 0;

my $can = can_ok($db, 'add_files');
SKIP : {
  skip "Can't add_files", 2 if not $can;
# Add species and sra
  ok($db->add_species(
      production_name => 'anopheles_gambiae',
      binomial_name   => 'Anopheles gambiae',
      taxon_id        => 7165,
      strain          => 'type',
      assembly        => 'AgamP4',
    ), 'Can add test species');
  my $test_sra = 'SRP014756';
  ok($db->add_sra($test_sra), "Can add test track $test_sra");

  # Get track_id
  my @tracks = $db->get_tracks('sra_ids' => [$test_sra]);
  my $track = shift @tracks;
  my $track_an = $track->track_analyses->first;

  # Add file
  my @paths = qw(filename.bw);
  ok(my $nadded = $db->add_files($track_an, \@paths), 'Added files');

  my @files = $db->get_all_files();
  ok(@files == 1, 'There is one file in the DB');
  my $file = shift @files;
  ok(ref($file) eq 'HASH', 'Returned files as hashes');
  is($file->{path}, $paths[0], 'File has path');
  is($file->{production_name}, 'anopheles_gambiae', 'File has production_name');
  ok(defined $file->{file_id}, 'File has file_id');
  is($file->{human_name}, 'SRP014756_General_Sample_for_Anopheles_gambiae_AgamP4.bw', 'File has correct human_name');
}

# Delete temp database
END {
  drop_mock_db($db) if not $DONT_DROP;
  done_testing();
}

__END__

