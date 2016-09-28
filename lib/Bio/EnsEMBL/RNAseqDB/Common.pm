package Bio::EnsEMBL::RNAseqDB::Common;
use 5.10.00;
use strict;
use warnings;
use Carp;
use Moose;
use MooseX::FollowPBP;

has project_prefix => (
  is      => 'rw',
  isa     => 'Str',
  default => 'VB',
);

# Regex list to identify
has sra_regex => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_sra_regex',
);

sub _build_sra_regex {
  my $self = shift;

  my $prefix = $self->get_project_prefix();
  my %regex = (
    study         => qr{[SED]RP\d+},
    experiment    => qr{[SED]RX\d+},
    run           => qr{[SED]RR\d+},
    sample        => qr{[SED]RS\d+},
    vb_study      => qr/${prefix}SRP\d+/,
    vb_experiment => qr/${prefix}SRX\d+/,
    vb_run        => qr/${prefix}SRR\d+/,
    vb_sample     => qr/${prefix}SRS\d+/,
  );
return \%regex;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 DESCRIPTION

This package provides some common general functions or data.

=head1 USAGE
    my $reg = $db->get_sra_regex();
    if ('SRP000001' =~ /$reg->{study}/) {
      print "OK";
    }

=cut

