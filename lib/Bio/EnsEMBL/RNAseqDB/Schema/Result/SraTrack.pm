use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::SraTrack;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::SraTrack

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
  "sra_track_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "run_id",
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

=item * L</sra_track_id>

=back

=cut

__PACKAGE__->set_primary_key("sra_track_id");

=head1 RELATIONS

=head2 run

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Run>

=cut

__PACKAGE__->belongs_to(
  "run",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Run",
  { run_id => "run_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 track

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Track>

=cut

__PACKAGE__->belongs_to(
  "track",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Track",
  { track_id => "track_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-05-13 14:43:34
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Hm5zCfIooBrF3nrH6aXgaw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

