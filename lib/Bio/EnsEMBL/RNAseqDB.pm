package Bio::EnsEMBL::RNAseqDB;

use strict;
use warnings;
use utf8;
our $VERSION = "1.00";

use List::Util qw( first );
use JSON;
use Perl6::Slurp;
use Log::Log4perl qw( :easy );

my $logger = get_logger();
use Data::Dumper;
use Readonly;
use Try::Tiny;

use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);

use Moose;
extends 'Bio::EnsEMBL::RNAseqDB::Schema';
with  'Bio::EnsEMBL::RNAseqDB::Species';
with  'Bio::EnsEMBL::RNAseqDB::Publications';
with  'Bio::EnsEMBL::RNAseqDB::SRA';
with  'Bio::EnsEMBL::RNAseqDB::Analysis';
with  'Bio::EnsEMBL::RNAseqDB::Track';
with  'Bio::EnsEMBL::RNAseqDB::Bundle';
with  'Bio::EnsEMBL::RNAseqDB::File';
with  'Bio::EnsEMBL::RNAseqDB::Vocabulary';

1;

__END__


=head1 NAME

Bio::EnsEMBL::RNAseqDB - Interface for the RNAseq DB.


=head1 VERSION

This document describes Bio::EnsEMBL::RNAseqDB 1.0.


=head1 SYNOPSIS

    use Bio::EnsEMBL::RNAseqDB;

    # Connect to an RNAseqDB
    my $rdb = Bio::EnsEMBL::RNAseqDB->connect(
      "dbi:mysql:host=$host:port=$port:database=$db",
      $user,
      $password
    );
    
    # Prepare the species table
    $rdb->add_species('aedes_aegypti', 7159, 'Liverpool');
    
    # Add a study
    $rdb->add_sra('SRP009679');


=head1 DESCRIPTION

This module is an object interface for the RNAseqDB. It inherits the Bio::EnsEMBL::RNAseqDB::Schema object, which is a DBIx class. It inherits several roles:
 * Bio::EnsEMBL::RNAseqDB::Bundle.pm
 * Bio::EnsEMBL::RNAseqDB::Common.pm
 * Bio::EnsEMBL::RNAseqDB::File.pm
 * Bio::EnsEMBL::RNAseqDB::Publications.pm
 * Bio::EnsEMBL::RNAseqDB::Schema.pm
 * Bio::EnsEMBL::RNAseqDB::Species.pm
 * Bio::EnsEMBL::RNAseqDB::SRA.pm
 * Bio::EnsEMBL::RNAseqDB::Track.pm
 * Bio::EnsEMBL::RNAseqDB::Vocabulary.pm
The purpose of the interface is to simplify the population of the database.


The module logs with Log4perl (easy mode).

=head1 INTERFACE

=over

=item BUILD connect()

  (Inherited from Bio::EnsEMBL::RNAseqDB::Schema)
  Args           : DBI connection arguments
  Function       : create a connection to an RNAseq DB
  Usage:

    my $rdb = Bio::EnsEMBL::RNAseqDB->connect(
      "dbi:mysql:host=$host:port=$port:database=$db",
      $user,
      $password
    );

=item add_sra()

=item add_private_study()

=item add_private_study_from_json()

 See the role Bio::EnsEMBL::RNAseqDB::SRA

=item add_species()
 See the role Bio::EnsEMBL::RNAseqDB::Species

=back

=head1 AUTHOR

Matthieu Barba  C<< <mbarba@ebi.ac.uk> >>

=cut

