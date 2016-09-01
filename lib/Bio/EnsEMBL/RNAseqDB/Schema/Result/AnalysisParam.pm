use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::AnalysisParam;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::AnalysisParam

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<analysis_param>

=cut

__PACKAGE__->table("analysis_param");

=head1 ACCESSORS

=head2 analysis_param_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 analysis_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 program

  data_type: 'text'
  is_nullable: 1

=head2 parameters

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
  "analysis_param_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "analysis_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "program",
  { data_type => "text", is_nullable => 1 },
  "parameters",
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

=item * L</analysis_param_id>

=back

=cut

__PACKAGE__->set_primary_key("analysis_param_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<metasum>

=over 4

=item * L</metasum>

=back

=cut

__PACKAGE__->add_unique_constraint("metasum", ["metasum"]);

=head1 RELATIONS

=head2 analysis

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Analysis>

=cut

__PACKAGE__->belongs_to(
  "analysis",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Analysis",
  { analysis_id => "analysis_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 analysis_files

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::AnalysisFile>

=cut

__PACKAGE__->has_many(
  "analysis_files",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::AnalysisFile",
  { "foreign.analysis_param_id" => "self.analysis_param_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-05-06 14:23:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xGGUGWDdlfZrwqoGGroptw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
