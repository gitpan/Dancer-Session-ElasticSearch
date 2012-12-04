use Test::More;

use strict;
use warnings;

use Dancer qw(:syntax :tests);
use Dancer::Session::ElasticSearch;
use ElasticSearch::TestServer;

my $es;

setup_server();

set 'session_options' => {
    signing => {
        secret => "lkjadslaj!ljasxmHasjaojsxm!!'",
        length => 12
    }
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

sub setup_server {
    
    eval {
        if ( $ENV{ES} )
        {
            $es = ElasticSearch->new( servers => $ENV{ES} );
            $es->current_server_version;
        }
        elsif ( $ENV{ES_HOME} ) {
            $es = ElasticSearch::TestServer->new(
                instances => 1,
                home      => $ENV{ES_HOME},
                transport => 'http'
            );
        }
        else {
            $es = ElasticSearch::TestServer->new();
        }
    
        1;
    } or do { diag $_ for split /\n/, $@; undef $es };
 
    if ($es) {
        
        my $temp_index = 'test_session.' . time;
    	
        $es->create_index( index => $temp_index );    
        $es->use_index($temp_index);
        $es->use_type('session');
        wait_for_es(1);
        $Dancer::Session::ElasticSearch::es = $Dancer::Session::ElasticSearch::es = $es;
        return;
    }

    plan skip_all => "No Elasticsearch test server available";

}

sub wait_for_es {
    $es->cluster_health( wait_for_status => 'yellow' );
    $es->refresh_index;
    sleep $_[0] if $_[0];
}
