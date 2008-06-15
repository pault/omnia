package Everything::Config::URL;

=cut

=head1 NAME

  Everything::Config::URL - a couple of methods to turn nodes into url locations and parse a location and turn it into a node.

=head1 SYNOPSIS


=cut



use strict;
use warnings;

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

These two arguments are combined into a code reference which is returned.

=cut


sub create_url_rule {
    my ( $self, $check_node_cb, $make_url_cb ) = @_;

    my $rule = sub {
		    return $make_url_cb->( @_ ) if $check_node_cb->( @_ );
		    return;
		    };
    return $rule;

}

=head2 C<< create_nodetype_rule >>

Creates a rule to test whether a node is of a certain type, if it is then applies the url creation subroutine supplied by the first argument.  The second argument is the type name.

Returns a subroutine reference.

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


1;
