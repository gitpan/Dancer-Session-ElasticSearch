package Dancer::Session::ElasticSearch;

use strict;
use warnings;
use base 'Dancer::Session::Abstract';

use Dancer qw(:syntax);
use ElasticSearch;
use Try::Tiny;

our $VERSION = 0.001;

our $es;

sub create {
    my $self = __PACKAGE__->new;

    $self->flush;

    return $self;
}

sub flush {
    my $self = shift;
    my $data = {%$self};
    my $id   = $data->{id};

    $self->_es->index( data => $data, id => $id );
    return $self;
}

sub retrieve {
    my ( $self, $session_id ) = @_;

    my $res = try {
        $self->_es->get( id => $session_id )->{_source};
    }
    catch {
        warning("Could not retrieve session ID $session_id - $_");
        return;
    };

    return bless $res, __PACKAGE__ if $res;
}

sub destroy {
    my $self = shift;
    try {
        $self->_es->delete( id => $self->id );
    } catch {
        warning("Could not delete session ID " . $self->id . " - $_");
        return;
    };
}

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

Dancer::Session::ElasticSearch - ElasticSearch based session engine for Dancer

=head1 SYNOPSIS

This module implements a session engine storing session variables in an
ElasticSearch index.

=head1 USAGE

In config.yml

  session:       "ElasticSearch"
  session_index: "session" # defaults to "session"

This session engine will not automagically remove expired sessions on the
server, but as it's ElasticSearch you know when sessions were last updated
from the in-built timestamp on documents.

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

=head1 SEE ALSO

L<Dancer>, L<Dancer::Session>, L<Plack::Session::Store::DBI>

=cut

