=head1 Everything::Node::container

Class representing the container node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::container;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends  'Everything::Node::Parseable', 'Everything::Node::node';

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype' );

has context => ( is => 'rw' );
has parent_container => ( is => 'rw' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'container', $self->SUPER::dbtables();
}

sub get_compilable_field {
    'context';
}


sub process_contained_data {
    my ( $self, $request, $data, $no_clear, $ehtml, $container_args ) = @_;
    my $html = $self->generate_container( $no_clear, $request, $ehtml, $container_args );
    $html =~ s/CONTAINED_STUFF/$data/s;
    return $html;
}

my %container_trap = ();

sub generate_container {
    my ( $self, $noClear, $request, $ehtml, $container_args ) = @_;
    my $nodebase = $self->get_nodebase;
    my $cgi      = $request->get_cgi;
    my $user     = $request->get_user;

    my $replacetext;
    my $containers;

    %container_trap = () unless $noClear;

    if ( exists $container_trap{ $self->get_node_id } ) {
        my @container_ids = keys %container_trap;
        die "Infinite recursion on containers @container_ids";
    }

    # Mark this container as being "visted";
    $container_trap{ $self->get_node_id }++;

    $replacetext = $self->run( { ehtml => $ehtml, args => $container_args } );

    $containers = $cgi->param('containers') || '';

    # SECURITY!  Right now, only gods can see the containers.  When we get
    # a full featured security model in place, this will change...
    if ( $user->isGod() && ( $containers eq "show" ) ) {
        $replacetext = $self->show_containers( $replacetext, $request, $ehtml );
    }

     if ( $self->get_parent_container ) {

         my $parentcontainer = $nodebase->getNode( $self->get_parent_container );
         $replacetext =
           $parentcontainer->process_contained_data( $request, $replacetext, 1, $ehtml );

     }

    return $replacetext;
}

sub show_containers {
    my ( $self, $replacetext, $request, $ehtml ) = @_;
    my $start          = "";
    my $middle         = $replacetext;
    my $end            = "";
    my $debugcontainer =
      $self->get_nodebase->getNode( 'show container', 'container' );

    # If this container contains the body tag, we do not
    # want to wrap the entire thing in the debugcontainer.
    # Rather, we want to wrap the contents inside the body
    # tag.  If we don't do this, we end up wrapping the
    # <head> and <body> in a table, which makes the page
    # not display right.
    if ( $replacetext =~ /<body/i ) {
        $replacetext =~ /(.*<body.*>)(.*)(<\/body>.*)/is;
        $start  = $1;
        $middle = $2;
        $end    = $3;
    }

    if ( $debugcontainer
        && ( $debugcontainer->get_node_id ne $self->get_node_id ) )
    {


        my $debugtext = $debugcontainer->process_contained_data( $request, $middle, undef, $ehtml, [ $self ] );
        $replacetext = $start . $debugtext . $end;
    }

    return $replacetext;
}
1;
