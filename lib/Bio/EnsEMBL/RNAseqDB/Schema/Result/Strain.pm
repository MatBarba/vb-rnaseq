use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::Strain;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::Strain

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<strain>

=cut

__PACKAGE__->table("strain");

=head1 ACCESSORS

=head2 strain_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 species_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 production_name

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 strain

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 metasum

  data_type: 'char'
  is_nullable: 1
  size: 32

=head2 date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 1

=head2 status

  data_type: 'enum'
  default_value: 'ACTIVE'
  extra: {list => ["ACTIVE","RETIRED"]}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "strain_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "species_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "production_name",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "strain",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "metasum",
  { data_type => "char", is_nullable => 1, size => 32 },
  "date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 1,
  },
  "status",
  {
    data_type => "enum",
    default_value => "ACTIVE",
    extra => { list => ["ACTIVE", "RETIRED"] },
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</strain_id>

=back

=cut

__PACKAGE__->set_primary_key("strain_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<metasum>

=over 4

=item * L</metasum>

=back

=cut

__PACKAGE__->add_unique_constraint("metasum", ["metasum"]);

=head1 RELATIONS

=head2 assemblies

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Assembly>

=cut

__PACKAGE__->has_many(
  "assemblies",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Assembly",
  { "foreign.strain_id" => "self.strain_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 species

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Species>

=cut

__PACKAGE__->belongs_to(
  "species",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Species",
  { species_id => "species_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2019-06-05 14:34:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WkLmC7q+iiUsB7PV6C0R6A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
