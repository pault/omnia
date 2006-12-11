package Everything::Node::Test::nodeball;

use strict;
use warnings;

use base 'Everything::Node::Test::nodegroup';

use Test::More;


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
		"$module should extend nodegroup" );
	$self->SUPER();
}

sub test_insert :Test( 10 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_true( 'setVars' )
	     ->set_series( SUPER => 0, 1, 0 )
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
	is( $method, 'SUPER',   '... calling super method' );
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

	( $method, $args ) = $node->next_call(2);
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

sub test_field_to_XML :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};

	my @saveargs;
	local *Everything::Node::setting::fieldToXML;
	*Everything::Node::setting::fieldToXML = sub { @saveargs = @_ };

	my @args = ( 'doc', '', 1 );
	$node->set_always( SUPER => 4 );

	is( $node->fieldToXML(@args), 4,
		'fieldToXML() should call SUPER() unless handling a "vars" field' );

	my ($method, $args) = $node->next_call();
	is_deeply( $args, [ $node, @args ], '... passing all arguments' );

	$args[1] = 'vars';
	is( $node->fieldToXML( @args ), 4,
		'... delegating to setting nodetype if handling "vars" field' );
	is( "@saveargs", "$node @args", '... passing along its arguments' );
}

sub test_xml_tag :Test( 5 )
{
	my $self = shift;
	my $node = $self->{node};

	my @saveargs;
	local *Everything::Node::setting::xmlTag;
	*Everything::Node::setting::xmlTag = sub {
		@saveargs = @_;
	};

	$node->set_always( SUPER => 1 )
		 ->set_series( getTagName => 0, 'vars' );

	is( $node->xmlTag( $node ), 1,
		'xmlTag() should call SUPER() unless XMLifying a "vars" field' );

	# handle these out of order
	my $method        = $node->next_call();
	(undef, my $args) = $node->next_call();
	is( $args->[1], $node, '... passing tag' );

	is( $method, 'getTagName', '... calling getTagName() on tag' );

	is( $node->xmlTag( $node ), 2,
		'... delegating to settings node if passed "vars" field' );
	is( "$node $node", "@saveargs", '... passing node and tag' );
}

sub test_apply_xml_fix :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};

	my @saveargs;
	local *Everything::Node::setting::applyXMLFix;
	*Everything::Node::setting::applyXMLFix = sub { @saveargs = @_ };

	my $fix  = { fixBy => '' };
	my @args = ( $fix, 1 );

	$node->set_always( SUPER => 18 );

	is( $node->applyXMLFix( @args ), 18,
		'applyXMLFix() should call SUPER() unless fixing up "setting" node' );

	my ($method, $args) = $node->next_call();
	is_deeply( $args, [ $node, $fix, 1 ], '... passing args' );

	$fix->{fixBy} = 'setting';

	is( $node->applyXMLFix( @args ), 3,
		'... delegating to setting nodetype when fixing "setting" field' );
	is( "@saveargs", "$node @args", '... and should pass same arguments' );
}

1;
