package Everything::Template::Plugin::Code;

use Carp;
use Scalar::Util qw/blessed/;
use base qw/Template::Plugin/;
use strict;
use warnings;

sub new {

    my ( $class, $context ) = @_;

    my $ehtml = $context->{STASH}->{ehtml};
    croak "The variable 'ehtml' needs to be an Everything::HTML object but it's a " . blessed( $ehtml ) unless $ehtml->isa('Everything::HTML');

    return sub {
	my $code_name = shift;
	my $code_node = $ehtml->get_nodebase->getNode( $code_name );
	croak "No such node '$code_name'" unless $code_node;

	return $code_node->run( { ehtml => $ehtml } );

    };


}

1;
