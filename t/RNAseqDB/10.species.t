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

# Delete temp database
END {
  drop_mock_db($db);
  done_testing();
}

