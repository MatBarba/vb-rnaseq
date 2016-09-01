use Test::More tests => 1;
use FindBin;
use lib $FindBin::Bin . '/../../lib';

BEGIN {
use_ok( 'Bio::EnsEMBL::RNAseqDB', "Testing Bio::EnsEMBL::RNAseqDB");
}

