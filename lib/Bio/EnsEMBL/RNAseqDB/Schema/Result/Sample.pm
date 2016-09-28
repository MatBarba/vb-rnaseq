use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::Sample;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::Sample

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<sample>

=cut

__PACKAGE__->table("sample");

=head1 ACCESSORS

=head2 sample_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 sample_sra_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 sample_private_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 taxon_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 strain

  data_type: 'text'
  is_nullable: 1

=head2 strain_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 biosample_acc

  data_type: 'varchar'
  is_nullable: 1
  size: 15

=head2 biosample_group_acc

  data_type: 'varchar'
  is_nullable: 1
  size: 15

=head2 label

  data_type: 'text'
  is_nullable: 1

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
  "sample_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "sample_sra_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "sample_private_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "taxon_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "strain",
  { data_type => "text", is_nullable => 1 },
  "strain_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "biosample_acc",
  { data_type => "varchar", is_nullable => 1, size => 15 },
  "biosample_group_acc",
  { data_type => "varchar", is_nullable => 1, size => 15 },
  "label",
  { data_type => "text", is_nullable => 1 },
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

=item * L</sample_id>

=back

=cut

__PACKAGE__->set_primary_key("sample_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<biosample_acc>

=over 4

=item * L</biosample_acc>

=back

=cut

__PACKAGE__->add_unique_constraint("biosample_acc", ["biosample_acc"]);

=head2 C<metasum>

=over 4

=item * L</metasum>

=back

=cut

__PACKAGE__->add_unique_constraint("metasum", ["metasum"]);

=head2 C<sample_private_acc>

=over 4

=item * L</sample_private_acc>

=back

=cut

__PACKAGE__->add_unique_constraint("sample_private_acc", ["sample_private_acc"]);

=head2 C<sample_sra_acc>

=over 4

=item * L</sample_sra_acc>

=back

=cut

__PACKAGE__->add_unique_constraint("sample_sra_acc", ["sample_sra_acc"]);

=head1 RELATIONS

=head2 runs

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Run>

=cut

__PACKAGE__->has_many(
  "runs",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Run",
  { "foreign.sample_id" => "self.sample_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

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


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-09-28 14:36:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gIe6Nz9tiKSg3InPCPK6XA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
