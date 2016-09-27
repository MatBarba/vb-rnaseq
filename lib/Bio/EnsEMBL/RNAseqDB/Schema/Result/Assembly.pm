use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::Assembly;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::Assembly

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<assembly>

=cut

__PACKAGE__->table("assembly");

=head1 ACCESSORS

=head2 assembly_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 strain_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 assembly

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 assembly_accession

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 latest

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

=head2 date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "assembly_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "strain_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "assembly",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "assembly_accession",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "latest",
  { data_type => "tinyint", default_value => 1, is_nullable => 1 },
  "date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</assembly_id>

=back

=cut

__PACKAGE__->set_primary_key("assembly_id");

=head1 RELATIONS

=head2 strain

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Strain>

=cut

__PACKAGE__->belongs_to(
  "strain",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Strain",
  { strain_id => "strain_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-09-27 09:51:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Nxhz7PBq6hUH2IBu5lrB0g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
