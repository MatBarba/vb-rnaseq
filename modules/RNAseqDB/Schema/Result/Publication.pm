use utf8;
package RNAseqDB::Schema::Result::Publication;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::Publication

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<publication>

=cut

__PACKAGE__->table("publication");

=head1 ACCESSORS

=head2 publication_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 pubmed_id

  data_type: 'integer'
  is_nullable: 1

=head2 doi

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 authors

  data_type: 'text'
  is_nullable: 1

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 abstract

  data_type: 'text'
  is_nullable: 1

=head2 year

  data_type: 'integer'
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
  "publication_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "pubmed_id",
  { data_type => "integer", is_nullable => 1 },
  "doi",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "authors",
  { data_type => "text", is_nullable => 1 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "abstract",
  { data_type => "text", is_nullable => 1 },
  "year",
  { data_type => "integer", is_nullable => 1 },
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

=head2 C<publication_id>

=over 4

=item * L</publication_id>

=back

=cut

__PACKAGE__->add_unique_constraint("publication_id", ["publication_id"]);

=head2 C<pubmed_id>

=over 4

=item * L</pubmed_id>

=back

=cut

__PACKAGE__->add_unique_constraint("pubmed_id", ["pubmed_id"]);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-02-26 13:26:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:m8jCgusXzbQJb4ZpJYMr6Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
