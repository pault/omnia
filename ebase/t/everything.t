#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', '..', 'lib/';
}

BEGIN
{
	package Everything;
	use subs qw( localtime caller );
	package main;
	require 'lib/FakeNodeBase.pm';
	$INC{'Everything/NodeBase.pm'} = 1;
}

use TieOut;
use FakeDBI;
use File::Path;
use File::Spec;
use Test::More tests => 70;
use Test::MockObject;

$ENV{EVERYTHING_LOG} = File::Spec->catfile( File::Spec->curdir(), 'log' );
use_ok( 'Everything' );

foreach my $sub ( qw( 
	getNode getNodeById getType getNodeWhere selectNodeWhere getRef getId )) {
	can_ok('main', $sub);
}

# printErr()
{
	local *STDERR;
	my $out = tie *STDERR, 'TieOut';
	printErr('error message');
	is( $out->read, 'error message', 'printErr() should print to STDERR' );
	printErr(7, 6, 5);
	is( $out->read, 7, '... and only the first parameter' );
}

# getTime()
{
	local *Everything::localtime = sub { return (0..8) };
	is( Everything::getTime(), '02:01 05-03-1905', 
		'getTime() should format localtime output nicely' );
	is( Everything::getTime(1), '02:01 Sat May 3 1905',
		'... and should respect long parameter' );
}

# printLog()
# clearLog()
SKIP: {
	local *Everything::getTime;
	*Everything::getTime = sub { 'timestamp' };

	unlink 'log' if -e 'log';

	Everything::printLog( 'logme' );

	local *IN;
	my $skip = ok( open( IN, 'log' ),
		'printLog() should log to file specified in %ENV' );

	skip( 'log open failed', 4 ) unless $skip;
	my $line = <IN>;

	is( $line, "timestamp: logme\n", '... logging time and message' );
	close IN;

	Everything::printLog( 'second' );
	open( IN, 'log' ) or skip( 'log open failed again', 3 );

	my @lines = <IN>;
	close IN;

	is( $lines[1], "timestamp: second\n", '... appending to log' );

	Everything::clearLog();

	open( IN, 'log' ) or skip( 'log open failed on third try', 2 );
	@lines = <IN>;

	is( @lines, 1, 'clearLog() should clear old lines' );
	is( $lines[0], 'timestamp: Everything log cleared',
		'... writing a cleared message' );

	unlink 'log';
}

# getParamArray()
my $order = 'red, blue, one , two';
my @results = getParamArray($order, qw( one two red blue ));
my @args = (-one => 1, -two => 2, -red => 'red', -blue => 'blue');
is( @results, 4, 'getParamArray() should return array params unchanged');

@results = getParamArray($order, @args);
is( @results, 4, '... and the right number of args in hash mode' );

# now ask for a repeated parameter
@results = getParamArray($order . ', one', @args);
is( @results, 5, '... (even when being tricky)' );
is( join('', @results), 'redblue121', '... the values in hash mode' );

# and leave out some parameters
is( join('', getParamArray('red,blue', @args)), 'redblue', 
	'... and only the requested values');

# cleanLinks()
{
	my $mock = Test::MockObject->new();
	$mock->set_always( 'sqlSelectJoined', $mock )
		 ->set_series( 'fetchrow_hashref', { node_id => 1 }, { to_node => 8 },
			0, { node_id => 2, to_node => 9 }, { to_node => 10 } )
		 ->set_true( 'sqlDelete' );

	local *Everything::DB;
	*Everything::DB = \$mock;

	Everything::cleanLinks();

	my @expect = ( to_node => 8, from_node => 10 );
	my $count;

	while (my ($method, $args) = $mock->next_call())
	{
		next unless $method eq 'sqlDelete';
		my $args = join('-', $args->[1], $args->[2]->{ shift @expect });
		is( $args, 'links-' . shift @expect,
			'cleanLink() should delete bad links' );
		$count++;
	}

	is( $count, 2, '... and only bad links' );
}

# initEverything()
SKIP:
{
	local @Everything::fsErrors = '123';
	local @Everything::bsErrors = '321';
	local ($Everything::DB, %Everything::NODEBASES);

	initEverything('onedb', { staticNodetypes => 1 });

	is( join('', @$Everything::DB), 'onedb1', 
		'initEverything() should create a new database if needed' );
	is( @Everything::fsErrors, 0, '... and should clear @fsErrors' );
	is( @Everything::bsErrors, 0, '... and @bsErrors' );

	initEverything('onedb');
	is( $Everything::DB, $Everything::NODEBASES{onedb}, 
		'... should reuse NodeBase object with same DB requested' );

	initEverything('twodb');
	is( keys %Everything::NODEBASES, 2, '... and should cache objects' );

	eval { initEverything( 'threedb', { dbtype => 'badtype' } ) };
	like($@, qr/Unknown database type 'badtype'/, '... dying given bad dbtype');

	my $status;
	local @INC = 'lib';

	@INC = 'lib';

	my $path = File::Spec->catdir(qw( lib Everything NodeBase ));
	
	if (-d $path or mkpath $path)
	{
		local *OUT;
		if (open(OUT, '>', File::Spec->catfile( $path, 'foo.pm' )))
		{
			(my $foo = <<'			END_HERE') =~ s/^\t+//gm;;
			package Everything::NodeBase::foo;

			sub new { 'foo' }
	
			1;
			END_HERE

			print OUT $foo;
			$status = 1;
		}
	}

	skip( 'Cannot write fake module', 2 )  unless $status;

	eval { initEverything( 'foo', { dbtype => 'foo' } ) };
	is( $@, '', '... loading nodebase for requested database type' );
	is( $Everything::NODEBASES{foo}, 'foo', "... and caching it" );
}

# clearFrontside()
{
	local @Everything::fsErrors = '123';
	clearFrontside();
	is( @Everything::fsErrors, 0, 'clearFrontside() should clear @fsErrors' );
}

# clearBackside()
{
	local @Everything::bsErrors = '123';
	clearBackside();
	is( @Everything::bsErrors, 0, 'clearBackside() should clear @bsErrors' );
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
	like( $output, qr/Warning: warn.+Error: error.+Code: code/s,
		'... should print warning, error, and code' );
}

# flushErrorsToBackside()
{
	local (@Everything::fsErrors, @Everything::bsErrors);

	@Everything::fsErrors = (1 .. 3);
	@Everything::bsErrors = 'a';

	flushErrorsToBackside();
	is( join('', @Everything::bsErrors), 'a123', 
		'flushErrorsToBackside() should push @fsErrors onto @bsErrors' );
	is( @Everything::fsErrors, 0, '... should clear @fsErrors' );
}

is( getFrontsideErrors(), \@Everything::fsErrors, 
	'getFrontsideErrors() should return reference to @fsErrors' );
is( getBacksideErrors(), \@Everything::bsErrors,
	'getBacksideErrors() should return reference to @bsErrors' );

# searchNodeName()
{
	local $Everything::DB;
	$Everything::DB = Everything::NodeBase->new();

	my $skipwords = Test::MockObject->new();
	$skipwords->set_always( getVars => {
		ab => 1, abcd => 1, });

	Everything::NodeBase::setNode( nosearchwords => $skipwords );

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
	is( @$found, 3, '... should find all proper results' );
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
	is( @stack, 4, 'getCallStack() should not report self' );
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
