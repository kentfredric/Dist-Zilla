package Dist::Zilla::File::FromCode;
# ABSTRACT: a file whose content is (re-)built on demand
use Moose;
use Params::Util qw( _CODELIKE );
use Carp qw();
=head1 DESCRIPTION

This represents a file whose contents will be generated on demand from a
callback or method name.

It has one attribute, C<code>, which may be a method name (string) or a
coderef.  When the file's C<content> method is called, the code is used to
generate the content.  This content is I<not> cached.  It is recomputed every
time the content is requested.

=cut

has code => (
  is  => 'rw',
  isa => 'CodeRef|Str',
  required => 1,
);

sub content {
  my ($self) = @_;

  confess "cannot set content of a FromCode file" if @_ > 1;

  my $code = $self->code;
  return $self->$code;
}

sub munge {
  my ( $self, $munger ) = @_ ;
  Carp::croak('->munge( munger )  was not passed a coderef' ) unless _CODELIKE($munger);
  my $orig = $self->code;
  $self->code(sub {
    return $munger->( $self, $self->$orig );
  });
}

with 'Dist::Zilla::Role::File';
__PACKAGE__->meta->make_immutable;
no Moose;
1;
