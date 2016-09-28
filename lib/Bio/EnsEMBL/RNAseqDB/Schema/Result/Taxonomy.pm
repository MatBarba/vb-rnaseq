use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::Taxonomy;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::Taxonomy - VIEW

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<taxonomy>

=cut

__PACKAGE__->table("taxonomy");

=head1 ACCESSORS

=head2 binomial_name

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 taxon_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 production_name

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 strain

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 strain_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 status

  data_type: 'enum'
  default_value: 'ACTIVE'
  extra: {list => ["ACTIVE","RETIRED"]}
  is_nullable: 1

=head2 assembly

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 assembly_accession

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=cut

__PACKAGE__->add_columns(
  "binomial_name",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "taxon_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "production_name",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "strain",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "strain_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "status",
  {
    data_type => "enum",
    default_value => "ACTIVE",
    extra => { list => ["ACTIVE", "RETIRED"] },
    is_nullable => 1,
  },
  "assembly",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "assembly_accession",
  { data_type => "varchar", is_nullable => 1, size => 32 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-09-28 14:36:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7uSuP/uuZ8BrlZcjA1Hg9A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
