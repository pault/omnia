#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use Test::More tests => 26;
use Test::MockObject;

# catch attempts to use these modules
use vars qw( @imported );

my ($method, $args, $result);
my $mock = Test::MockObject->new();

my $imported = sub { push @imported, scalar caller() };
foreach my $fake (qw( Everything Everything::Node::setting ))
{
	$mock->fake_module( $fake, import => $imported );
}

use_ok( 'Everything::Node::nodeball' ) or exit;
is( scalar grep('Everything::Node::nodeball', @imported), 2, 
	'nodeball package should use Everything and Everything::Node::setting' );

# insert()
{
	my ($error, $vars);

	local (*Everything::logErrors, *insert);

	*Everything::logErrors = sub { $error = shift };
	$mock->set_true( 'setVars' )
		 ->set_series( SUPER => 0, 1, 0 )
		 ->set_series( getNode => '',
				bless { title  => 'title' }, 'Everything::Node' )
		 ->set_series( getVars => 1 );

	*insert = \&Everything::Node::nodeball::insert;

	$mock->{DB} = $mock;

	is( insert($mock), 0, 'insert() should return 0 if SUPER() insert fails' );
	like( $error, qr/bad insert id:/, '... and should log error' );
	ok( exists $mock->{vars}, '... should vivify node "vars" field' );

	is( $mock->next_call(), 'getVars', '... and call getVars() on node');
	is( $mock->next_call(), 'SUPER', '... calling super method' );

	is( insert($mock, 2), 1, '... should return node_id if insert succeeds' );

	($method, $args) = $mock->next_call( 3 );
	is( $method, 'setVars', '... calling setVars()' );
	is_deeply( $args->[1], {
		author      => 'ROOT',
		version     => '0.1.1',
		description => 'No description',
	}, '... with default vars' );

	$mock->clear();

	insert($mock);
	($method, $args) = $mock->next_call( 3 );
	is( $args->[1]->{author}, 'title', 
		'... should respect given title when creating default vars' );
}

# getVars()
$mock->set_always( getHash =>  10 )
	 ->clear();

is( Everything::Node::nodeball::getVars($mock), 10,
	'getVars() should call getHash()' );
($method, $args) = $mock->next_call();
is( $args->[1], 'vars', '... with appropriate arguments' );

# setVars()
$mock->set_always( setHash => 11 );

is( Everything::Node::nodeball::setVars($mock, 12), 11,
	'setVars() should call setHash()' );
($method, $args) = $mock->next_call();
is( join('-', @$args), "$mock-12-vars", '... with appropriate arguments' );

# hasVars()
ok( Everything::Node::nodeball::hasVars(), 'hasVars() should return true' );

# fieldToXML()
{
	my @saveargs;
	local *Everything::Node::setting::fieldToXML;
	*Everything::Node::setting::fieldToXML = sub {
		@saveargs = @_;
	};

	my @args = ($mock, 'doc', '', 1);
	$mock->set_always( SUPER => 4 )
		 ->clear();

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

	$mock->set_always( SUPER => 1 )
		 ->set_series( getTagName => 0, 'vars' )
		 ->clear();

	is( Everything::Node::nodeball::xmlTag($mock, $mock), 1, 
		'xmlTag() should call SUPER() unless XMLifying a "vars" field' );
	is( $mock->next_call(), 'getTagName', '... calling getTagName() on tag' );
	
	is( scalar Everything::Node::nodeball::xmlTag($mock, $mock), 2,
		'... should delegate to settings node if passed "vars" field' ); 
	is( "$mock $mock", "@saveargs", '... passing node and tag' );
}

# applyXMLFix()
{
	my @saveargs;
	local *Everything::Node::setting::applyXMLFix;
	*Everything::Node::setting::applyXMLFix = sub {
		@saveargs = @_;
	};

	my $fix = { fixBy => '' };
	my @args = ($mock, $fix, 1);

	$mock->set_always( SUPER => 18 );

	is( Everything::Node::nodeball::applyXMLFix(@args), 18,
		'applyXMLFix() should call SUPER() unless fixing up "setting" field' );
	$fix->{fixBy} = 'setting';
	is( scalar Everything::Node::nodeball::applyXMLFix(@args), 3,
		'... should delegate to setting nodetype when fixing "setting" field' );
	is( "@args", "@saveargs", '... and should pass same arguments' );
}
