package Everything::HTTP::URL;

=cut

=head1 NAME

  Everything::HTTP::URL - process requested urls and turn nodes into urls.

=head1 SYNOPSIS

  
    Everything::HTTP::URL->register_request_modifier(
			    sub { my ( $url, $e ) = @_;
				  return unless $url eq '/location/';
				  my $node = $e->get_nodebase->getNode( 0 );
				  $e->set_node ($node);
				  return 1;

});

    Everything::HTTP::URL->create_url_rule(
		             sub { my $node = shift;
				   return 1 if $node->get_title eq '/';
				   return
                                 },
			     sub { '/location/' }
					  );

Everything::HTTP::URL->set_default_sub( \&Everything::HTML::linkNode );


The apache handler:

sub handler {

    my $r = shift; # grab the request object;

    my $e = Evertyhing::HTTP::Request->( ...with options....);

    Everything::HTTP::URL->modify_request( $r->path_info, $e );

   *Everything::HTML::linkNode = Everything::HTTP::URL->create_linknode;


}

=head1 DESCRIPTION

As you will have noticed all the methods are class methods.  This is because all the variables are class variables and they can be modified in httpd.conf or anywhere. It is also because this class is designed to be subclassed, but also to be able to srote all the url parsers and node to url modifiers in the same place.

=cut



use strict;
use warnings;


our @node_to_url_subs = ();
our @request_modifiers      = ();
our $default_sub;

sub new {
    my ( $class, $args ) = @_;
    my $self = bless {}, $class;
    foreach ( keys %$args ) {
        $self->{$_} = $args->{$_};
    }
    return $self;

}

=head2 C<< create_url_rule >>

Creates a rule for node to url subs.

Takes two arguments.

The first argument is a call back to check whether this rule applies
to this node. The call back is passed the node as an argument and should
return true if this rule applies to the node or false otherwise.

The second argument is a call back that turns a node into a url. It is passed the node as an argument and returns a string which is the path to url.

These two arguments are combined into a code reference which is added to the node_to_url_subs attribute and returned.

=cut


sub create_url_rule {
    my ( $self, $check_node_cb, $make_url_cb ) = @_;

    my $rule = sub {
		    return $make_url_cb->( @_ ) if $check_node_cb->( @_ );
		    return;
		    };
    push @node_to_url_subs, $rule;
    return $rule;

}

=head2 C<< create_nodetype_rule >>

Creates a rule to test whether a node is of a certain type, if it is then applies the url creation subroutine supplied by the first argument.  The second argument is the type name.

Returns a subroutine reference and pushes it onto the class list of subroutine references that can be retrieved by get_node_to_url_subs.

=cut


sub create_nodetype_rule {
    my ( $self, $sub, $typename ) = @_;
    my $select_node = sub {
        my $node = shift;
	my $flag;
        eval { $flag++ if $node->isa( 'Everything::Node::' . $typename ) };
	warn $@ if $@;
	return $flag;
    };
    return $self->create_url_rule( $select_node, $sub );
}


=head2 C<< create_linknode >>

Concantenates all the subroutines stored in node_to_url_subs adds the default_sub to the end and returns a code ref.  This is supposed to be a replacement for Everything::HTML::linkNode;

=cut

sub create_linknode {
    my ($self) = @_;
    my @subs = @node_to_url_subs;
    push @subs, $self->get_default_sub if $self->get_default_sub;
    my $linknode = sub {
        foreach (@subs) {
            my $rv = $_->(@_);
            return $rv if $rv;
        }

      }

}

=cut

=head2 C<< modify_request >>

Goes throught the parsers one by one in order and modifies the request object. Stops once a parser returns a true value.  If a parser returns a false value keeps going.

Takes two argumnets.  The first is the url being request, the second is a Everything::HTTP::Request object.

Returns a true value if at least one of the request modifiers was successful.

=cut

sub modify_request {
    my ( $self, $url, $e ) = @_;

    return unless $self->isset_request_modifiers;

    my $found = 0;

    foreach ( @request_modifiers ) {
	$found++  if $_->( $url, $e );
	last if $found;
    }

    return $found if $found;
    return;
}

sub set_default_sub {

    $default_sub = $_[1];

}

sub get_default_sub {

    $default_sub;

}

sub get_node_to_url_subs {

    @node_to_url_subs;
}

sub clear_node_to_url_subs {

    @node_to_url_subs = ();
}

sub get_node_to_url_subs_ref {

    \@node_to_url_subs;
}

sub set_node_to_url_subs {

    shift;
    @node_to_url_subs = @_;
}

=cut

=head2 C<< register_request_modifier >>

Pushs the argument, which must be subroutine reference onto the request_modifiers array.

  The subroutine/argument is passed two arguments, the first is a path from a url the second is a Everything::HTTP::Request instance.

  Should return true if it wants to be the last subroutine run.

=cut


sub register_request_modifier {

    push @request_modifiers, $_[1];

}

sub isset_request_modifiers {

    return 1 if @request_modifiers;
    return;

}

sub get_request_modifiers {

    @request_modifiers;
}

sub clear_request_modifiers {

    @request_modifiers = ();
}

1;
