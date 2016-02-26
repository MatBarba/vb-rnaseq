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
  is_nullable: 1

=head2 file_id

  data_type: 'integer'
  is_nullable: 1

=head2 file_io

  data_type: 'enum'
  extra: {list => ["INPUT","OUTPUT"]}
  is_nullable: 1

=head2 scope

  data_type: 'enum'
  extra: {list => ["run","sample"]}
  is_nullable: 1

=head2 scope_id

  data_type: 'integer'
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
  { data_type => "integer", is_nullable => 1 },
  "file_id",
  { data_type => "integer", is_nullable => 1 },
  "file_io",
  {
    data_type => "enum",
    extra => { list => ["INPUT", "OUTPUT"] },
    is_nullable => 1,
  },
  "scope",
  {
    data_type => "enum",
    extra => { list => ["run", "sample"] },
    is_nullable => 1,
  },
  "scope_id",
  { data_type => "integer", is_nullable => 1 },
  "metasum",
  { data_type => "char", is_nullable => 1, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</analysis_file_id>

=back

=cut

__PACKAGE__->set_primary_key("analysis_file_id");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-02-26 16:36:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ym+VbBw6k0Slc7Ya7Y3jwg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
