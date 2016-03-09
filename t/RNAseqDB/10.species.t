#!/usr/bin/env perl
use strict;
use warnings;
use autodie qw( :all );
use Test::More;
use Test::Exception;
use JSON;
use Perl6::Slurp;
use Data::Dumper;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

BEGIN : {
    use RNAseqDB::DB;
}

# Load database schema
my $schema_path = 'sql/tables.sql';
die "Can't access schema\n" if not -e $schema_path;

# Get database parameters
my $dbconf_path = 't/db_conf.json';
die "Can't access DB conf file" if not -e $dbconf_path;
my $dbconf_json = slurp $dbconf_path;
my %dbconf = %{ decode_json( $dbconf_json ) };
die "Missing host for DB\n" unless $dbconf{host};
die "Missing user for DB\n" unless $dbconf{user};
die "Missing dbname for DB\n" unless $dbconf{dbname};

# Add some random number at the end to avoid a collision with an existing database
my $rand_num = int(rand(9999999));
$dbconf{dbname} .= '_' . $rand_num;

# Create temp database
my $mysql_command = "mysql --host=$dbconf{host} --port=$dbconf{port} --user=$dbconf{user} --password=$dbconf{pass}";
system "$mysql_command -e ". '"CREATE DATABASE ' . $dbconf{dbname} . ';"';
# Load the schema
system "$mysql_command $dbconf{dbname} < $schema_path";

# Actual tests
my $db_connected = (my $db = RNAseqDB::DB->connect(
  "dbi:mysql:host=$dbconf{host}:port=$dbconf{port}:database=$dbconf{dbname}",
  $dbconf{user},
  $dbconf{pass},
  { RaiseError => 1 },
));
ok defined $db_connected, "Connection to DB";

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
  if (defined $dbconf{dbname}
        and ref($db) eq 'RNAseqDB::DB'
        and $db_connected) {
      $logger->info("Dropping temp database $dbconf{dbname}");
      system "mysql --host=$dbconf{host} --port=$dbconf{port} --user=$dbconf{user} --password=$dbconf{pass} -e ". '"DROP DATABASE ' . $dbconf{dbname} . ';"';
    }
    else {
      $logger->warn("Failed to drop database $dbconf{dbname}: was it actually created");
    }
    done_testing();
  }

