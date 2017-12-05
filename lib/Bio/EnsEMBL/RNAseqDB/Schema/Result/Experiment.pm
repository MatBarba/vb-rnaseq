use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::Experiment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::Experiment

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<experiment>

=cut

__PACKAGE__->table("experiment");

=head1 ACCESSORS

=head2 experiment_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 study_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 experiment_sra_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 experiment_private_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 title

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
  "experiment_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "study_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "experiment_sra_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "experiment_private_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "title",
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

=item * L</experiment_id>

=back

=cut

__PACKAGE__->set_primary_key("experiment_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<experiment_private_acc>

=over 4

=item * L</experiment_private_acc>

=back

=cut

__PACKAGE__->add_unique_constraint("experiment_private_acc", ["experiment_private_acc"]);

=head2 C<experiment_sra_acc>

=over 4

=item * L</experiment_sra_acc>

=back

=cut

__PACKAGE__->add_unique_constraint("experiment_sra_acc", ["experiment_sra_acc"]);

=head2 C<metasum>

=over 4

=item * L</metasum>

=back

=cut

__PACKAGE__->add_unique_constraint("metasum", ["metasum"]);

=head1 RELATIONS

=head2 runs

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Run>

=cut

__PACKAGE__->has_many(
  "runs",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Run",
  { "foreign.experiment_id" => "self.experiment_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 study

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Study>

=cut

__PACKAGE__->belongs_to(
  "study",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Study",
  { study_id => "study_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-12-05 09:59:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RzXPBNWXEkB8IUpp6cZzAQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
