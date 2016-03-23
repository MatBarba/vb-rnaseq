use utf8;
package RNAseqDB::Schema::Result::DrupalNode;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::DrupalNode

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<drupal_node>

=cut

__PACKAGE__->table("drupal_node");

=head1 ACCESSORS

=head2 drupal_node_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 experiment_id

  data_type: 'integer'
  is_nullable: 1

=head2 autogen_txt

  data_type: 'text'
  is_nullable: 1

=head2 manual_txt

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
  "drupal_node_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "experiment_id",
  { data_type => "integer", is_nullable => 1 },
  "autogen_txt",
  { data_type => "text", is_nullable => 1 },
  "manual_txt",
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

=item * L</drupal_node_id>

=back

=cut

__PACKAGE__->set_primary_key("drupal_node_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<experiment_id>

=over 4

=item * L</experiment_id>

=back

=cut

__PACKAGE__->add_unique_constraint("experiment_id", ["experiment_id"]);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-03-23 09:59:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VerS5fAmBNdFRg9mObzA4A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
