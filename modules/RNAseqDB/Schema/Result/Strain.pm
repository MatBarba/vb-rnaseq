use utf8;
package RNAseqDB::Schema::Result::Strain;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::Strain

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<strain>

=cut

__PACKAGE__->table("strain");

=head1 ACCESSORS

=head2 strain_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 species_id

  data_type: 'integer'
  is_nullable: 1

=head2 production_name

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 strain

  data_type: 'varchar'
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
  "strain_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "species_id",
  { data_type => "integer", is_nullable => 1 },
  "production_name",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "strain",
  { data_type => "varchar", is_nullable => 1, size => 32 },
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

=item * L</strain_id>

=back

=cut

__PACKAGE__->set_primary_key("strain_id");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-03-08 15:44:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:U2DBMYLzziXEwJqvEL22TQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
