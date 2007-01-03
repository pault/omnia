package Everything::Node::Test::setting;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;


sub setup_imports {

    return ('Everything::XML');
}

sub test_imports :Test(startup => 1) {
    my ( $self) = @_;
    my $imports = $self->{imports};
    is_deeply(
        $$imports{'Everything::XML'},
        { genBasicTag => 1 },
        '...imports genBasicTag and parseBasicTag from Everything::XML'
    );
}


sub test_extends :Test( +1 )
{
	my $self   = shift;
	my $module = $self->node_class();
	ok( $module->isa( 'Everything::Node::node' ),
		'setting should extend node' );
	$self->SUPER();
}

sub test_dbtables :Test( 2 )
{
	my $self   = shift;
	my $module = $self->node_class();

	can_ok( $module, 'dbtables' );
	my @tables = $module->dbtables();
	is_deeply( \@tables, [qw( setting node )],
		'dbtables() should return node tables' );
}

sub test_get_vars :Test( 2 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( getHash => { foo => 'bar' } );

	is_deeply( $node->getVars($node), { foo => 'bar' },
		'getVars() should call getHash() on node' );

	is( ( $node->next_call() )[1]->[1], 'vars', '... with "vars" argument' );
}

sub test_set_vars :Test( 2 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_true( 'setHash' );
	$node->setVars( { my => 'vars' } );

	my ($method, $args) = $node->next_call();
	is( $method, 'setHash', 'setVars() should call setHash()' );
	is_deeply( $args->[1], { my => 'vars' }, '... with hash arguments' );
}

sub test_has_vars :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};
	ok( $node->hasVars(), 'hasVars() should return true' );
}

sub test_field_to_XML :Test( +5 )
{
	my $self = shift;
	my $node = $self->{node};

	$self->SUPER();

	local ( *XML::DOM::Element::new, *XML::DOM::Text::new,
		*Everything::Node::setting::genBasicTag, *fieldToXML );

	my @dom;
	*XML::DOM::Element::new = *XML::DOM::Text::new = sub {
		push @dom, shift;
		return $node;
	};

	my @tags;
	*Everything::Node::setting::genBasicTag = sub {
		push @tags, join( ' ', @_[ 1 .. 3 ] );
	};

	$node->set_always( getVars => { a => 1, b => 1, c => 1 } )
		 ->set_series( SUPER   => 2, 10 )
		  ->set_true( '-appendChild' );

	is( $node->fieldToXML( '', 'vars' ),
		$node, '... should return XML::DOM element for vars, if "vars" field' );
	is( @dom, 5, '... should make several DOM nodes:' );
	is( scalar grep( /Element/, @dom ), 1, '... one Element node' );
	is( scalar grep( /Text/,    @dom ), 4, '... and several Text nodes' );

	is( join( '!', @tags ), 'var a 1!var b 1!var c 1',
		'... should call genBasicTag() on each var pair' );
}

sub test_get_node_keep_keys :Test( +1 )
{
	my $self   = shift;
	my $node   = $self->{node};
	my $result = $node->getNodeKeepKeys();
	is( $result->{vars}, 1, '... and should set "vars" to true in results' );
	$self->SUPER();
}

sub test_update_from_import :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( -SUPER   => 10 )
	     ->set_series( -getVars => { a => 1, b => 2 }, $node )
		 ->set_true( 'setVars' );

	is( $node->updateFromImport( $node ), 10,
		'updateFromImport() should call SUPER()' );
	is( $node->next_call(), 'setVars', '... and should call setVars()' );
	is( join( '', @$node{ 'a', 'b' } ), '12',
		'... and merging keys from new node' );
}

1;
