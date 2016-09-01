use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::DrupalNode;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::DrupalNode

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<drupal_node>

=cut

__PACKAGE__->table("drupal_node");

=head1 ACCESSORS

=head2 drupal_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 drupal_node_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 autogen_text

  data_type: 'text'
  is_nullable: 1

=head2 manual_text

  data_type: 'text'
  is_nullable: 1

=head2 metasum

  data_type: 'char'
  is_nullable: 1
  size: 32

=head2 autogen_title

  data_type: 'text'
  is_nullable: 1

=head2 manual_title

  data_type: 'text'
  is_nullable: 1

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
  "drupal_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "drupal_node_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "autogen_text",
  { data_type => "text", is_nullable => 1 },
  "manual_text",
  { data_type => "text", is_nullable => 1 },
  "metasum",
  { data_type => "char", is_nullable => 1, size => 32 },
  "autogen_title",
  { data_type => "text", is_nullable => 1 },
  "manual_title",
  { data_type => "text", is_nullable => 1 },
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

=item * L</drupal_id>

=back

=cut

__PACKAGE__->set_primary_key("drupal_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<drupal_node_id>

=over 4

=item * L</drupal_node_id>

=back

=cut

__PACKAGE__->add_unique_constraint("drupal_node_id", ["drupal_node_id"]);

=head1 RELATIONS

=head2 drupal_node_tracks

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::DrupalNodeTrack>

=cut

__PACKAGE__->has_many(
  "drupal_node_tracks",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::DrupalNodeTrack",
  { "foreign.drupal_id" => "self.drupal_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-05-06 14:32:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:t/cjHiLO3s1mKFIuZ6vGig


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
