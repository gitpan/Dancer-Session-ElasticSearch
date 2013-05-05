use Test::More;

use strict;
use warnings;

use Dancer qw(:syntax :tests);
use Dancer::Session::ElasticSearch;
use ElasticSearch::TestServer;

our $es;

{
    $ENV{ES_HOME}      ||= '/usr/share/elasticsearch/';
    $ENV{ES_PORT}      ||= '9400';
    $ENV{ES_INSTANCES} ||= 1;
    $ENV{ES_IP}        ||= '127.0.0.1';
    eval { $es = ElasticSearch::TestServer->new(
                        ip        => $ENV{ES_IP},
                        home      => $ENV{ES_HOME},
                        port      => $ENV{ES_PORT},
                        instances => $ENV{ES_INSTANCES},
                 )
    };

    if ( $es ) {
        $es->use_index('session');
        $es->use_type('session');
        $Dancer::Session::ElasticSearch::es = $es;
    }
    else {
        BAIL_OUT 'No ElasticSearch test server available ' . $@;
    }
}

set 'session_options' => {
    signing => {
        secret => "lkjadslaj!ljasxmHasjaojsxm!!'",
        length => 12
    },
    fast => 1,
};

# create a session
my $session = Dancer::Session::ElasticSearch->create;

isa_ok $session, "Dancer::Session::ElasticSearch";

my $id = $session->id;

$session->flush;

is $session->id, $id, "Session ID remains the same after flushing";

$session->retrieve($id);

is $session->id, $id, "Session ID remains the same after retrieval";

my $session2 = $session->retrieve("NOTASESSIONID");

isnt $session2, "Dancer::Session::ElasticSearch", "Retrieving with an invalid session ID errors";

$session->destroy;

done_testing();