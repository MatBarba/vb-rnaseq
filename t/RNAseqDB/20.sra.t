#!/usr/bin/env perl
use strict;
use warnings;
use autodie qw( :all );
use Test::More;
use Test::Exception;
use Log::Log4perl qw( :easy );
#Log::Log4perl->easy_init($DEBUG);
my $logger = get_logger();

use File::Basename;
use lib dirname($0);
use MockRNAseqDB qw( create_mock_db drop_mock_db );

# Get a mock DB (RNAseqBD::DB), create with the proper schema
my $db = create_mock_db();

# Preparation: add necessary species
$db->add_species({
    production_name => 'culex_quinquefasciatus',
    binomial_name   => 'Culex quinquefasciatus',
    taxon_id        => 7176,
  });

# Check tables are empty
check_tables_numbers($db, [0, 0, 0, 0]);

# Try to add 1 run from a species that is not defined in the taxonomy
{
  my $acc = 'SRR1271738';
  my $num = $db->add_sra($acc);
  ok( $num == 0, "Don't insert 1 SRA $acc (species not allowed)" );
check_tables_numbers($db, [0, 0, 0, 0]);
}

# Add 1 run
{
  my $acc = 'SRR1271734';
  my $num = $db->add_sra($acc);
  ok( $num == 1, "Insert 1 SRA $acc" );
  check_number_in_table($db, 'study', 1);
  check_number_in_table($db, 'experiment', 1);
  check_number_in_table($db, 'run', 1);
  check_number_in_table($db, 'sample', 1);
}

# Add 1 experiment (same study)
{
  my $acc = 'SRX533493';
  my $num = $db->add_sra($acc);
  ok( $num == 1, "Insert 1 SRA $acc" );
  check_number_in_table($db, 'study', 1);
  check_number_in_table($db, 'experiment', 2);
  check_number_in_table($db, 'run', 2);
  check_number_in_table($db, 'sample', 2);
}

# Add 1 sample (same study)
{
  my $acc = 'SRS602296';
  my $num = $db->add_sra($acc);
  ok( $num == 1, "Insert 1 SRA $acc" );
  check_number_in_table($db, 'study', 1);
  check_number_in_table($db, 'experiment', 3);
  check_number_in_table($db, 'run', 3);
  check_number_in_table($db, 'sample', 3);
}

# Add 1 study (same, whole study, there should 2 runs left to add, so 5 in total)
{
  my $acc = 'SRP041691';
  my $num = $db->add_sra($acc);
  ok( $num == 2, "Insert 1 SRA $acc ($num runs inserted)" );
  check_number_in_table($db, 'study', 1);
  check_number_in_table($db, 'experiment', 5);
  check_number_in_table($db, 'run', 5);
  check_number_in_table($db, 'sample', 5);
}

sub check_number_in_table {
  my ($db, $table, $expected_number) = @_;
  $table = ucfirst $table;
  
  my $req = $db->resultset( $table )->search({
        status  => 'ACTIVE',
  });
  my @lines = $req->all;
  ok( scalar @lines == $expected_number, sprintf("Right number of lines in %s (%d / %d)", $table, scalar @lines, $expected_number) );
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
# Add some species (no strain)
{
  my %species1 = (
    production_name => 'anopheles_stephensi',
    binomial_name   => 'Anopheles stephensi',
    taxon_id        => 30069,
  );
  my %species2 = (
    production_name => 'anopheles_stephensiI',
    binomial_name   => 'Anopheles stephensi',
    taxon_id        => 30069,
    strain          => 'Indian',
  );
  
  ok( insert_species(\%species1), 'Insert 1 species (no strain)' );
  ok( insert_species(\%species2), 'Insert 1 species (strain)' );
  dies_ok{ insert_species(\%species1); } 'Fail to insert a duplicate (1)';
  dies_ok{ insert_species(\%species2); } 'Fail to insert a duplicate (2)';
}
  
sub insert_species {
  my ($species) = shift;
  
  my %species_clone = %$species;
  $db->add_species( \%species_clone ) or die('Species not inserted');
  ok( my $species_req = $db->resultset('Taxonomy')->search({
        status  => 'ACTIVE',
        production_name => $species->{production_name}
      }), 'Request empty species list');
  $species_req->result_class('DBIx::Class::ResultClass::HashRefInflator');
  my @lines = $species_req->all;
  ok( scalar @lines == 1, 'Species list has 1 species' );
  
  # Check all fields
  my $sp = $lines[0];
  for my $key (keys %$species) {
    ok( (defined $sp->{ $key }
        and $sp->{ $key } eq $species->{ $key }),
      "Inserted species has the same value for $key ($sp->{ $key } eq $species->{ $key })");
  }
  return 1;
}


