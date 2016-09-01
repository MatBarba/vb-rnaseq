use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::Publication;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::Publication

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
  extra: {unsigned => 1}
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
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
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

=head1 PRIMARY KEY

=over 4

=item * L</publication_id>

=back

=cut

__PACKAGE__->set_primary_key("publication_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<metasum>

=over 4

=item * L</metasum>

=back

=cut

__PACKAGE__->add_unique_constraint("metasum", ["metasum"]);

=head2 C<pubmed_id>

=over 4

=item * L</pubmed_id>

=back

=cut

__PACKAGE__->add_unique_constraint("pubmed_id", ["pubmed_id"]);

=head1 RELATIONS

=head2 study_publications

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::StudyPublication>

=cut

__PACKAGE__->has_many(
  "study_publications",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::StudyPublication",
  { "foreign.publication_id" => "self.publication_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-05-06 14:23:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KA/y3LuA164SKiHRoAvTIA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
