#!/usr/bin/perl -w

use strict;
use warnings;

use vars '$AUTOLOAD';

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use Test::More tests => 45;

use TieOut;
use Test::MockObject::Extends;

my $module = 'Everything::Node::setting';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::node' ), 'setting should extend node' );

can_ok( $module, 'dbtables' );
my @tables = $module->dbtables();
is_deeply( \@tables, [qw( setting node )],
	'dbtables() should return node tables' );

for my $class (
	qw( Everything::Security Everything::Util Everything::XML XML::DOM )
) {
	(my $path = $class) =~ s{::}{/}g;
	ok( $INC{ $path . '.pm' }, "$module should load $class" );
}

my $node = Test::MockObject::Extends->new( 'Everything::Node::setting' );

# construct()
ok( $node->construct(), 'construct() should return a true value' );

# destruct()
is( $node->destruct(), 1, 'destruct() should delegate to SUPER()' );

# getVars()
$node->set_always( getHash => { foo => 'bar' } );
is_deeply( $node->getVars($node),
	{ foo => 'bar' }, 'getVars() should call getHash() on node' );
is( ( $node->next_call() )[1]->[1], 'vars', '... with "vars" argument' );

$node->set_true( 'setHash' );
# setVars()
$node->setVars( { my => 'vars' } );
my ($method, $args) = $node->next_call();
is( $method, 'setHash', 'setVars() should call setHash()' );
is_deeply( $args->[1], { my => 'vars' }, '... with hash arguments' );

# hasVars()
ok( $node->hasVars(), 'hasVars() should return true' );


# fieldToXML()
{
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

	*fieldToXML = \&Everything::Node::setting::fieldToXML;

	$node->set_always( getVars => { a => 1, b => 1, c => 1 } )
		 ->set_series( SUPER   => 2, 10 )
		  ->set_true( '-appendChild' );

	is(
		$node->fieldToXML( '', '', '!' ),
		2,
		'fieldToXML() should delegate to SUPER() unless field param is "vars"'
	);

	$node->clear();
	is( $node->fieldToXML( '', 'vars' ),
		$node, '... should return XML::DOM element for vars, if "vars" field' );
	is( @dom, 5, '... should make several DOM nodes:' );
	is( scalar grep( /Element/, @dom ), 1, '... one Element node' );
	is( scalar grep( /Text/,    @dom ), 4, '... and several Text nodes' );

	is(
		join( '!', @tags ),
		'var a 1!var b 1!var c 1',
		'... should call genBasicTag() on each var pair'
	);

	# could check $indent and $indentchild
}
# xmlTag()
{
	local *XML::DOM::TEXT_NODE;
	*XML::DOM::TEXT_NODE = sub () { 1 };

	$node->set_always( -SUPER         => 3 );
	$node->set_series( -getTagName    => '', 'vars' );
	$node->set_series( -getVars       => ($node) x 3 );
	$node->set_series( -getChildNodes => ($node) x 3 );
	$node->set_series( getNodeType   => 1, 0, 0 );
	$node->set_true( 'setVars' );
	$node->clear();

	my @types = ( { where => 'foo', name => 'foo' }, { name => 'bar' } );
	local *Everything::Node::setting::parseBasicTag;
	*Everything::Node::setting::parseBasicTag = sub {
		return shift @types;
	};

	is( $node->xmlTag( $node ), 3,
		'xmlTag() should delegate to SUPER() unless passed "vars" tag' );

	$node->{vars} = { foo => -1, bar => 1 };
	my $fixes = Everything::Node::setting::xmlTag( $node, $node );
	ok( exists $node->{vars},
		'... should vivify "vars" field in node when "vars" is requested' );
	is( @$fixes, 1, '... and return array ref of fixable nodes' );
	is( $node->{vars}{ $fixes->[0]{where} },
		-1, '... and should mark fixable nodes by name in "vars"' );
	is( $node->{vars}{bar}, 1, '... and keep tag value for fixed tags' );
	my ($method, $args) = $node->next_call( 2 );
	is( join( ' ', $method, $args->[1] ), "setVars $node",
		'... and should call setVars() to keep them' );
}

# applyXMLFix()
{
	local ( *Everything::XML::patchXMLwhere, *Everything::logErrors );
	my $patch;
	*Everything::XML::patchXMLwhere = sub
	{
		$patch = shift;
		return { type_nodetype => 'nodetype' };
	};

	my @errors;
	*Everything::logErrors = sub
	{
		push @errors, join( ' ', @_ );
	};

	is( $node->applyXMLFix(), undef,
		'applyXMLFix() should return if called without a fix' );
	is( $node->applyXMLFix( 'bad' ), undef, '... or with a bad fix' );
	my $fix = {};
	foreach my $key (qw( fixBy field where ))
	{
		is( $node->applyXMLFix( $fix ), undef, "... or without a '$key' key" );
		$fix->{$key} = '';
	}

	$node->set_always( 'SUPER', 'duper' );
	is( $node->applyXMLFix( $fix ), 'duper', '... or unless fixing a setting' );
	is( $node->next_call(), 'SUPER',         '... and delegate to SUPER() ' );

	$node->set_series( getVars => ( $node ) x 3 );
	$node->set_series( getNode => 0, 0, { node_id => 888 } );
	$node->{DB} = $node;

	@$fix{ 'fixBy', 'where' } = ( 'setting', 'w' );
	isa_ok( $node->applyXMLFix( $fix ),
		'HASH', '... should return setting $FIX if it cannot be found' );
	is( $patch, 'w',
		'... should call patchXMLwhere() with "where" field of FIX' );

	$node->{title} = 'node title';
	$node->{nodetype}{title} = 'nodetype title';

	local *STDOUT;
	my $out = tie *STDOUT, 'TieOut';

	$node->applyXMLFix(
		{
			field         => 'field',
			fixBy         => 'setting',
			title         => 'title',
			type_nodetype => 'type',
			where         => 1,
		},
		1
	);

	like(
		$errors[0],
		qr/Unable to find 'title'.+'type'.+field/s,
		'... should print error if node is not found and printError is true'
	);

	$node->{node_id} = 0;
	$fix->{field}    = 'foo';

	$node->clear();
	is( $node->applyXMLFix( $fix ), undef,
		'applyXMLFix() should return undef if successfully called for setting'
	);
	is( $node->{foo}, 888, '... and set variable for field to node_id' );
	my ($method, $args) = $node->next_call( 3 );
	is( join( ' ', $method, $args->[1] ), "setVars $node",
		'... and should call setVars() to save vars'
	);
}

# getNodeKeepKeys()
$node->set_always( SUPER => $node );
is( $node->getNodeKeepKeys(), $node, 'getNodeKeepKeys() should call SUPER()' );
is( $node->{vars}, 1, '... and should set "vars" to true in results' );

# updateFromImport()
$node->set_always( -SUPER   => 10 );
$node->set_series( -getVars => { a => 1, b => 2 }, $node );
$node->clear();
is( $node->updateFromImport( $node ),
	10, 'updateFromImport() should call SUPER()' );
is( $node->next_call(), 'setVars', '... and should call setVars()' );
is( join( '', @$node{ 'a', 'b' } ), '12', '... and merge keys from new node' );
