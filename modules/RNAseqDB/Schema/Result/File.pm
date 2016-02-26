use utf8;
package RNAseqDB::Schema::Result::File;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::File

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<file>

=cut

__PACKAGE__->table("file");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 path

  data_type: 'text'
  is_nullable: 0

=head2 type

  data_type: 'enum'
  extra: {list => ["fastq","bam","bai","bed","bigwig"]}
  is_nullable: 1

=head2 md5

  data_type: 'char'
  is_nullable: 1
  size: 32

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
  "file_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "path",
  { data_type => "text", is_nullable => 0 },
  "type",
  {
    data_type => "enum",
    extra => { list => ["fastq", "bam", "bai", "bed", "bigwig"] },
    is_nullable => 1,
  },
  "md5",
  { data_type => "char", is_nullable => 1, size => 32 },
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

=head1 UNIQUE CONSTRAINTS

=head2 C<file_id>

=over 4

=item * L</file_id>

=back

=cut

__PACKAGE__->add_unique_constraint("file_id", ["file_id"]);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-02-26 13:26:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OGC1uEy2xBRj8QGNabxRGQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
