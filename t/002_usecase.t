use Test::More tests => 5;

use strict;
use warnings;

use Dancer::Session::ElasticSearch;
use Dancer qw(:syntax :tests);

$\ = "\n";

# create a session
set session => 'ElasticSearch';

my $id = session->id;

session "foo" => "bar";

my $foo = session "foo";

is $foo, "bar", "Data added to session object";

session->flush;

is session->id, $id, "Session ID remains the same after flushing";

session->retrieve($id);

is session->id, $id, "Session ID remains the same after retrieval";

session->destroy;

my $foo2 = session "foo";

isnt $foo, $foo2, "After destruction, session vars are gone";

isnt session->id, $id, "After destruction, session ID is changed";

session->destroy;