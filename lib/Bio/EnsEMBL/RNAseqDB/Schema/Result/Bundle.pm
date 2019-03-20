use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::Bundle;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::Bundle

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<bundle>

=cut

__PACKAGE__->table("bundle");

=head1 ACCESSORS

=head2 bundle_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 drupal_node_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 title_auto

  data_type: 'text'
  is_nullable: 1

=head2 text_auto

  data_type: 'text'
  is_nullable: 1

=head2 text_manual

  data_type: 'text'
  is_nullable: 1

=head2 title_manual

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

=head2 assembly_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "bundle_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "drupal_node_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "title_auto",
  { data_type => "text", is_nullable => 1 },
  "text_auto",
  { data_type => "text", is_nullable => 1 },
  "text_manual",
  { data_type => "text", is_nullable => 1 },
  "title_manual",
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
  "assembly_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</bundle_id>

=back

=cut

__PACKAGE__->set_primary_key("bundle_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<drupal_node_id>

=over 4

=item * L</drupal_node_id>

=back

=cut

__PACKAGE__->add_unique_constraint("drupal_node_id", ["drupal_node_id"]);

=head1 RELATIONS

=head2 assembly

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Assembly>

=cut

__PACKAGE__->belongs_to(
  "assembly",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Assembly",
  { assembly_id => "assembly_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 bundle_tracks

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::BundleTrack>

=cut

__PACKAGE__->has_many(
  "bundle_tracks",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::BundleTrack",
  { "foreign.bundle_id" => "self.bundle_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2019-03-20 14:25:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WPtyVnZ3byeFbckfFf6Gug


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
