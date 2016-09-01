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

=head2 title_auto

  data_type: 'text'
  is_nullable: 1

=head2 text_auto

  data_type: 'text'
  is_nullable: 1

=head2 title_manual

  data_type: 'text'
  is_nullable: 1

=head2 text_manual

  data_type: 'text'
  is_nullable: 1

=head2 merge_level

  data_type: 'enum'
  extra: {list => ["taxon","study","experiment","run","sample"]}
  is_nullable: 1

=head2 merge_id

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 merge_text

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
  extra: {list => ["ACTIVE","RETIRED","MERGED"]}
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
  "title_auto",
  { data_type => "text", is_nullable => 1 },
  "text_auto",
  { data_type => "text", is_nullable => 1 },
  "title_manual",
  { data_type => "text", is_nullable => 1 },
  "text_manual",
  { data_type => "text", is_nullable => 1 },
  "merge_level",
  {
    data_type => "enum",
    extra => { list => ["taxon", "study", "experiment", "run", "sample"] },
    is_nullable => 1,
  },
  "merge_id",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "merge_text",
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
    extra => { list => ["ACTIVE", "RETIRED", "MERGED"] },
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

=head2 C<merge_id>

=over 4

=item * L</merge_id>

=back

=cut

__PACKAGE__->add_unique_constraint("merge_id", ["merge_id"]);

=head1 RELATIONS

=head2 analyses

Type: has_many

Related object: L<RNAseqDB::Schema::Result::Analysis>

=cut

__PACKAGE__->has_many(
  "analyses",
  "RNAseqDB::Schema::Result::Analysis",
  { "foreign.track_id" => "self.track_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bundle_tracks

Type: has_many

Related object: L<RNAseqDB::Schema::Result::BundleTrack>

=cut

__PACKAGE__->has_many(
  "bundle_tracks",
  "RNAseqDB::Schema::Result::BundleTrack",
  { "foreign.track_id" => "self.track_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 files

Type: has_many

Related object: L<RNAseqDB::Schema::Result::File>

=cut

__PACKAGE__->has_many(
  "files",
  "RNAseqDB::Schema::Result::File",
  { "foreign.track_id" => "self.track_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 sra_tracks

Type: has_many

Related object: L<RNAseqDB::Schema::Result::SraTrack>

=cut

__PACKAGE__->has_many(
  "sra_tracks",
  "RNAseqDB::Schema::Result::SraTrack",
  { "foreign.track_id" => "self.track_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 vocabulary_tracks

Type: has_many

Related object: L<RNAseqDB::Schema::Result::VocabularyTrack>

=cut

__PACKAGE__->has_many(
  "vocabulary_tracks",
  "RNAseqDB::Schema::Result::VocabularyTrack",
  { "foreign.track_id" => "self.track_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-07-22 12:01:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IOv9WpVGPMMAyBEj+uMalw


# You can replace this text with custom code or comments, and it will be preserved on regeneration

1;

