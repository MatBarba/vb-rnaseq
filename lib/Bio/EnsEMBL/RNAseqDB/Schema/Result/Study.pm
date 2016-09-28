use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::Study;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::Study

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<study>

=cut

__PACKAGE__->table("study");

=head1 ACCESSORS

=head2 study_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 study_sra_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 study_private_acc

  data_type: 'char'
  is_nullable: 1
  size: 12

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 abstract

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
  "study_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "study_sra_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "study_private_acc",
  { data_type => "char", is_nullable => 1, size => 12 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "abstract",
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

=item * L</study_id>

=back

=cut

__PACKAGE__->set_primary_key("study_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<metasum>

=over 4

=item * L</metasum>

=back

=cut

__PACKAGE__->add_unique_constraint("metasum", ["metasum"]);

=head2 C<study_private_acc>

=over 4

=item * L</study_private_acc>

=back

=cut

__PACKAGE__->add_unique_constraint("study_private_acc", ["study_private_acc"]);

=head2 C<study_sra_acc>

=over 4

=item * L</study_sra_acc>

=back

=cut

__PACKAGE__->add_unique_constraint("study_sra_acc", ["study_sra_acc"]);

=head1 RELATIONS

=head2 experiments

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Experiment>

=cut

__PACKAGE__->has_many(
  "experiments",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Experiment",
  { "foreign.study_id" => "self.study_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 study_publications

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::StudyPublication>

=cut

__PACKAGE__->has_many(
  "study_publications",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::StudyPublication",
  { "foreign.study_id" => "self.study_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-09-28 14:36:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9I3XazqZf1zaC8BS+Ep4UA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
