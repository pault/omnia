
=head1 Everything::Node::htmlpage

Class representing the htmlpage node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::htmlpage;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

use MooseX::ClassAttribute;
class_has class_nodetype => (
    reader  => 'get_class_nodetype',
    writer  => 'set_class_nodetype',
    isa     => 'Everything::Node::nodetype',
    default => sub {
        Everything::Node::nodetype->new(
            Everything::NodetypeMetaData->default_data );
    }
);

extends 'Everything::Node::node';

has $_ => ( is => 'rw' )
  foreach
  qw/MIMEtype displaytype ownedby_theme page pagetype_nodetype parent_container permissionneeded/;

with 'Everything::Node::Parseable';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables {
    my $self = shift;
    return 'htmlpage', $self->SUPER::dbtables();
}

sub get_compilable_field {
    'page';
}

sub make_html {
    my ( $this, $request, $ehtml ) = @_;

    my $page = $this->run( { ehtml => $ehtml } );

    if ( $this->get_parent_container ) {
        my $container =
          $this->get_nodebase->getNode( $this->get_parent_container );
        $page =
          $container->process_contained_data( $request, $page, undef, $ehtml );
    }

    my $errors = '';
    if ( $request->get_user->isGod() ) {
        $errors = $ehtml->formatGodsBacksideErrors();
    }
    else {
        Everything::HTML::printBacksideToLogFile();
    }
    $page =~ s/<BacksideErrors>/$errors/;

    return $page;

}

1;
