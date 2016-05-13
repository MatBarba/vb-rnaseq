use utf8;
package RNAseqDB::Schema::Result::DrupalNodeTrack;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::DrupalNodeTrack

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<drupal_node_track>

=cut

__PACKAGE__->table("drupal_node_track");

=head1 ACCESSORS

=head2 drupal_node_track_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 drupal_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 track_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "drupal_node_track_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "drupal_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "track_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
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

=item * L</drupal_node_track_id>

=back

=cut

__PACKAGE__->set_primary_key("drupal_node_track_id");

=head1 RELATIONS

=head2 drupal

Type: belongs_to

Related object: L<RNAseqDB::Schema::Result::DrupalNode>

=cut

__PACKAGE__->belongs_to(
  "drupal",
  "RNAseqDB::Schema::Result::DrupalNode",
  { drupal_id => "drupal_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 track

Type: belongs_to

Related object: L<RNAseqDB::Schema::Result::Track>

=cut

__PACKAGE__->belongs_to(
  "track",
  "RNAseqDB::Schema::Result::Track",
  { track_id => "track_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-05-13 14:43:34
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ifCy4QcIep+w6nCQDFp0HA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
