#!/usr/bin/env perl
use Test::More;
use FindBin;
use lib $FindBin::Bin . '/../../lib';

BEGIN : {
    use Bio::EnsEMBL::RNAseqDB;
}

ok defined(my $rdb = Bio::EnsEMBL::RNAseqDB->connect()), "Constructor";
isa_ok($rdb, "Bio::EnsEMBL::RNAseqDB", "Bio::EnsEMBL::RNAseqDB constructor");

my @methods = qw(
  connect
  add_sra
  add_private_study
  add_private_study_from_json
  add_species
);
can_ok($rdb, @methods);

done_testing();

