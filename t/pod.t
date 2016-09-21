#!perl -T
use Test::More skip_all => "Dev test";

use Test::More;
eval "use Test::Pod 1.14";
plan skip_all => "Test::Pod 1.14 required for testing POD" if $@;
my @pods = all_pod_files('lib');
all_pod_files_ok(@pods);
