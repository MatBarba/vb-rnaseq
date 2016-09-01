use utf8;
package RNAseqDB::Schema::Result::Vocabulary;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::Vocabulary

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<vocabulary>

=cut

__PACKAGE__->table("vocabulary");

=head1 ACCESSORS

=head2 vocabulary_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 voc_name

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 voc_type

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=cut

__PACKAGE__->add_columns(
  "vocabulary_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "voc_name",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "voc_type",
  { data_type => "varchar", is_nullable => 1, size => 128 },
);

=head1 PRIMARY KEY

=over 4

=item * L</vocabulary_id>

=back

=cut

__PACKAGE__->set_primary_key("vocabulary_id");

=head1 RELATIONS

=head2 vocabulary_tracks

Type: has_many

Related object: L<RNAseqDB::Schema::Result::VocabularyTrack>

=cut

__PACKAGE__->has_many(
  "vocabulary_tracks",
  "RNAseqDB::Schema::Result::VocabularyTrack",
  { "foreign.vocabulary_id" => "self.vocabulary_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-07-19 11:25:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vj7k43Rt3L48ZgOWEdJpYw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
