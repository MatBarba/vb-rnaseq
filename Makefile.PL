use 5.10.0;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'RNAseqDB',
    VERSION_FROM => 'lib/RNAseqDB.pm',
    PREREQ_PM    => {
        'Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor' => 0,
        'Bio::EnsEMBL::TrackHub' => '1',
        'Digest::MD5'            => '0',
        'Digest::MD5::File'      => '0',
        'DBIx::Class'            => '0',
        'HTTP::Request::Common'  => '0',
        'JSON'                   => '0',
        'List::MoreUtils'        => '0',
        'Log::Log4perl'          => '0',
        'LWP::Simple'            => '0',
        'Moose'                  => '0',
        'Moose::Role'            => '0',
        'MooseX::FollowPBP'      => '0',
        'namespace::autoclean'   => '0',
        'Perl6::Slurp'           => '0',
        'Readonly'               => '0',
        'Test::Exception'        => '0',
        'Test::File'             => '0',
        'Test::Pod::Coverage'    => '0',
        'Test::Warnings'         => '0',
        'Try::Tiny'              => '0',
    },
    test => {TESTS => 't/*.t t/*/*.t'},
    #ABSTRACT_FROM => 'lib/RNAseqDB.pm',
    AUTHOR        => 'mbarba <mbarba@ebi.ac.uk>',
    LICENSE       => 'apache',
);
