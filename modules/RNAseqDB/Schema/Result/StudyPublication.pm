use utf8;
package RNAseqDB::Schema::Result::StudyPublication;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RNAseqDB::Schema::Result::StudyPublication

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
  is_nullable: 0

=head2 publication_id

  data_type: 'integer'
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
  { data_type => "integer", is_nullable => 0 },
  "publication_id",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</study_pub_id>

=back

=cut

__PACKAGE__->set_primary_key("study_pub_id");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-02-26 16:36:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:M4Nqh9FVhq9nx4tRoTEmmg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
