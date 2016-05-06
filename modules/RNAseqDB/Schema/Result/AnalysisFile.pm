use utf8;
package RNAseqDB::Schema::Result::AnalysisFile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::AnalysisFile

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<analysis_file>

=cut

__PACKAGE__->table("analysis_file");

=head1 ACCESSORS

=head2 analysis_file_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 analysis_param_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 file_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 file_io

  data_type: 'enum'
  extra: {list => ["INPUT","OUTPUT"]}
  is_nullable: 1

=head2 run_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 metasum

  data_type: 'char'
  is_nullable: 1
  size: 32

=cut

__PACKAGE__->add_columns(
  "analysis_file_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "analysis_param_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "file_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "file_io",
  {
    data_type => "enum",
    extra => { list => ["INPUT", "OUTPUT"] },
    is_nullable => 1,
  },
  "run_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "metasum",
  { data_type => "char", is_nullable => 1, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</analysis_file_id>

=back

=cut

__PACKAGE__->set_primary_key("analysis_file_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<metasum>

=over 4

=item * L</metasum>

=back

=cut

__PACKAGE__->add_unique_constraint("metasum", ["metasum"]);

=head1 RELATIONS

=head2 analysis_param

Type: belongs_to

Related object: L<RNAseqDB::Schema::Result::AnalysisParam>

=cut

__PACKAGE__->belongs_to(
  "analysis_param",
  "RNAseqDB::Schema::Result::AnalysisParam",
  { analysis_param_id => "analysis_param_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 file

Type: belongs_to

Related object: L<RNAseqDB::Schema::Result::File>

=cut

__PACKAGE__->belongs_to(
  "file",
  "RNAseqDB::Schema::Result::File",
  { file_id => "file_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 run

Type: belongs_to

Related object: L<RNAseqDB::Schema::Result::Run>

=cut

__PACKAGE__->belongs_to(
  "run",
  "RNAseqDB::Schema::Result::Run",
  { run_id => "run_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-05-06 14:23:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RZuB5OXJ0BYnHX2IyAhN8A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
