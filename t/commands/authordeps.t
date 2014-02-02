use strict;
use warnings;
use Test::More 0.88 tests => 1;

use lib 't/lib';

use autodie;

use Dist::Zilla::Util::AuthorDeps;
use Dist::Zilla::Path;

my $authordeps =
    Dist::Zilla::Util::AuthorDeps::extract_author_deps(
	path('corpus/dist/AutoPrereqs'),
	0
    );

is_deeply(
    $authordeps,
    [ map { +{"Dist::Zilla::Plugin::$_" => 0} } qw<AutoPrereqs Encoding ExecDir GatherDir MetaYAML> ],
    "authordeps in corpus/dist/AutoPrereqs"
) or diag explain $authordeps;

done_testing;
