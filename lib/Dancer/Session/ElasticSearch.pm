package Dancer::Session::ElasticSearch;

use strict;
use warnings;
use base 'Dancer::Session::Abstract';

use Dancer qw(:syntax);
use ElasticSearch;
use Try::Tiny;
use Digest::HMAC_SHA1 qw();

our $VERSION = 1.001;
our $es;

BEGIN {

    my $settings = setting('session_options');
    my $es = ElasticSearch->new( %{ $settings->{connection} } );

    my $index    = $settings->{index} // 'session';
    my $ttl      = $settings->{ttl} // "1d";

    unless ( $es->index_exists( index => $index ) ) {

        $es->create_index(
            index   => $index,
            mappings => {
                session   => {
                    "_all" => { "enabled" => 0 },
                    "_ttl" => { "enabled" => 1, "default" => $ttl },
                    enabled => 0,
                }
            }
        );

        info "Created $index ElasticSearch index";
    }
}

sub create {
    my $self = __PACKAGE__->new;

    my $data = {%$self};
    my $id = $self->_es->index( data => $data )->{_id};

    $self->id( $self->_sign($id) );

    return $self;
}

sub flush {
    my $self = shift;

    my $data = {%$self};
    try {
        my $id   = $self->_verify( $self->id );
        $self->_es->index( data => $data, id => $id,  );
    }
    catch {
        warning("Could not flush session ID ". $self->id . " - $_");
        return;
    };

    return $self;
}

sub retrieve {
    my ( $self, $session_id ) = @_;

    my $res = try {
        my $id = $self->_verify($session_id);
        my $get = $self->_es->get( id => $id, ignore_missing => 1 );
        return defined $get ? $get->{_source} : undef;
    }
    catch {
        warning("Could not retrieve session ID $session_id - $_");
        return;
    };

    $res->{id} = $session_id;

    return bless $res, __PACKAGE__ if $res;
}

sub destroy {
    my $self = shift;
    try {
        my $id = $self->_verify($self->id);
        $self->_es->delete( id => $id );
        $self->write_session_id(0);
        delete $self->{id};
    }
    catch {
        warning( "Could not delete session ID " . $self->id . " - $_" );
        return;
    };
}

sub init { }

sub _es {

    return $es if defined $es;

    my $settings = setting('session_options');

    $es = ElasticSearch->new( %{ $settings->{connection} } );
    $es->use_type( $settings->{type}   // 'session' );
    $es->use_index( $settings->{index} // 'session' );

    return $es;

}

sub _sign {
    my ( $self, $id ) = @_;

    my $settings = setting('session_options');
    my $length = $settings->{signing}{length} || 10;

    my $salt = join "",
        ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )
        [ map { rand 64 } ( 1 .. $length ) ];
    my $hash = $self->_hash( $id, $salt );

    return ( $hash . $salt . $id );
}

sub _verify {
    my ( $self, $string ) = @_;

    my $settings = setting('session_options');
    my $length = $settings->{signing}{length} || 10;

    my ( $hash, $salt, $id ) = unpack "A${length}A${length}A*", $string;

    return $hash eq $self->_hash( $id, $salt )
        ? $id
        : die "Session ID not verified";
}

sub _hash {
    my ( $self, $id, $salt ) = @_;
    my $settings = setting('session_options');
    my $secret   = $settings->{signing}{secret};
    my $length   = $settings->{signing}{length} || 10;

    return
        lc substr( Digest::HMAC_SHA1::hmac_sha1_hex( $id, $secret . $salt ),
        0, $length );
}

1;

__END__

=head1 NAME

Dancer::Session::ElasticSearch - L<ElasticSearch> based session engine for Dancer

=head1 SYNOPSIS

This module implements a session engine storing session variables in an
ElasticSearch index. It also signs IDs to thwart tampering and guessing, and
will automatically create the ES index if it doesn't exist yet.

=head1 USAGE

In config.yml

  session:       "ElasticSearch"
  session_options:
    connection:
                                    # passed directly to ElasticSearch
    index: "my_index"               # ES index to use. defaults to "session"
    type:  "my_session"             # defaults to "session"
    signing:
        secret: "ldjaldjaklsdanm.m" # required for signing IDs
        length: 10                  # length of salt and hash. defaults to 10
    ttl: 1d                         # used if we create the index. defaults 1d.

As this is ElasticSearch you can set a ttl on the documents when you create
your ES index and let it do the work for you. Or let this package create the
index and it will be set up with a default ttl for you.

=head1 METHODS

=head2 create()

Creates a new session. Returns the session object.

=head2 flush()

Write the session to ES. Returns the session object.

=head2 retrieve($id)

Look for a session with the given id.

Returns the session object if found, C<undef> if not.

=head2 destroy()

Remove the current session object from ES

=head1 INTERNAL METHODS

=head2 _es

Connect to ElasticSearch and returns a handle

=head2 init

Overload the init method in L<Dancer::Session::Abstract> to C<not> create an ID
as we will use the ElasticSearch ID instead.

=head2 _verify($string)

Verifies a signed ID

=head2 _sign($id)

Signs an ID

=head2 _hash($id, $salt)

Creates a hash from the $id, $salt and secret key as found in the config

=head1 FORK ME

Fork a copy for yourself from L<https://github.com/babf/Dancer-Session-ElasticSearch>

=head1 SEE ALSO

L<Dancer>, L<Dancer::Session>

=cut

