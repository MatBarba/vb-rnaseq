#!/usr/bin/env perl
package MockRNAseqDB;
use Exporter 'import';
our @EXPORT_OK = qw( create_mock_db drop_mock_db );

use strict;
use warnings;
use autodie qw( :all );
use Test::More;
use Test::Exception;
use JSON;
use Perl6::Slurp;
use Data::Dumper;

use RNAseqDB::DB;
use Log::Log4perl qw( :easy );
my $logger = get_logger();
use File::Basename;
use lib dirname($0);

our $db_connected;
our %dbconf;

sub create_mock_db {
  # Load database schema
  my $schema_path = dirname($0).'/../../sql/tables.sql';
  my $dbconf_path = dirname($0).'/db_conf.json';

  die "Can't access schema\n" if not -e $schema_path;
  die "Can't find configuration file: make sure to copy the template db_conf.json.example to db_conf.json and change the parameters\n" if not -e $dbconf_path;

  # Get database parameters
  die "Can't access DB conf file" if not -e $dbconf_path;
  my $dbconf_json = slurp $dbconf_path;
  %dbconf = %{ decode_json( $dbconf_json ) };
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
  $db_connected = (my $db = RNAseqDB::DB->connect(
      "dbi:mysql:host=$dbconf{host}:port=$dbconf{port}:database=$dbconf{dbname}",
      $dbconf{user},
      $dbconf{pass},
      { RaiseError => 1 },
    ));
  ok(defined $db_connected, "Connection to DB");
  return $db;
}

sub drop_mock_db {
  my ($db) = shift;
  
  if (defined $dbconf{dbname}
      and ref($db) eq 'RNAseqDB::DB'
      and $db_connected) {
    $logger->info("Dropping temp database $dbconf{dbname}");
    system "mysql --host=$dbconf{host} --port=$dbconf{port} --user=$dbconf{user} --password=$dbconf{pass} -e ". '"DROP DATABASE ' . $dbconf{dbname} . ';"';
  }
  else {
    $logger->warn("Failed to drop database: was it actually created? ");
  }
}

1;

