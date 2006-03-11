#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use TieOut;
use FakeNode;
use Test::More tests => 39;

$INC{'Everything/Security.pm'} = $INC{'Everything/Util.pm'} =
	$INC{'Everything/XML.pm'}  = $INC{'XML/DOM.pm'}         = 1;

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::Node::setting::$AUTOLOAD";

	if ( defined &{$sub} )
	{
		*{$AUTOLOAD} = \&{$sub};
		goto &{$sub};
	}
}

my @imports;
local (
	*Everything::Security::import, *Everything::Util::import,
	*Everything::XML::import,      *XML::DOM::import
);

*Everything::Security::import = *Everything::Util::import =
	*Everything::XML::import = *XML::DOM::import = sub {
	push @imports, scalar caller();
	};

use_ok('Everything::Node::setting') or exit;
is(
	scalar @imports,
	4,
'... and should use Everything::Security, Everything::Util, Everything::XML, and XML::DOM'
);

my $node = FakeNode->new();

# construct()
ok(
	Everything::Node::setting::construct($node),
	'construct() should return a true value'
);
is( $node->{_calls}[0][0], 'SUPER', '... and should call SUPER()' );

# destruct()
$node->{_subs}{SUPER} = [2];
is( Everything::Node::setting::destruct($node),
	2, 'destruct() should delegate to SUPER()' );

# getVars()
$node->{_subs}{getHash} = [3];
is( Everything::Node::setting::getVars($node),
	3, 'getVars() should call getHash() on node' );
is( $node->{_calls}[-1][1], 'vars', '... with "vars" argument' );

# setVars()
Everything::Node::setting::setVars( $node, 'set' );
is(
	join( ' ', @{ $node->{_calls}[-1] } ),
	'setHash set vars',
	'setVars() should call setHash() with appropriate arguments'
);

# hasVars()
ok( Everything::Node::setting::hasVars($node), 'hasVars() should return true' );

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

	$node->{_subs} = {
		getVars => [    { a => 1, b => 1, c => 1 } ],
		SUPER   => [ 2, 10 ],
	};

	is(
		fieldToXML( $node, '', '', '!' ),
		2,
		'fieldToXML() should delegate to SUPER() unless field param is "vars"'
	);

	$node->{_calls} = [];
	is( fieldToXML( $node, '', 'vars' ),
		$node, '... should return XML::DOM element for vars, if "vars" field' );
	is( scalar @dom, 5, '... should make several DOM nodes:' );
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

	$node->{_subs} = {
		SUPER       => [3],
		getTagName  => [ '', 'vars' ],
		getVars     => [ $node, $node, $node ],
		getNodeType => [ 1, 0, 0 ],
	};

	local *FakeNode::getChildNodes;
	*FakeNode::getChildNodes = sub {
		return ( $node, $node, $node );
	};

	my @types = ( { where => 'foo', name => 'foo' }, { name => 'bar' } );
	local *Everything::Node::setting::parseBasicTag;
	*Everything::Node::setting::parseBasicTag = sub {
		return shift @types;
	};

	is( Everything::Node::setting::xmlTag( $node, $node ),
		3, 'xmlTag() should delegate to SUPER() unless passed "vars" tag' );

	$node->{vars} = { foo => -1, bar => 1 };
	my $fixes = Everything::Node::setting::xmlTag( $node, $node );
	ok( exists $node->{vars},
		'... should vivify "vars" field in node when "vars" is requested' );
	is( @$fixes, 1, '... and return array ref of fixable nodes' );
	is( $node->{vars}{ $fixes->[0]{where} },
		-1, '... and should mark fixable nodes by name in "vars"' );
	is( $node->{vars}{bar}, 1, '... and keep tag value for fixed tags' );
	is(
		join( ' ', @{ $node->{_calls}[-1] } ),
		"setVars $node",
		'... and should call setVars() to keep them'
	);
}

# applyXMLFix()
{
	local ( *Everything::XML::patchXMLwhere, *Everything::logErrors );
	my $patch;
	*Everything::XML::patchXMLwhere = sub {
		$patch = shift;
		return { type_nodetype => 'nodetype' };
	};

	my @errors;
	*Everything::logErrors = sub {
		push @errors, join( ' ', @_ );
	};

	is( applyXMLFix($node), undef,
		'applyXMLFix() should return if called without a fix' );
	is( applyXMLFix( $node, 'bad' ), undef, '... or with a bad fix' );
	my $fix = {};
	foreach my $key (qw( fixBy field where ))
	{
		is( applyXMLFix( $node, $fix ), undef, "... or without a '$key' key" );
		$fix->{$key} = '';
	}
	is( applyXMLFix( $node, $fix ), undef, '... or unless fixing a setting' );
	is( $node->{_calls}[-1][0], 'SUPER', '... and delegate to SUPER() ' );

	$node->{_subs} = {
		getVars => [ $node, $node, $node ],
		getNode => [ 0, 0, { node_id => 888 } ],
	};
	$node->{DB} = $node;

	@$fix{ 'fixBy', 'where' } = ( 'setting', 'w' );
	isa_ok( applyXMLFix( $node, $fix ),
		'HASH', '... should return setting $FIX if it cannot be found' );
	is( $patch, 'w',
		'... should call patchXMLwhere() with "where" field of FIX' );

	$node->{title} = 'node title';
	$node->{nodetype}{title} = 'nodetype title';

	local *STDOUT;
	my $out = tie *STDOUT, 'TieOut';

	applyXMLFix(
		$node,
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

	is(
		applyXMLFix( $node, $fix ),
		undef,
		'applyXMLFix() should return undef if successfully called for setting'
	);
	is( $node->{foo}, 888, '... and set variable for field to node_id' );
	is(
		join( ' ', @{ $node->{_calls}[-1] } ),
		"setVars $node",
		'... and should call setVars() to save vars'
	);
}

# getNodeKeepKeys()
$node->{_subs}{SUPER} = [$node];
is( Everything::Node::setting::getNodeKeepKeys($node),
	$node, 'getNodeKeepKeys() should call SUPER()' );
is( $node->{vars}, 1, '... and should set "vars" to true in results' );

# updateFromImport()
$node->{_subs} = {
	SUPER   => [10],
	getVars => [ { a => 1, b => 2 }, $node ],
};
is( Everything::Node::setting::updateFromImport( $node, $node ),
	10, 'updateFromImport() should call SUPER()' );
is( $node->{_calls}[-2][0], 'setVars', '... and should call setVars()' );
is( join( '', @$node{ 'a', 'b' } ), '12', '... and merge keys from new node' );
