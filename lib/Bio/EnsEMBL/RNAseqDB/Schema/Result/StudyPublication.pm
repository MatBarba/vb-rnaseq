use utf8;
package Bio::EnsEMBL::RNAseqDB::Schema::Result::StudyPublication;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::RNAseqDB::Schema::Result::StudyPublication

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<study_publication>

=cut

__PACKAGE__->table("study_publication");

=head1 ACCESSORS

=head2 study_pub_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 study_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 publication_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "study_pub_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "study_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "publication_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</study_pub_id>

=back

=cut

__PACKAGE__->set_primary_key("study_pub_id");

=head1 RELATIONS

=head2 publication

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Publication>

=cut

__PACKAGE__->belongs_to(
  "publication",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Publication",
  { publication_id => "publication_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 study

Type: belongs_to

Related object: L<Bio::EnsEMBL::RNAseqDB::Schema::Result::Study>

=cut

__PACKAGE__->belongs_to(
  "study",
  "Bio::EnsEMBL::RNAseqDB::Schema::Result::Study",
  { study_id => "study_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-05-06 14:23:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NfiXel5hMxBC6ssdIj0jDQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
