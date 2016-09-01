#!/usr/bin/env perl
use strict;
use warnings;
use autodie qw( :all );
use Test::More;
use Test::Exception;
use Data::Dumper;
use Log::Log4perl qw( :easy );
#Log::Log4perl->easy_init($DEBUG);
my $logger = get_logger();

use FindBin;
use lib $FindBin::Bin;
use lib $FindBin::Bin . '/../../lib';

BEGIN : {
    use RNAseqDB::Publications;
}

# Try to retrieve data from pubmed (REST)
my $pubmed_id = 21276245;
$logger->debug("Publication: $pubmed_id");
my $data = RNAseqDB::Publications::_get_pubmed_data( $pubmed_id );

ok( keys(%$data) > 0, 'Got some data' );

done_testing();

