package Dancer::Session::ElasticSearch;

use strict;
use warnings;
use base 'Dancer::Session::Abstract';

use Dancer qw(:syntax);
use ElasticSearch;
use Try::Tiny;

our $VERSION = 0.006;

our $es;

sub create {
    my $self = __PACKAGE__->new;

    my $data = {%$self};
    my $id   = $self->_es->index( data => $data )->{_id};

    $self->id($id);

    return $self;
}

sub flush {
    my $self = shift;

    my $data = {%$self};

    $self->_es->index( data => $data, id => $self->id );
    return $self;
}

sub retrieve {
    my ( $self, $session_id ) = @_;

    my $res = try {
        my $get = $self->_es->get( id => $session_id, ignore_missing => 1 );
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
        $self->_es->delete( id => $self->id );
        $self->write_session_id(0);
        delete $self->{id};
    } catch {
        warning("Could not delete session ID " . $self->id . " - $_");
        return;
    };
}

sub init { }

sub _es {

    return $es if defined $es;

    my $settings = setting('session_options');

    $es = ElasticSearch->new( %{ $settings->{connection} } );
    $es->use_type( $settings->{type}  // 'session' );
    $es->use_index( $settings->{index} // 'session' );

    return $es;

}

1;

__END__

=head1 NAME

Dancer::Session::ElasticSearch - L<ElasticSearch> based session engine for Dancer

=head1 SYNOPSIS

This module implements a session engine storing session variables in an
ElasticSearch index.

=head1 USAGE

In config.yml

  session:       "ElasticSearch"
  session_options:
    connection:
    ... settings to pass to L<ElasticSearch>
    index: "my_index" # defaults to "session"
    type:  "my_session" # defaults to "session"

This session engine will not remove expired sessions on the server, but as it's
ElasticSearch you know when sessions were last updated from the document timestamp.

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

=head2 _es

Overload the init method in L<Dancer::Session::Abstract> to C<not> create an ID
as we will use the ElasticSearch ID instead.

=head1 FORK ME

Fork a copy for yourself from L<https://github.com/babf/Dancer-Session-ElasticSearch>

=head1 SEE ALSO

L<Dancer>, L<Dancer::Session>

=cut

