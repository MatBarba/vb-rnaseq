#!perl
use Test::More skip_all => "Slow, do it later";

if (!require Test::Perl::Critic) {
    Test::More::plan(
        skip_all => "Test::Perl::Critic required for testing PBP compliance"
    );
}

#use Test::Perl::Critic ( -severity => 4 );
Test::Perl::Critic::all_critic_ok('modules');
