#!/usr/bin/env perl
use strict;
use warnings;
use autodie qw( :all );
use Test::More;
use Test::Exception;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

use File::Basename;
use lib dirname($0);
use MockRNAseqDB qw( create_mock_db drop_mock_db );

# Get a mock DB (RNAseqBD::DB), create with the proper schema
my $db = create_mock_db();

# Preparation: add necessary species
$db->add_species({
    production_name => 'phlebotomus_papatasi',
    binomial_name   => 'Phlebotomus papatasi',
    taxon_id        => 29031,
});

# Check tables are empty
check_tables_numbers($db, [0, 0, 0, 0]);

# Define a mock private rnaseq data
my $rnaseq_study_json_path = dirname($0) . '/private1.json';
my $rnaseq_study = {
  info => {
    title           => 'Phlebotomus papatasi RNAseq study',
    abstract        => 'Phlebotomus papatasi RNAseq study abstract text',
  },
  production_name => 'phlebotomus_papatasi',

  experiments =>
  [
    {
      info => {
        title         => 'Phlebotomus papatasi RNAseq experiment',
      },

      runs => 
      [
        {
          info  => {
            title         => 'Phlebotomus papatasi RNAseq run',
            submitter     => 'Phlebotomus papatasi submitter',
          },
          files         => ['Ppap1_1.fastq', 'Ppap1_2.fastq'],
          sample_name   => 'sample1',
        },
      ],
    },
  ],

  samples => 
  [
    {
      sample_name   => 'sample1',
      info => {
        title         => 'Phlebotomus papatasi RNAseq sample 1',
        description   => 'Phlebotomus papatasi RNAseq sample 1 description text',
      },
    },
  ],
};

# Try to add 1 study that has no SRA accession
{
  my $num = $db->add_private_study($rnaseq_study);
  ok( $num == 1, "Insert 1 SRA run from a private study (no SRA) - $num" );
  check_tables_numbers($db, [1, 1, 1, 1]);
}

# Same, but from a json file
{
  my $num = $db->add_private_study_from_json($rnaseq_study_json_path);
  ok( $num == 1, "Insert 1 SRA run from a private study from a json file (no SRA) - $num" );
  check_tables_numbers($db, [2, 2, 2, 2]);
}

sub check_number_in_table {
  my ($db, $table, $expected_number) = @_;
  $table = ucfirst $table;
  
  my $req = $db->resultset( $table )->search({
        status  => 'ACTIVE',
  });
  my @lines = $req->all;
  ok( scalar @lines == $expected_number, sprintf("Right number of lines in %s (%d / %d)", $table, scalar @lines, $expected_number ));
}

sub check_tables_numbers {
  my $db = shift;
  my $nums = shift;
  check_number_in_table($db, 'study', $nums->[0]);
  check_number_in_table($db, 'experiment', $nums->[1]);
  check_number_in_table($db, 'run', $nums->[2]);
  check_number_in_table($db, 'sample', $nums->[3]);
}

# Delete temp database
END {
  drop_mock_db($db);
  done_testing();
}

__END__
