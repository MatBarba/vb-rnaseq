use utf8;
package RNAseqDB::Common;

use strict;
use warnings;
use Carp;
use English qw( -no_match_vars );
use Moose;
use MooseX::FollowPBP;
use Readonly;

has sra_regex => (
  is  => 'ro',
  isa => 'HashRef',
  default => sub{ {
    study      => qr{[SED]RP\d+},
    experiment => qr{[SED]RX\d+},
    run        => qr{[SED]RR\d+},
    sample     => qr{[SED]RS\d+},
    vb_study      => qr{VBSRP\d+},
    vb_experiment => qr{VBSRX\d+},
    vb_run        => qr{VBSRR\d+},
    vb_sample     => qr{VBSRS\d+},
  } }
);

 __PACKAGE__->meta->make_immutable;
1;

