#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 26;

my $node = FakeNode->new();

{
	local $INC{'Everything.pm'} = 1;

	local *Everything::import;

	my $import;
	*Everything::import = sub {
		$import = caller();
	};

	use_ok( 'Everything::Node::user' );
	is( $import, 'Everything::Node::user', '... should use Everything module' );
}

$node->{DB} = $node;

# insert
$node->{_subs} = {
	SUPER	=> [ 10 ],
};

is( Everything::Node::user::insert($node, 'user'), 10, 
	'insert() should return inserted node_id' );
is( join(' ', @{ $node->{_calls}[0] }), 'SUPER', '... and should call SUPER()');
is( join(' ', @{ $node->{_calls}[1] }), 'update user', '... and then update()');
is( $node->{author_user}, 10, '... and set "author_user" to inserted node_id' );

{
	local *isGod = \&Everything::Node::user::isGod;

	$node->{_calls} = [];
	$node->{_subs} = {
		getNode		=> [ 0, $node, $node ],
		inGroup		=> [ 'inGroup' ],
		inGroupFast	=> [ 'inGroupFast' ],
	};

	ok( ! isGod($node), 
		'isGod() should return false unless it can find gods usergroup' );
	is( join(' ', @{ $node->{_calls}[0] }), 'getNode gods usergroup',
		'... and should call getNode() to find it' );
	
	is( isGod($node), 'inGroupFast', 
		'... should call inGroupFast() without recurse flag' );
	is( isGod($node, 1), 'inGroup', '... and inGroup() with it' );
}

# isGuest
{ 
	local *isGuest = \&Everything::Node::user::isGuest;
	my @newnodes = (bless({ guest_user => 0 }, 'FakeNode'),
					bless({ guest_user => 1 }, 'FakeNode'));

	$node->{_calls} = [];
	$node->{_subs} = {
		getNode => [ 0, $node, $node ],
		getVars => [ undef, @newnodes ],
	};

	ok( isGuest($node), 
		'isGuest() should return true unless it can get system settings node' );
	is( join(' ', @{ $node->{_calls}[0] }), 'getNode system settings setting',
		'... so it should try to get system settings node with getNode()' );
	ok( isGuest($node), 
		'... should return true unless it can get system settings node' );

	$node->{node_id} = 1;

	ok( ! isGuest($node),
		'... should return false if node_ids do not match' );

	ok( isGuest($node),
		'... and true if they do' );
}
# call getNode for 'system settings'
# return 1 unless that worked

# getNodeKeys
my $hash_ref = { passwd => 1, lasttime => 1, title => 1 };
$node->{_subs}{SUPER} = [ $hash_ref, $hash_ref ];
my $keys = Everything::Node::user::getNodeKeys($node);
isa_ok( $keys , 'HASH', 'getNodeKeys() should return a hash' );
is( scalar keys %$keys, 3, '... but should delete nothing if not exporting' );

$keys = Everything::Node::user::getNodeKeys($node, 1);
ok( !exists $keys->{passwd}, '... should delete "passwd" if exporting' );
ok( !exists $keys->{lasttime}, '... should delete "lasttime" if exporting' );

# verifyFieldUpdate
{
	local *verifyFieldUpdate = \&Everything::Node::user::verifyFieldUpdate;

	foreach my $field (qw( title karma lasttime )) {
		ok( ! verifyFieldUpdate($node, $field), 
			"verifyFieldUpdate should return false for '$field' field" );
	}
	$node->{_subs}{SUPER} = [ 1, 0 ];
	ok( verifyFieldUpdate($node, 'absent'), 
		'... should return false if SUPER() call does' );
	ok( ! verifyFieldUpdate($node, 'title'), 
		'... and false if field is restricted here, but not in parent' );
}

ok( ! Everything::Node::user::conflictsWith(), 
	'conflictsWith() should return false' );

ok( ! Everything::Node::user::updateFromImport(), 
	'updateFromImport() should return false' );
