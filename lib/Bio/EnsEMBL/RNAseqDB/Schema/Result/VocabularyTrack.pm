use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::VocabularyTrack;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::VocabularyTrack

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<vocabulary_track>

=cut

__PACKAGE__->table("vocabulary_track");

=head1 ACCESSORS

=head2 vocabulary_track_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 vocabulary_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 track_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "vocabulary_track_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "vocabulary_id",
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
);

=head1 PRIMARY KEY

=over 4

=item * L</vocabulary_track_id>

=back

=cut

__PACKAGE__->set_primary_key("vocabulary_track_id");

=head1 RELATIONS

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

=head2 vocabulary

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Vocabulary>

=cut

__PACKAGE__->belongs_to(
  "vocabulary",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Vocabulary",
  { vocabulary_id => "vocabulary_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-09-28 14:36:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yF2KGL5VpQ2WJRA67FwaQg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
