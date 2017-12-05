use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::BundleTrack;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::BundleTrack

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<bundle_track>

=cut

__PACKAGE__->table("bundle_track");

=head1 ACCESSORS

=head2 bundle_track_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 bundle_id

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
  "bundle_track_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "bundle_id",
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

=item * L</bundle_track_id>

=back

=cut

__PACKAGE__->set_primary_key("bundle_track_id");

=head1 RELATIONS

=head2 bundle

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Bundle>

=cut

__PACKAGE__->belongs_to(
  "bundle",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Bundle",
  { bundle_id => "bundle_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 track

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Track>

=cut

__PACKAGE__->belongs_to(
  "track",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Track",
  { track_id => "track_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-12-05 09:59:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Qn6CN1sPF8n8J8uotjG0Fw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
