package Everything::HTTP::Response::Nodeball;

use Everything::Storage::Nodeball;
use Apache2::Const qw/FORBIDDEN OK/;
use File::Temp qw/ :seekable /;
use strict;

use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
    qw/request headers/);
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->init(@_);
}

sub init {
    my ( $self, $args ) = @_;
    $self->set_request( $args->{ request } );
    $self->authorise;
    $self->{ headers } = {};
    return $self;
}

sub authorise {
    my $self = shift;
    my $e = $self->get_request;
    my $user = $e->get_user;
    my $node = $e->get_node;
    return $self->allowed( 1 ) if $node->hasAccess( $user, 'r' );
    return $self->allowed( undef );

}

sub content {

    my $self = shift;
    return unless $self->allowed;
    my $e = $self->get_request;
    my $nb = $e->get_nodebase;
    my $node = $e->get_node;
    my $file = File::Temp->new;

    my $ball_title = $node->get_title;

    my $storage = Everything::Storage::Nodeball->new ( nodebase => $nb );

    $storage->cleanup( 1 );
    $storage->export_nodeball_to_file( $ball_title, "$file" );

    $ball_title =~ s/[^\w\.\-]/-/g;
    $self->add_header( 'Content-Disposition', "attachment; filename=" . $ball_title . '.nbz' );

    $file->seek( SEEK_SET, 0 );
    local $/;
    return <$file>;
}

sub headers {

 return %{ $_[0]->get_headers };

}

sub content_type {

'application/x-gzip';

}

sub status_code {
    my $self = shift;
    return OK if $self->allowed;
    return FORBIDDEN;

}

sub allowed {

    my $self = shift;

    if ( ! @_ ) {
	return $self->{allowed};
    } else {
	return $self->{allowed} = $_[0];
    }

}

=head2 add_header

Adds a header to the headers attribute.  Takes two arguments. The first is the name of the header, the second is the header value.

=cut

sub add_header {
    my ( $self, $key, $value ) =@_;
    $self->get_headers->{ $key } = $value;

}

1;
