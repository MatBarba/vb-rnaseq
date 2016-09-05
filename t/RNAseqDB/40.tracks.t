#!/usr/bin/env perl
use strict;
use warnings;
use autodie qw( :all );
use Test::More;
use Test::Exception;
use Test::Warnings;
use Data::Dumper;

use Log::Log4perl qw( :easy );
#Log::Log4perl->easy_init($WARN);
#Log::Log4perl->easy_init($DEBUG);
my $logger = get_logger();

use FindBin;
use lib $FindBin::Bin;
use lib $FindBin::Bin . '/../../lib';
use MockRNAseqDB qw( create_mock_db drop_mock_db );

# Get a mock DB (RNAseqBD::DB), create with the proper schema
my $db = create_mock_db();
my $DONT_DROP = 0;

# Preparation: add necessary species
$db->add_species({
    production_name => 'culex_quinquefasciatus',
    binomial_name   => 'Culex quinquefasciatus',
    taxon_id        => 7176,
  });
$db->add_species({
    production_name => 'aedes_aegypti',
    taxon_id        => 7159,
});

{
  ok(my $tracks = $db->get_new_runs_tracks(), "Get list of new SRA tracks (none expected)");
  $logger->debug(Dumper $tracks);
  check_expected_track($tracks, [0,0]);
  check_tables_numbers($db, [0,0,0,0,0]);
}
{
  ok((my @track_ids = $db->get_track_ids) == 0, "Get empty list of track_ids");
}

{
  # Add 1 study
  $db->add_sra('SRP041691');
  # Get the list of tracks to create
  ok(my $tracks = $db->get_new_runs_tracks(), "Get list of new SRA tracks (1 species expected)");
  $logger->debug(Dumper $tracks);
  
  # Check sizes
  check_expected_track($tracks, [1, 5]);
  check_tables_numbers($db, [1,5,5,5,5]);
}

{
  ok(my @track_ids = $db->get_track_ids, "Get list of track_ids");
  cmp_ok(@track_ids+0, 'gt', 0, "Several track ids in the list");
  
  my $track_id = shift @track_ids;
  ok(my $track = $db->get_track_from_track_id($track_id), "Get track information");
  isa_ok($track, 'Bio::EnsEMBL::RNAseqDB::Schema::Result::Track', 'Get a track object');
  ok(my $track_id_bis = $track->track_id, "Can get track_id");
}

{
  # Add another study
  $db->add_sra('SRP003874');

  # Get the list of tracks to create
  ok(my $tracks = $db->get_new_runs_tracks(), "Get list of new SRA tracks (2 species expected)");
  $logger->debug(Dumper $tracks);
  
  # Check sizes
  check_expected_track($tracks, [2, 9]);
  check_tables_numbers($db, [2,9,9,9,9]);
}

{ 
  # Merge tracks by samples
  my @to_merge = qw( SRS602294 SRS602295 SRS602296 );
  $db->merge_tracks_by_sra_ids(\@to_merge);
  
  ok(my $tracks = $db->get_new_runs_tracks(), "Get list of new SRA tracks (3 samples merged)");
  check_expected_track($tracks, [2, 7]);
  check_tables_numbers($db, [2,9,9,9,10]);
}

{ 
  # Merge tracks by study
  my @to_merge = qw( SRP003874 );
  $db->merge_tracks_by_sra_ids(\@to_merge);
  
  ok(my $tracks = $db->get_new_runs_tracks(), "Get list of new SRA tracks (1 study = 4 samples merged)");
  check_expected_track($tracks, [2, 4]);
  check_tables_numbers($db, [2,9,9,9,11]);
}
{ 
  # Try to merge a second time
  my @to_merge = qw( SRP003874 );
  $db->merge_tracks_by_sra_ids(\@to_merge);
  
  ok(my $tracks = $db->get_new_runs_tracks(), "Merge a second time (1 study = 4 samples)");
  check_expected_track($tracks, [2, 4]);
  check_tables_numbers($db, [2,9,9,9,11]);
}

sub check_expected_track {
  my ($tracks, $nums) = @_;
  
  # Number of species
  my $num_prods = keys %$tracks;
  cmp_ok( $num_prods, '==', $nums->[0], "Got $nums->[0] species with tracks");
  
  # Number of tracks total
  if (defined $nums->[1]) {
    my $num_tracks = 0;
    for my $sp (keys %$tracks) {
      my $sras_aref = $tracks->{ $sp };
      my @sras = values %$sras_aref;
      $num_tracks += scalar @sras;
    }
    cmp_ok( $num_tracks, '==', $nums->[1], "Got $nums->[1] tracks");
  }
  
}

sub check_number_in_table {
  my ($db, $table, $expected_number) = @_;
  return if not defined $expected_number;
  $table = ucfirst $table;
  
  my $req = $db->resultset( $table );
  my @lines = $req->all;
  cmp_ok( scalar @lines, '==', $expected_number, sprintf("Right number of lines in $table = $expected_number" ) );
}

sub check_tables_numbers {
  my $db = shift;
  my $nums = shift;
  check_number_in_table($db, 'Study', $nums->[0]);
  check_number_in_table($db, 'Experiment', $nums->[1]);
  check_number_in_table($db, 'Run', $nums->[2]);
  check_number_in_table($db, 'Sample', $nums->[3]);
  check_number_in_table($db, 'Track', $nums->[4]);
}

# Delete temp database
END {
  drop_mock_db($db) if not $DONT_DROP;
  done_testing();
}

__END__

