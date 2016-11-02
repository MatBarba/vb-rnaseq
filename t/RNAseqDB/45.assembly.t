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
my $DONT_DROP = 1;

# Preparation: add necessary species
{
  # Check empty assembly
  my @as = $db->get_assemblies('all' => 1);
  ok(@as == 0, 'No assembly yet in the DB');
  
  # Add a species
  my $species = 'anopheles_gambiae';
  my $old_assembly = 'AgamP4';
  my $new_assembly = 'AgamP9';
  my $ass_acc = 'GCA_000349125.1';
  my $ass_sample = 'KB672286:2500000-3000000';
  ok($db->add_species(
      production_name => $species,
      binomial_name   => 'Anopheles gambiae',
      taxon_id        => 7165,
      strain          => 'type',
      assembly        => $old_assembly,
    ), 'Can add test species');
  
  # Check assembly
  @as = $db->get_assemblies('all' => 1);
  ok(@as == 1, 'One assembly in the DB');
  @as = $db->get_assemblies('species' => $species);
  ok(@as == 1, 'Only one latest assembly in the DB');
  ok($as[0]->assembly eq $old_assembly, 'Correct latest assembly');
  
  # And add some SRA
  my $test_sra = 'SRP014756';
  ok($db->add_sra($test_sra), "Can add test track $test_sra");

  # Get track_id
  my @tracks = $db->get_tracks('species' => $species);
  ok(@tracks == 1, "Got one track (latest assembly)");
  @tracks = $db->get_tracks('assembly' => $old_assembly);
  ok(@tracks == 1, "Got one track in the old assembly");
  @tracks = $db->get_tracks('assembly' => $new_assembly);
  ok(@tracks == 0, "Got no track in the new assembly");
  
  # Try to add a new assembly
  ok($db->add_assembly(
      species  => $species,
      assembly => $new_assembly,
      assembly_accession => $ass_acc,
      sample  => $ass_sample,
    ), 'New assembly added');
  @as = $db->get_assemblies('all' => 1);
  ok(@as == 2, 'Two assemblies in the DB');
  @as = $db->get_assemblies('species' => $species);
  ok(@as == 1, 'Only one latest assembly in the DB');
  ok($as[0]->assembly eq $new_assembly, 'Correct latest assembly');
  
  @tracks = $db->get_tracks('species' => $species);
  ok(@tracks == 1, "Got one track (latest assembly)");
  @tracks = $db->get_tracks('assembly' => $old_assembly);
  ok(@tracks == 1, "Got one track in the old assembly");
  @tracks = $db->get_tracks('assembly' => $new_assembly);
  ok(@tracks == 1, "Got one track in the new assembly");
  @tracks = $db->get_tracks('all_assemblies' => 1);
  ok(@tracks == 1, "Got one track (all assemblies)");
  ok($tracks[0]->track_analyses == 2, "Got two track analyses (all assemblies)");
  
  # Check new run tracks to align
  ok(my $runs = $db->get_new_runs_tracks(), 'Can get new runs to align');
  my ($runs_species) = keys %$runs;
  cmp_ok($runs_species, 'eq', $species, 'We need to align two runs (one for each assembly)');
  my @track_ids = keys %{ $runs->{$species} };
  cmp_ok(@track_ids+0, '==', 1, 'We need to align one run (can only be aligned against the latest)');
}

done_testing();
__END__

