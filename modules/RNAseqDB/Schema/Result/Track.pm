use utf8;
package RNAseqDB::Schema::Result::Track;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::Track

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<track>

=cut

__PACKAGE__->table("track");

=head1 ACCESSORS

=head2 track_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 file_id

  data_type: 'integer'
  is_nullable: 0

=head2 sample_id

  data_type: 'integer'
  is_nullable: 0

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 description

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
  "track_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "file_id",
  { data_type => "integer", is_nullable => 0 },
  "sample_id",
  { data_type => "integer", is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "description",
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

=item * L</track_id>

=back

=cut

__PACKAGE__->set_primary_key("track_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<file_id>

=over 4

=item * L</file_id>

=back

=cut

__PACKAGE__->add_unique_constraint("file_id", ["file_id"]);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-02-26 16:36:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:clXX/mtXaf8Uf0i1PX0h7g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
