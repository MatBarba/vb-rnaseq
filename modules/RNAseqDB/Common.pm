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

__END__


=head1 NAME

RNAseqDB::Common - Basic data for the RNAseqDB


=head1 SYNOPSIS

    my $reg = $db->get_sra_regex();
    if ('SRP000001' =~ /$reg->{study}/) {
      print "OK";
    }

=head1 DESCRIPTION

This role provides some common general functions or data.

