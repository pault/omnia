#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', '..', 'lib/';
}

BEGIN {
	package Everything;
	use subs qw( localtime caller );
	package main;
	require 'lib/FakeNodeBase.pm';
	$INC{'Everything/NodeBase.pm'} = 1;
}

use TieOut;
use FakeDBI;
use Test::More tests => 63;
use_ok( 'Everything' );

foreach my $sub ( qw( 
	getNode getNodeById getType getNodeWhere selectNodeWhere getRef getId )) {
	can_ok('main', $sub);
}

{
	local *STDERR;
	my $out = tie *STDERR, 'TieOut';
	printErr('error message');
	is( $out->read, 'error message', 'printErr() should print to STDERR' );
	printErr(7, 6, 5);
	is( $out->read, 7, '... and only the first parameter' );
}

{
	local *Everything::localtime = sub { return (0..8) };
	is( Everything::getTime(), '02:01 05-03-1905', 
		'getTime() should format localtime output nicely' );
	is( Everything::getTime(1), '02:01 Sat May 3 1905',
		'... and should respect long parameter' );
}

# printLog
# 	opens a filehandle to file named in lexical $everythingLog

# clearLog
#	also opens filehandle to lexical $everythingLog file

# getParamArray
my $order = 'red, blue, one , two';
my @results = getParamArray($order, qw( one two red blue ));
my @args = (-one => 1, -two => 2, -red => 'red', -blue => 'blue');
is( scalar @results, 4, 'getParamArray() should return array params unchanged');

@results = getParamArray($order, @args);
is( scalar @results, 4, '... and the right number of args in hash mode' );

# now ask for a repeated parameter
@results = getParamArray($order . ', one', @args);
is( scalar @results, 5, '... (even when being tricky)' );
is( join('', @results), 'redblue121', '... the values in hash mode' );

# and leave out some parameters
is( join('', getParamArray('red,blue', @args)), 'redblue', 
	'... and only the requested values');

# cleanLinks
# make $select
#	get database handle
#	prepare statement
#	execute cursor
#		fetchrow_hashref()
#			without a node_id, save to_node as bad
#	prepare statement
#		fetchrow_hashref()
#			without a node_id, save from_node as bad
#	loop through to_nodes and from_nodes, calling sqlDelete on them
{
	local $Everything::DB;
	$Everything::DB = Everything::NodeBase->new();

	my $results = FakeDBI->new([
		{ node_id => 1 },
		{ to_node => 0 },
		undef,
		{ node_id => 1 },
		{ to_node => 0 },
	]);

	Everything::NodeBase::setResults($results);
	Everything::cleanLinks();
	my @calls = Everything::NodeBase::calls();
	like( join(' ', @{ $calls[1] }), qr/prepare SELECT to_node/,
		'cleanLinks() should select all to_node values in links table' );
	like( join(' ', @{ $calls[3] }), qr/prepare SELECT from_node/,
		'... and all from_node values in links table' );
	
	FakeDBI::set_execute(1);
	Everything::cleanLinks();
	@calls = (Everything::NodeBase::calls())[-1, -2];

	is( join(' ', @{ $calls[0] }[0,1], $calls[0]->[2]->{from_node}), 
		'sqlDelete links 0', '... should delete appropriate to links' );
	is( join(' ', @{ $calls[1] }[0,1], $calls[1]->[2]->{to_node}), 
		'sqlDelete links 0', '... should delete appropriate from links' );
}

# initEverything
{
	local @Everything::fsErrors = '123';
	local @Everything::bsErrors = '321';
	local ($Everything::DB, %Everything::NODEBASES);

	initEverything('onedb', 1);

	is( join('', @$Everything::DB), 'onedb1', 
		'initEverything() should create a new database if needed' );
	is( scalar @Everything::fsErrors, 0, '... and should clear @fsErrors' );
	is( scalar @Everything::bsErrors, 0, '... and @bsErrors' );
	
	initEverything('onedb');
	is( $Everything::DB, $Everything::NODEBASES{onedb}, 
		'... should reuse NodeBase object with same DB requested' );
	
	initEverything('twodb');
	is( scalar keys %Everything::NODEBASES, 2, '... and should cache objects' );
}

# clearFrontside
{
	local @Everything::fsErrors = '123';
	clearFrontside();
	is( scalar @Everything::fsErrors, 0, 
		'clearFrontside() should clear @fsErrors' );
}

# clearBackside
{
	local @Everything::bsErrors = '123';
	clearBackside();
	is( scalar @Everything::bsErrors, 0, 
		'clearBackside() should clear @bsErrors' );
}

# logErrors()
{
	local *STDOUT;
	my $out = tie *STDOUT, 'TieOut';
	is( logErrors(), undef, 
		'logErrors() should return, lacking passed a warning or an error' );
	
	local $Everything::commandLine = 0;
	ok( logErrors('warning', undef, 'code', 'CONTEXT'), 
		'... and should succeed given a warning or an error' );

	is( join('', sort values %{ $Everything::fsErrors[-1]}), 
		'CONTEXTcodewarning', 
		'... should store message in @fsErrors normally' );
	logErrors(undef, 'error', 'code', 'CONTEXT');
	is( join('', sort values %{ $Everything::fsErrors[-1]}), 
		'CONTEXTcodeerror', 
		'... should use blank string lacking a warning or error' );
	is( $$out, undef, '... and should not print unless $commandLine is true' );
	
	$Everything::commandLine = 1;
	logErrors('warn', 'error', 'code');
	my $output = $out->read();

	like( $output, qr/^###/, '... should print if $commandLine is true' );
	like( $output, qr/Warning: warn.+Error: error.+Code:\ncode/s, 
		'... should print warning, error, and code' );

}

# flushErrorsToBackside
{
	local (@Everything::fsErrors, @Everything::bsErrors);

	@Everything::fsErrors = (1 .. 3);
	@Everything::bsErrors = 'a';

	flushErrorsToBackside();
	is( join('', @Everything::bsErrors), 'a123', 
		'flushErrorsToBackside() should push @fsErrors onto @bsErrors' );
	is( scalar @Everything::fsErrors, 0, '... should clear @fsErrors' );
}

is( getFrontsideErrors(), \@Everything::fsErrors, 
	'getFrontsideErrors() should return reference to @fsErrors' );
is( getBacksideErrors(), \@Everything::bsErrors,
	'getBacksideErrors() should return reference to @bsErrors' );

# searchNodeName()
{
	local $Everything::DB;
	$Everything::DB = Everything::NodeBase->new();

	my $skipwords = FakeNode->new();
	Everything::NodeBase::setNode(
		nosearchwords => $skipwords,
	);

	$skipwords->{vars} = {
		'ab'	=> 1,
		'abcd'	=> 1,
	};
	is( Everything::searchNodeName(''), undef, 
		'searchNodeName() should return without workable words to find' );
	
	Everything::NodeBase::calls();
	Everything::NodeBase::setId(foo => 1, bar => 2);
	Everything::searchNodeName('', [ 'foo', 'bar' ]);
	my @calls = Everything::NodeBase::calls();
	is( $calls[0]->[1], 'foo', '... should call getId() for first type' );
	is( $calls[1]->[1], 'bar', '... and subsequent types (if passed)' );

	my $results = FakeDBI->new([ 1, 2, 3 ]);
	Everything::NodeBase::setResults($results);
	my $found = Everything::searchNodeName('ab aBc!  abcd a ee', 
		[ 'foo', 'bar' ]);
	@calls = Everything::NodeBase::calls();
	is( $calls[4]->[0], 'quote', '... should quote() searchable words' );
	like( $calls[4]->[1], qr/abc\\!/, '... should escape nonword chars too' );

	is( $calls[-1]->[0], 'sqlSelectMany', 
		'... should sqlSelectMany() matching titles' );
	like( $calls[-1]->[1], qr/\*.+?lower.title.+?rlike.+abc.+\+.+ee/, 
		'... selecting by title with regexes' );
	like( $calls[-1]->[3], qr/AND .type_nodetype = 1 OR type_nodetype = 2/,
		'... should constrain by type, if provided' );
	is( $calls[-1]->[4], 'ORDER BY matchval DESC', 
		'... and should order results properly' );
	
	is( ref $found, 'ARRAY', '... should return an arrayref on success' );
	is( scalar @$found, 3, '... should find all proper results' );
	is( join('', @$found), '123', '... and should return results' );
}

# getCallStack() and dumpCallStack()
{
	local *Everything::caller = sub {
		my $frame = shift;
		return if $frame >= 5;
		return ('Everything', 'everything.t', 100 + $frame, $frame, $frame % 2);
	};

	my @stack = Everything::getCallStack();
	is( scalar @stack, 4, 'getCallStack() should not report self' );
	is( $stack[0], 'everything.t:104:4', 
		'... should report file, line, subname' );
	is( $stack[-1], 'everything.t:101:1',
		'... and report frames in reverse order' );

	local *STDOUT;
	my $out = tie *STDOUT, 'TieOut';
	Everything::dumpCallStack();

	my $stackdump = $out->read();
	like( $stackdump, qr/Start/, 'dumpCallStack() should print its output' );
	like( $stackdump, qr/102:2.+103:3.+104:4/s, 
		'... should report stack in forward order' );
	ok( $stackdump !~ /101/, '... but should remove current frame' );
}

# this is handy for the other functions
my $log;
local *Everything::printLog;
*Everything::printLog = sub {
	$log .= join('', @_);
};

# logCallStack()
{
	local *Everything::getCallStack;
	*Everything::getCallStack = sub {
		return (1 .. 10);
	};

	Everything::logCallStack();
	like( $log, qr/^Call Stack:/, 'logCallStack() should print log' );
	like( $log, qr/9.8.7/s, 
		'... and should report stack backwards, minus first element' );
}

# logHash()
{
	my $hash = { foo => 'bar', boo => 'far' };
	ok( logHash($hash), 'logHash() should succeed' );

	# must quote the parenthesis in the stringified references
	like( $log, qr/\Q$hash\E/, '... and should log hash reference' );
	like( $log, qr/foo = bar/, '... and hash keys' );
	like( $log, qr/boo = far/, '... and hash keys (redux)' );
}

package FakeNode;

sub new {
	bless({}, $_[0]);
}

sub getVars {
	return $_[0]->{vars};
}
