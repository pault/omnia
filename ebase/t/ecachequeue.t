#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	use lib '../blib/lib', 'lib/', '..';
}

use Test::More tests => 45;

use FakeNode;
my $node = FakeNode->new();

{
	$INC{'Everything.pm'} = 1;

	my $import;
	local *Everything::import;
	*Everything::import = sub {
		$import = caller();
	};
	use_ok( 'Everything::CacheQueue' );
	is( $import, 'Everything::CacheQueue', 
		'Everything::CacheQueue should use() Everything' );
}

# new()
{
	local *Everything::CacheQueue::createQueueData;
	*Everything::CacheQueue::createQueueData = sub {
		return { id => $_[1]};
	};

	my $cq = Everything::CacheQueue->new();
	isa_ok( $cq, 'Everything::CacheQueue' );
	is( $cq->{queueHead}{id}, 'HEAD', 'new() should create head queue data' );
	is( $cq->{queueTail}{id}, 'TAIL', '... and tail queue data' );
	is( $cq->{queueHead}{prev}{id}, 'TAIL', '... pointing head prev to tail' );
	is( $cq->{queueTail}{next}{id}, 'HEAD', '... and tail next to head' );
	is( $cq->{queueSize}, 0, '... and queueSize should be 0' );
	is( $cq->{numPermanent}, 0, '... and numPermanent should be 0' );
}

# queueItem
{
	$node->{_subs}{createQueueData} = [ 'queued' ];

	is( Everything::CacheQueue::queueItem($node, 'foo', 1), 'queued',
		'queueItem() should return queued data' );
	
	is( join(' ', @{ $node->{_calls}[0] }), 'createQueueData foo 1', 
		'... calling createQueueData with item and permanent flag' );
	is( join(' ', @{ $node->{_calls}[1] }), 'queueData queued', 
		'... and queueData() with item' );

}

# getItem()
$node->{_calls} = [];
my $data = { item => 'foo' };
is( Everything::CacheQueue::getItem($node, $data), 'foo', 
	'getItem() should return cached item' );
is( join(' ', @{ $node->{_calls}[0] }), "removeData $data", 
	'... removing it from the queue' );
is( join(' ', @{ $node->{_calls}[1] }), "queueData $data", 
	'... and queueing it again' );

# getNextItem()
{
	my $queue = {};
	$queue->{prev} = $node;
	$node->{queueHead} = $queue;
	$node->{item} = 'foo';

	is( Everything::CacheQueue::getNextItem($node), 'foo', 
		'getNextItem() should return first item in queue' );
	is( join(' ', @{ $node->{_calls}[-1] }), "removeData $node",
		'... and should call removeData() on item' );

	local *FakeNode::queueData;
	*FakeNode::queueData = sub {
		push @{ $_[0]->{_calls} }, [ 'queueData' ];
		$_[0]{queueHead}{prev} = {
			item		=> 'bar',
			permanent	=> 0,
		};
	};

	$node->{queueHead}{prev}{permanent} = 1;
	$node->{_calls} = [];

	is( Everything::CacheQueue::getNextItem($node), 'bar', 
		'... should skip nodes with permanent flag' );

	is( join(' ', $node->{_calls}[0][0], $node->{_calls}[1][0]), 
		'removeData queueData', 
		'... and should requeue permanently cached items' );
}

# getSize()
$node->{queueSize} = 41;
is( Everything::CacheQueue::getSize($node), 41, 
	'getSize() should return queue size' );

# removeItem()
is( Everything::CacheQueue::removeItem($node), undef,
	'removeItem() should return undef if data is undefined' );
$data = { item => 'bar' };
is( Everything::CacheQueue::removeItem($node, $data), 'bar',
	'... should return queued item' );
is( join(' ', @{ $node->{_calls}[-1] }), "removeData $data", 
	'... and should call removeData() on it' );

# listItems()
{
	$node->{queueTail}{next} = {
		item => 'first',
		next => {
			item => 'second',
			next => {
				item => 'HEAD'
			}
		},
	};

	my $list = Everything::CacheQueue::listItems($node);
	isa_ok( $list, 'ARRAY', 'listItems() should return an array reference' );
	is( scalar @$list, 2, '... of the correct number of items' );
	is( "@$list", 'first second', '... in the correct order (last first)' );
}

# queueData()
$node->{numPermanent} = 0;
$node->{queueTail} = 'tail';
$data = {};
Everything::CacheQueue::queueData($node, $data);
is( join(' ', @{ $node->{_calls}[-1] }), "insertData $data tail",
	'queueData() should call insertData() with data and cache tail' );

$data->{permanent} = 1;
Everything::CacheQueue::queueData($node, $data);
is( $node->{numPermanent}, 1, 
	'... and should increment numPermanent only for permanent data' );

# insertData()
{
	my $data = {};
	my $after = { id => 'before next' };
	my $before = { next => $after };
	$node->{queueSize} = 6;

	Everything::CacheQueue::insertData($node, $data, $before);
	is( $data->{next}{id}, 'before next', 
		'insertData() should set data next to before next' );
	is( $data->{prev}, $before, '... and its previous to before' );
	is( $before->{next}, $data, '... and before next to data' );
	is( $after->{prev}, $data, '... and before next prev to data' );
	is( $node->{queueSize}, 7, '... and should increment queueSize' );
}

# removeData()
{
	local *removeData = \&Everything::CacheQueue::removeData;

	my $data = {
		next => 0,
		prev => 0,
	};

	$node->{queueSize} = 0;
	is( removeData($node), undef, 
		'removeData() should return with nothing in queue' );

	$node->{queueSize} = 4;
	$node->{numPermanent} = 6;

	is( removeData($node, $data), undef, 
		'... or if data has already been removed from queue' );

	my $next = {
		prev => 1,
	};

	my $prev = {
		next => 1,
	};

	$data = {
		next		=> $next,
		prev		=> $prev,
		permanent	=> 0,
	};

	removeData($node, $data);
	is( $next->{prev}, $prev, '... should set next prev to previous' );
	is( $prev->{next}, $next, '... should set prev next to next' );

	is( join(' ', @$data{qw( next prev )}), '0 0', 
		'... and should set next and prev in data to 0' );

	is( $node->{queueSize}, 3, '... and reduce queueSize' );

	$data = {
		next		=> $next,
		prev		=> $prev,
		permanent	=> 1,
	};
	removeData($node, $data);
	is( $node->{numPermanent}, 5, 
		'... but should reduce numPermanent only when removing permanent item');
}

# createQueueData()
{
	local *cqd = \&Everything::CacheQueue::createQueueData;

	my $queued = cqd($node, 'foo');
	isa_ok( $queued, 'HASH', 'createQueueData() should return a hashref' );

	is( $queued->{item}, 'foo', '... storing data in "item" slot' );
	is( join(' ', @$queued{qw( next prev )}), '0 0',
		'... setting "next" and "prev" slots both to 0' );
	is( $queued->{permanent}, 0, '... vivifying "permanent" to 0 if needed' );

	is( cqd($node, 'foo', 1)->{permanent}, 1, 
		'... but should respect passed "permanent" flag' );
}
