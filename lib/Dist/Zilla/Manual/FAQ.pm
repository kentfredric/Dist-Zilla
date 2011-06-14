use strict;
use warnings;

package Dist::Zilla::Manual::FAQ;

# ABSTRACT: Frequently asked questions about Dist::Zilla

=head2 "authordeps" doesn't report "foomodule"

=head3 Problem

You'll possibly occasionally hit a problem where you do

  dzil authordeps | cpanm -
  dzil build

and have it not work.

This is because the current approach to authordeps is rather simplistic.

All it currently does is parses C<dist.ini> and reports which listed plugins
cannot be loaded.

This of course falls short when plugins are in weaver.ini or loaded in some
other way ( ie: A Bundle ).

=head3 Solution

At present, the best you can do to solve the problem is as follows

  name = Some-Module
  ; authordep foo

which will then make C<"foo"> get reported amongst the result of
C<dzil authordeps> ( as documented in L<Dist::Zilla::App::Command::authordeps> ),
and at least that way, you're unlikely to bump into this problem too often.

=head3 Future Approaches

Many would like a more intuitive interface, but no way has been found by which
it can be done sanely. So we're open to ideas that work well.

=head4 A Method on A Role.

The most logical approach that first comes to mind is creating a role, say
C<AuthorDepProvider> which requires a method, say, C<authordeps>, with the idea
being Plugins like PodWeaver can provide this method, and then delegate the
resolution themselves.

However, this poses one very obvious problem, which some think is worse than the
situation already is.

  dzil authordeps
  # -> PodWeaver
  cpanm PodWeaver
  dzil authordeps
  # -> MorePlugins
  # -> MorePluginsB
  cpanm MorePlugins MorePluginsB
  dzil authordeps
  # -> EvenMorePlugins
  # -> FFFFFFFFFFFFFFF

And Ideally, we want to only run C<authordeps> once, and know that its output
won't magically be different next time we run it, so we're doing

  dzil authordeps | cpanm -

and not

  while(defined( my @items = qx/dzil authordeps/ )) {
    system('cpanm', @items);
  }

Which in the worst case scenario, might never terminate. ( it most likely will
of course, just this is a bit of pessimism and general implementation horror )

The next obvious approach is to create a C<--install> option, but thats a whole
new can of worms.

Something like:

  dzil authordeps --install=cpanm

Which might use something like:

  Dist::Zilla::Installer::cpanm

Which may be viable in future, but we don't have all the bits underneath that would
make that work yet, or know exactly the right way we'd do it.

All things considered, its a lot of work on L<Dist::Zilla>'s behalf for a
reasonably simple problem.

=cut

1;
