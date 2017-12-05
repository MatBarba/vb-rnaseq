use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::PrivateFile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::PrivateFile

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<private_file>

=cut

__PACKAGE__->table("private_file");

=head1 ACCESSORS

=head2 private_file_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 run_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 path

  data_type: 'text'
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
  "private_file_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "run_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "path",
  { data_type => "text", is_nullable => 1 },
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

=head1 PRIMARY KEY

=over 4

=item * L</private_file_id>

=back

=cut

__PACKAGE__->set_primary_key("private_file_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<md5>

=over 4

=item * L</md5>

=back

=cut

__PACKAGE__->add_unique_constraint("md5", ["md5"]);

=head2 C<metasum>

=over 4

=item * L</metasum>

=back

=cut

__PACKAGE__->add_unique_constraint("metasum", ["metasum"]);

=head1 RELATIONS

=head2 run

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Run>

=cut

__PACKAGE__->belongs_to(
  "run",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Run",
  { run_id => "run_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-12-05 09:59:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dqSQTf665DCpEYLsMIIPIw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
