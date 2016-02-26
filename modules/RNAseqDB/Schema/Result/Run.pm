use utf8;
package RNAseqDB::Schema::Result::Run;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::Run

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<run>

=cut

__PACKAGE__->table("run");

=head1 ACCESSORS

=head2 run_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 experiment_id

  data_type: 'integer'
  is_nullable: 0

=head2 sample_id

  data_type: 'integer'
  is_nullable: 0

=head2 run_sra_acc

  data_type: 'char'
  is_nullable: 0
  size: 12

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 submitter

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
  "run_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "experiment_id",
  { data_type => "integer", is_nullable => 0 },
  "sample_id",
  { data_type => "integer", is_nullable => 0 },
  "run_sra_acc",
  { data_type => "char", is_nullable => 0, size => 12 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "submitter",
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

=head1 UNIQUE CONSTRAINTS

=head2 C<run_id>

=over 4

=item * L</run_id>

=back

=cut

__PACKAGE__->add_unique_constraint("run_id", ["run_id"]);

=head2 C<run_sra_acc>

=over 4

=item * L</run_sra_acc>

=back

=cut

__PACKAGE__->add_unique_constraint("run_sra_acc", ["run_sra_acc"]);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-02-26 13:26:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:96tVtruE+B//DWRPA71YSw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
