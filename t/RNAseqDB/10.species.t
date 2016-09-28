#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
$Carp::Verbose = 1;
use autodie qw( :all );
use Test::More;
use Test::Exception;
use Log::Log4perl qw( :easy );
#Log::Log4perl->easy_init($DEBUG);
my $logger = get_logger();
use Data::Dumper;

use FindBin;
use lib $FindBin::Bin . '/../../lib';
use File::Basename;
use lib dirname($0);
use MockRNAseqDB qw( create_mock_db drop_mock_db );

# Get a mock DB (RNAseqBD::DB), create with the proper schema
my $db = create_mock_db();

# Get list of species
{
  ok( my $species_req = $db->resultset('Taxonomy')->search({
        status  => 'ACTIVE',
      }), 'Request empty species list');
  my @lines = $species_req->all;
  ok( scalar @lines == 0, 'Species list is empty' );
}

# Add some species (no strain)
{
  my %species1 = (
    production_name => 'anopheles_stephensi',
    binomial_name   => 'Anopheles stephensi',
    taxon_id        => 30069,
    strain          => 'type',
    assembly        => 'AstS1',
  );
  my %species2 = (
    production_name => 'anopheles_stephensiI',
    binomial_name   => 'Anopheles stephensi',
    taxon_id        => 30069,
    strain          => 'Indian',
    assembly        => 'AstI1',
    assembly_accession => 'GCA0000001',
  );
  
  ok( insert_species(\%species1), 'Insert 1 species and strain' );
  ok( insert_species(\%species2), 'Insert another strain (same species)' );
  dies_ok{ insert_species(\%species1); } 'Fail to insert a duplicate (1)';
  dies_ok{ insert_species(\%species2); } 'Fail to insert a duplicate (2)';
}

# FAILURE TESTS
{
  dies_ok { $db->add_species() } "Fail to insert no data";
  dies_ok { $db->add_species( production_name => 'anopheles_dirus' ) } "Fail to insert only production_name";
  dies_ok { $db->add_species( production_name => 'anopheles_stephensi' ) } "Fail to insert only existing production_name";
  dies_ok { $db->add_species( production_name => 'anopheles_stephensi' ) } "Fail to insert only existing production_name";
}

{
  # New assembly
  my %as1 = (
    production_name => 'anopheles_stephensi',
    assembly        => 'AstS2',
    assembly_accession => 'GCA0000001',
  );
  my %as2 = (
    production_name => 'anopheles_dirus',
    assembly        => 'AdirI2',
  );
  ok( $db->add_new_assembly(%as1), "Add new assembly to existing strain" );
  dies_ok { $db->add_new_assembly() } "Fail to add new assembly with no parameters";
  dies_ok { $db->add_new_assembly(%as2) } "Fail to add new assembly to non-existing strain";
}

sub insert_species {
  my ($species) = shift;
  
  ok( my %species_clone = %$species, "Can insert a species/strain" );
  $db->add_species( %species_clone );
  ok( my $species_req = $db->resultset('Taxonomy')->search({
        status  => 'ACTIVE',
        production_name => $species->{production_name}
      }), 'Request species list');
  my @lines = $species_req->all;
  ok( @lines == 1, 'Species list has 1 species' );
  
  # Check all fields
  my $sp = $lines[0];
  for my $key (qw(binomial_name production_name)) {
    ok( (defined $sp->$key
        and $sp->$key eq $species->{ $key }),
      sprintf("Inserted species has the same value for $key (%s eq %s)", $sp->$key, $species->{ $key }));
  }
  return 1;
}

# Delete temp database
END {
  #drop_mock_db($db);
  done_testing();
}

__END__

