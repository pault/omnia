#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 25;

# catch attempts to use these modules
use vars qw( @imported );

$INC{'Everything.pm'} = $INC{'Everything/Node/setting.pm'} = 1;
local (*Everything::import, *Everything::Node::setting::import);
*Everything::import = *Everything::Node::setting::import = sub { 
	push @imported, scalar caller();
};

use_ok( 'Everything::Node::nodeball' );
is( scalar grep('Everything::Node::nodeball', @imported), 2, 
	'nodeball package should use Everything and Everything::Node::setting' );

my $node = FakeNode->new();

# insert()
{
	my ($error, $vars);

	local (*Everything::Node::nodeball::logError, *FakeNode::setVars, *insert);
	*Everything::Node::nodeball::logError = sub {
		$error = shift;
	};

	*FakeNode::setVars = sub {
		$vars = $_[1];
	};

	*insert = \&Everything::Node::nodeball::insert;

	$node->{_subs} = {
		SUPER		=> [ 0, 1, 0 ],
		getNode		=> [ '', { title => 'title' } ],
		getVars		=> [ 1, undef, undef ],
	};

	$node->{DB} = $node;

	is( insert($node), 0, 'insert() should return 0 if SUPER() insert fails' );
	like( $error, qr/bad insert id:/, '... and should log error' );
	ok( exists $node->{vars}, '... should vivify node "vars" field' );
	is( $node->{_calls}[0][0], 'getVars', '... and call getVars() on node');

	is( insert($node, 2), 1, '... should return node_id if insert succeeds' );

	isa_ok( $vars, 'HASH', '... should call setVars() with default vars' );
	is( join(' ', @$vars{qw( author version description )}), 
		'ROOT 0.1.1 No description',
		'... should set default values for vars' );
	insert($node);
	is( $vars->{author}, 'title', 
		'... should respect given title when creating default vars' );
}

# getVars()
$node->{_subs}{getHash} = [ 10 ];
is( Everything::Node::nodeball::getVars($node), 10,
	'getVars() should call getHash()' );
is( join(' ', @{ pop @{ $node->{_calls} } }), 'getHash vars',
	'... with appropriate arguments' );

# setVars()
$node->{_subs}{setHash} = [ 11 ];
is( Everything::Node::nodeball::setVars($node, 12), 11,
	'setVars() should call setHash()' );
is( join(' ', @{ pop @{ $node->{_calls} } }), 'setHash 12 vars',
	'... with appropriate arguments' );

# call setHash with second arg and 'vars' on first arg

# hasVars()
ok( Everything::Node::nodeball::hasVars(), 'hasVars() should return true' );

# fieldToXML()
{
	my @saveargs;
	local *Everything::Node::setting::fieldToXML;
	*Everything::Node::setting::fieldToXML = sub {
		@saveargs = @_;
	};

	my @args = ($node, 'doc', '', 1);
	$node->{_subs}{SUPER} = [ 4 ];
	is( Everything::Node::nodeball::fieldToXML(@args), 4,
		'fieldToXML() should call SUPER() unless handling a "vars" field' );
	
	$args[2] = 'vars';
	is( scalar Everything::Node::nodeball::fieldToXML(@args), 4, 
		'... should delegate to setting nodetype if handling "vars" field' );
	is( "@saveargs", "@args", '... passing along its arguments' );
}

# xmlTag()
{
	my @saveargs;
	local *Everything::Node::setting::xmlTag;
	*Everything::Node::setting::xmlTag = sub {
		@saveargs = @_;
	};

	$node->{_subs} = {
		SUPER		=> [ 1 ],
		getTagName	=> [ 0, 'vars' ],
	};

	$node->{_calls} = [];

	is( Everything::Node::nodeball::xmlTag($node, $node), 1, 
		'xmlTag() should call SUPER() unless XMLifying a "vars" field' );
	is( $node->{_calls}[0][0], 'getTagName', 
		'... should call getTagName() on tag' );
	
	is( scalar Everything::Node::nodeball::xmlTag($node, $node), 2,
		'... should delegate to settings node if passed "vars" field' ); 
	is( "$node $node", "@saveargs", '... passing node and tag' );
}

# applyXMLFix()
{
	my @saveargs;
	local *Everything::Node::setting::applyXMLFix;
	*Everything::Node::setting::applyXMLFix = sub {
		@saveargs = @_;
	};

	my $fix = { fixBy => '' };
	my @args = ($node, $fix, 1);
	$node->{_subs}{SUPER} = [ 18 ];
	is( Everything::Node::nodeball::applyXMLFix(@args), 18,
		'applyXMLFix() should call SUPER() unless fixing up "setting" field' );
	$fix->{fixBy} = 'setting';
	is( scalar Everything::Node::nodeball::applyXMLFix(@args), 3,
		'... should delegate to setting nodetype when fixing "setting" field' );
	is( "@args", "@saveargs", '... and should pass same arguments' );
}
