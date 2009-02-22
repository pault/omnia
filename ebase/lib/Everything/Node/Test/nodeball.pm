package Everything::Node::Test::nodeball;

use strict;
use warnings;

use base 'Everything::Node::Test::nodegroup';

use Test::More;
use SUPER;

sub setup_imports {

    return ();
}

sub test_imports :Test(startup => 0) {
    return "Doesn't import symbols";
}

sub test_dbtables :Test( 2 )
{
	my $self   = shift;
	my $module = $self->node_class();
	can_ok( $module, 'dbtables' );
	my @tables = $module->dbtables();
	is_deeply( \@tables, [ 'setting', 'node' ],
		'dbtables() should return node tables' );
}

sub test_extends :Test( +1 )
{
	my $self   = shift;
	my $module = $self->node_class();
	ok( $module->isa( 'Everything::Node::nodegroup' ),
		"$module should extend Everything::Node::nodegroup" );
	$self->SUPER();
}

sub test_insert :Test( 10 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_true( 'setVars' )
	     ->set_series( super => 0, 1, 0 )
		 ->set_series( getVars => 1 );

	$node->{title} = 'title!';

	$db->set_series( getNode => '', $node );
	$self->{errors} = [];

	is( $node->insert( 'user' ), 0,
		'insert() should return 0 if SUPER() insert fails' );

	like( $self->{errors}[0][0], qr/bad insert id:/, '... logging error' );
	ok( exists $node->{vars}, '... vivifying node "vars" field' );

	is( $node->next_call(), 'getVars', '... and calling getVars() on node' );

	my ($method, $args) = $node->next_call();
	is( $method, 'super',   '... calling super method' );
	is( $args->[1], 'user', '... and passing user' );

	is( $node->insert( 2 ), 1, '... returning node_id if insert succeeds' );

	( $method, $args ) = $node->next_call(2);
	is( $method, 'setVars', '... calling setVars()' );
	is_deeply( $args->[1],
		{
			author      => 'ROOT',
			version     => '0.1.1',
			description => 'No description',
		}, '... with default vars' );

	$node->clear();
	$node->insert();

	( $method, $args ) = $node->next_call(2); diag $method;
	is( $args->[1]->{author}, 'title!',
		'... respecting given title when creating default vars' );
}

sub test_get_vars :Test( 2 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( getHash => 10 );

	is( $node->getVars(), 10, 'getVars() should call getHash()' );
	my ( $method, $args ) = $node->next_call();
	is( $args->[1], 'vars', '... with appropriate arguments' );
}

sub test_set_vars :Test( 2 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( setHash => 11 );

	is( $node->setVars( 12 ), 11, 'setVars() should call setHash()' );
	my ( $method, $args ) = $node->next_call();
	is( join( '-', @$args ), "$node-12-vars", '... with appropriate args' );
}

sub test_has_vars :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};

	ok( $node->hasVars(), 'hasVars() should return true' );
}

1;
