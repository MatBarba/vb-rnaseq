use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::TrackAnalysis;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::TrackAnalysis

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<track_analysis>

=cut

__PACKAGE__->table("track_analysis");

=head1 ACCESSORS

=head2 track_analysis_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 track_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 assembly_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "track_analysis_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "track_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "assembly_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</track_analysis_id>

=back

=cut

__PACKAGE__->set_primary_key("track_analysis_id");

=head1 RELATIONS

=head2 analyses

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Analysis>

=cut

__PACKAGE__->has_many(
  "analyses",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Analysis",
  { "foreign.track_analysis_id" => "self.track_analysis_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 assembly

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Assembly>

=cut

__PACKAGE__->belongs_to(
  "assembly",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Assembly",
  { assembly_id => "assembly_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 files

Type: has_many

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::File>

=cut

__PACKAGE__->has_many(
  "files",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::File",
  { "foreign.track_analysis_id" => "self.track_analysis_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 track

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Track>

=cut

__PACKAGE__->belongs_to(
  "track",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Track",
  { track_id => "track_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-12-05 09:59:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:P829ytxn5FwIHTsjsUbv6g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
