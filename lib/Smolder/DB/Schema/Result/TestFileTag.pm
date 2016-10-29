use utf8;
package Smolder::DB::Schema::Result::TestFileTag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Smolder::DB::Schema::Result::TestFileTag

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<test_file_tag>

=cut

__PACKAGE__->table("test_file_tag");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 test_file

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 tag

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "test_file",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tag",
  { data_type => "text", default_value => "", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 test_file

Type: belongs_to

Related object: L<Smolder::DB::Schema::Result::TestFile>

=cut

__PACKAGE__->belongs_to(
  "test_file",
  "Smolder::DB::Schema::Result::TestFile",
  { id => "test_file" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2016-10-24 15:51:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9hnzolKriFlGpfHwRfpyLw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
