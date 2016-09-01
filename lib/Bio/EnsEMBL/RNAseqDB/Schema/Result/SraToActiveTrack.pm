use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::SraToActiveTrack;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::SraToActiveTrack - VIEW

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<sra_to_active_track>

=cut

__PACKAGE__->table("sra_to_active_track");

=head1 ACCESSORS

=head2 study_id

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 study_sra_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 study_private_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 experiment_id

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 1

=head2 experiment_sra_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 experiment_private_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 run_id

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 1

=head2 run_sra_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 run_private_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 sample_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 sample_sra_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 sample_private_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 sample_title

  data_type: 'text'
  is_nullable: 1

=head2 sample_description

  data_type: 'text'
  is_nullable: 1

=head2 track_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 track_status

  data_type: 'enum'
  default_value: 'ACTIVE'
  extra: {list => ["ACTIVE","RETIRED","MERGED"]}
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

=head2 production_name

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=cut

__PACKAGE__->add_columns(
  "study_id",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "study_sra_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "study_private_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "experiment_id",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 1,
  },
  "experiment_sra_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "experiment_private_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "run_id",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 1,
  },
  "run_sra_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "run_private_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "sample_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "sample_sra_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "sample_private_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "sample_title",
  { data_type => "text", is_nullable => 1 },
  "sample_description",
  { data_type => "text", is_nullable => 1 },
  "track_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "track_status",
  {
    data_type => "enum",
    default_value => "ACTIVE",
    extra => { list => ["ACTIVE", "RETIRED", "MERGED"] },
    is_nullable => 1,
  },
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
  "production_name",
  { data_type => "varchar", is_nullable => 1, size => 64 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-07-08 10:11:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zpCvtt1Lb6090h7f/6YUEg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
