use utf8;
package RNAseqDB::Schema::Result::SraTrack;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::SraTrack

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<sra_track>

=cut

__PACKAGE__->table("sra_track");

=head1 ACCESSORS

=head2 sra_track_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 run_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 track_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sra_track_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "run_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "track_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
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

=item * L</sra_track_id>

=back

=cut

__PACKAGE__->set_primary_key("sra_track_id");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-05-03 16:57:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XAGp62tONkvbwrmJ3RpP4w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to( track  => 'RNAseqDB::Schema::Result::Track',  'track_id' );
__PACKAGE__->belongs_to( run => 'RNAseqDB::Schema::Result::Run', 'run_id');
1;

