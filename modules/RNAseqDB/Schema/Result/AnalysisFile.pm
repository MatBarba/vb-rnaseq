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

=head2 analysis_parameter_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 file_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 file_io

  data_type: 'enum'
  extra: {list => ["INPUT","OUTPUT"]}
  is_nullable: 1

=head2 run_id

  data_type: 'integer'
  extra: {unsigned => 1}
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
  "analysis_parameter_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "file_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "file_io",
  {
    data_type => "enum",
    extra => { list => ["INPUT", "OUTPUT"] },
    is_nullable => 1,
  },
  "run_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
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


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-05-03 16:57:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SmAYR0B2/MTdDCsRCa3vIg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
