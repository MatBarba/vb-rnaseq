use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::SraToTrack;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::SraToTrack - VIEW

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<sra_to_track>

=cut

__PACKAGE__->table("sra_to_track");
__PACKAGE__->result_source_instance->view_definition("select `vb_rnaseqdb`.`study`.`study_id` AS `study_id`,`vb_rnaseqdb`.`study`.`study_sra_acc` AS `study_sra_acc`,`vb_rnaseqdb`.`study`.`study_private_acc` AS `study_private_acc`,`vb_rnaseqdb`.`experiment`.`experiment_id` AS `experiment_id`,`vb_rnaseqdb`.`experiment`.`experiment_sra_acc` AS `experiment_sra_acc`,`vb_rnaseqdb`.`experiment`.`experiment_private_acc` AS `experiment_private_acc`,`vb_rnaseqdb`.`run`.`run_id` AS `run_id`,`vb_rnaseqdb`.`run`.`run_sra_acc` AS `run_sra_acc`,`vb_rnaseqdb`.`run`.`run_private_acc` AS `run_private_acc`,`vb_rnaseqdb`.`run`.`sample_id` AS `sample_id`,`vb_rnaseqdb`.`sample`.`sample_sra_acc` AS `sample_sra_acc`,`vb_rnaseqdb`.`sample`.`sample_private_acc` AS `sample_private_acc`,`vb_rnaseqdb`.`sample`.`title` AS `sample_title`,`vb_rnaseqdb`.`sample`.`description` AS `sample_description`,`vb_rnaseqdb`.`sra_track`.`track_id` AS `track_id`,`vb_rnaseqdb`.`track`.`status` AS `track_status`,`vb_rnaseqdb`.`track`.`merge_level` AS `merge_level`,`vb_rnaseqdb`.`track`.`merge_id` AS `merge_id`,`vb_rnaseqdb`.`track`.`merge_text` AS `merge_text`,`taxonomy`.`production_name` AS `production_name` from ((((((`vb_rnaseqdb`.`study` left join `vb_rnaseqdb`.`experiment` on((`vb_rnaseqdb`.`study`.`study_id` = `vb_rnaseqdb`.`experiment`.`study_id`))) left join `vb_rnaseqdb`.`run` on((`vb_rnaseqdb`.`experiment`.`experiment_id` = `vb_rnaseqdb`.`run`.`experiment_id`))) left join `vb_rnaseqdb`.`sample` on((`vb_rnaseqdb`.`run`.`sample_id` = `vb_rnaseqdb`.`sample`.`sample_id`))) left join `vb_rnaseqdb`.`sra_track` on((`vb_rnaseqdb`.`run`.`run_id` = `vb_rnaseqdb`.`sra_track`.`run_id`))) left join `vb_rnaseqdb`.`track` on((`vb_rnaseqdb`.`sra_track`.`track_id` = `vb_rnaseqdb`.`track`.`track_id`))) left join `vb_rnaseqdb`.`taxonomy` on((`vb_rnaseqdb`.`sample`.`strain_id` = `taxonomy`.`strain_id`)))");

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


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-12-05 09:59:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:u4WLrN9vn0p9hUuZzo8RWQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
