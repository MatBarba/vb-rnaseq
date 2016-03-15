use utf8;
package RNAseqDB::DB;

use strict;
use warnings;
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
extends 'RNAseqDB::Schema';
with  'RNAseqDB::Publications';
with  'RNAseqDB::SRA';
with  'RNAseqDB::Species';

1;

__END__


=head1 NAME

RNAseqDB::DB - Interface for the RNAseq DB.


=head1 VERSION

This document describes RNAseqDB::DB version 0.0.1


=head1 SYNOPSIS

    use RNAseqDB::DB;

    # Connect to an RNAseqDB
    my $rdb = RNAseqDB::DB->connect(
      "dbi:mysql:host=$host:port=$port:database=$db",
      $user,
      $password
    );
    
    # Prepare the species table
    $rdb->add_species('aedes_aegypti', 7159, 'Liverpool');
    
    # Add a study
    $rdb->add_sra('SRP009679');


=head1 DESCRIPTION

This module is an object interface for the RNAseqDB. It inherits the RNAseqDB::Schema object, which is a DBIx class. It inherits several roles:
 * RNAseqDB::SRA
 * RNAseqDB::Species

The purpose of the interface is to simplify the population of the database.


The module logs with Log4perl (easy mode).

=head1 INTERFACE

=over

=item BUILD connect()

  (Inherited from RNAseqDB::Schema)
  Args           : DBI connection arguments
  Function       : create a connection to an RNAseq DB
  Usage:

    my $rdb = RNAseqDB::DB->connect(
      "dbi:mysql:host=$host:port=$port:database=$db",
      $user,
      $password
    );

=item add_sra()
=item add_private_study()
=item add_private_study_from_json()

 See the role RNAseqDB::SRA

=item add_species()
 See the role RNAseqDB::Species

=back

=head1 AUTHOR

Matthieu Barba  C<< <mbarba@ebi.ac.uk> >>

