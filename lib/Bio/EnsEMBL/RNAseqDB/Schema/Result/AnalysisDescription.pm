use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::AnalysisDescription;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::AnalysisDescription

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<analysis_description>

=cut

__PACKAGE__->table("analysis_description");

=head1 ACCESSORS

=head2 analysis_description_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 type

  data_type: 'enum'
  extra: {list => ["aligner","indexer","converter","modifier","analyser"]}
  is_nullable: 1

=head2 pattern

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
  "analysis_description_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "type",
  {
    data_type => "enum",
    extra => {
      list => ["aligner", "indexer", "converter", "modifier", "analyser"],
    },
    is_nullable => 1,
  },
  "pattern",
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

=item * L</analysis_description_id>

=back

=cut

__PACKAGE__->set_primary_key("analysis_description_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<metasum>

=over 4

=item * L</metasum>

=back

=cut

__PACKAGE__->add_unique_constraint("metasum", ["metasum"]);

=head2 C<name>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name", ["name"]);

=head1 RELATIONS

=head2 analyses

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Analysis>

=cut

__PACKAGE__->has_many(
  "analyses",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Analysis",
  {
    "foreign.analysis_description_id" => "self.analysis_description_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-09-28 14:36:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GG2Qg2SWhSKbjnqbVtvvTQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
