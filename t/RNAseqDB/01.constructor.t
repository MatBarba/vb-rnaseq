#!/usr/bin/env perl
use Test::More;
use FindBin;
use lib $FindBin::Bin . '/../../lib';

BEGIN : {
    use RNAseqDB::DB;
}

ok defined(my $rdb = RNAseqDB::DB->connect()), "Constructor";
isa_ok($rdb, "RNAseqDB::DB", "RNAseqDB::DB constructor");

my @methods = qw(
  connect
  add_sra
  add_private_study
  add_private_study_from_json
  add_species
);
can_ok($rdb, @methods);

done_testing();

