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
my $DONT_DROP = 0;

# Preparation: add necessary species
$db->add_species({
    production_name => 'species_xxx',
    binomial_name   => 'Species xxx',
    taxon_id        => 29031,
    strain          => 'A',
});

# Check tables are empty
check_tables_numbers($db, [0, 0, 0, 0]);

# Define a mock private rnaseq data
my $rnaseq_study_json_path = dirname($0) . '/private1.json';
my $rnaseq_study = {
  info => {
    title           => 'Species xxx RNAseq study',
    abstract        => 'Species xxx RNAseq study abstract text',
  },
  production_name => 'species_xxx',
  pubmed_id       => 21276245,

  experiments =>
  [
    {
      info => {
        title         => 'Species xxx RNAseq experiment',
      },

      runs => 
      [
        {
          info  => {
            title         => 'Species xxx RNAseq run',
            submitter     => 'Species xxx submitter',
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
        title         => 'Species xxx RNAseq sample 1',
        description   => 'Species xxx RNAseq sample 1 description text',
      },
    },
  ],
};

# Try to add 1 study that has no SRA accession
{
  my $num = $db->add_private_study($rnaseq_study);
  ok( $num == 1, "Insert 1 SRA run from a private study (no SRA) - $num" );
  check_tables_numbers($db, [1,1,1,1,1,1]);
}

# Same, but from a json file
{
  my $num = $db->add_private_study_from_json($rnaseq_study_json_path);
  ok( $num == 1, "Insert 1 SRA run from a private study from a json file (no SRA) - $num" );
  # NB: share the same pubmed as the previous one, so only add a link
  check_tables_numbers($db, [2,2,2,2,1,2]);
}

sub check_number_in_table {
  my ($db, $table, $expected_number) = @_;
  return if not defined $expected_number;
  $table = ucfirst $table;
  
  my $req = $db->resultset( $table );
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
  check_number_in_table($db, 'Publication', $nums->[4]);
  check_number_in_table($db, 'StudyPublication', $nums->[5]);
}

# Delete temp database
END {
  drop_mock_db($db) if not $DONT_DROP;
  done_testing();
}

__END__
