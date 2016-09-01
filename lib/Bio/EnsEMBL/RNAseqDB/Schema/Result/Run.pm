use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::Run;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::Run

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<run>

=cut

__PACKAGE__->table("run");

=head1 ACCESSORS

=head2 run_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 experiment_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 sample_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 run_sra_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 run_private_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 submitter

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
  "run_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "experiment_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "sample_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "run_sra_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "run_private_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "submitter",
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

=item * L</run_id>

=back

=cut

__PACKAGE__->set_primary_key("run_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<metasum>

=over 4

=item * L</metasum>

=back

=cut

__PACKAGE__->add_unique_constraint("metasum", ["metasum"]);

=head2 C<run_private_acc>

=over 4

=item * L</run_private_acc>

=back

=cut

__PACKAGE__->add_unique_constraint("run_private_acc", ["run_private_acc"]);

=head2 C<run_sra_acc>

=over 4

=item * L</run_sra_acc>

=back

=cut

__PACKAGE__->add_unique_constraint("run_sra_acc", ["run_sra_acc"]);

=head1 RELATIONS

=head2 experiment

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Experiment>

=cut

__PACKAGE__->belongs_to(
  "experiment",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Experiment",
  { experiment_id => "experiment_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 private_files

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::PrivateFile>

=cut

__PACKAGE__->has_many(
  "private_files",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::PrivateFile",
  { "foreign.run_id" => "self.run_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 sample

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Sample>

=cut

__PACKAGE__->belongs_to(
  "sample",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Sample",
  { sample_id => "sample_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 sra_tracks

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::SraTrack>

=cut

__PACKAGE__->has_many(
  "sra_tracks",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::SraTrack",
  { "foreign.run_id" => "self.run_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-05-17 16:24:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fk2oqJ4zgGkSS1mLb7RkJA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

