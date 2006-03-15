#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use vars '$AUTOLOAD';

use Test::MockObject;
use Test::More tests => 39;

my $module = 'Everything::Node::user';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::node' ), 'user should extend node' );

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "${module}::$AUTOLOAD";
	if ( defined &{$sub} )
	{
		*{$AUTOLOAD} = \&{$sub};
		goto &{$sub};
	}
}

my $mock = Test::MockObject->new();
my ( $method, $args, $result );

# $mock->fake_module( 'Everything', import => sub { $result = caller() } );

ok( $INC{'Everything.pm'}, '... should use Everything module' );

$mock->{DB} = $mock;

# insert()
$mock->set_series( SUPER => 0, 10, 10 )->set_true('update');

$mock->{title} = 'foo';

ok( !insert( $mock, 'user' ),
	'insert() should return false if SUPER call fails' );
is( $mock->next_call(), 'SUPER', '... and should call SUPER()' );

is( insert( $mock, 'user' ),
	10, '... should return inserted node_id on success' );
( $method, $args ) = $mock->next_call(2);
is( $method, 'update', '... then calling update()' );
is( $args->[1], 'user', '... with the user' );
is( $mock->{author_user}, 10, '... and set "author_user" to inserted node_id' );

# isGod()
$mock->set_series( getNode => 0, ($mock) x 2 )
	->set_always( inGroup     => 'inGroup' )
	->set_always( inGroupFast => 'inGroupFast' )->clear();

ok( !isGod($mock),
	'isGod() should return false unless it can find gods usergroup' );
( $method, $args ) = $mock->next_call();
is( $method, 'getNode', '... and should call getNode() to find it' );
is( join( '-', @$args ), "$mock-gods-usergroup", '... for gods usergroup' );

is( isGod($mock), 'inGroupFast',
	'... should call inGroupFast() without recurse flag' );
is( isGod( $mock, 1 ), 'inGroup', '... and inGroup() with it' );

# isGuest()
my @newnodes = (
	bless( { guest_user => 0 }, 'FakeNode' ),
	bless( { guest_user => 1 }, 'FakeNode' )
);
$mock->{_calls} = [];
$mock->set_series( getNode => 0, ($mock) x 2 )
	->set_series( getVars => undef, @newnodes )->clear();

ok( isGuest($mock),
	'isGuest() should return true unless it can get system settings node' );
( $method, $args ) = $mock->next_call();
is( $method, 'getNode', '... so it should fetch a node' );
is(
	join( '-', @$args ),
	"$mock-system settings-setting",
	'... the system settings'
);
ok( isGuest($mock),
	'... should return true unless it can get system settings node' );

$mock->{node_id} = 1;

ok( !isGuest($mock), '... should return false if node_ids do not match' );
ok( isGuest($mock), '... and true if they do' );

# getNodeKeys()
my $hash_ref = { passwd => 1, lasttime => 1, title => 1 };
$mock->set_always( SUPER => ($hash_ref) x 2 )->clear();

my $keys = getNodeKeys($mock);
isa_ok( $keys, 'HASH', 'getNodeKeys() should return a hash' );
is( scalar keys %$keys, 3, '... but should delete nothing if not exporting' );

$keys = getNodeKeys( $mock, 1 );
ok( !exists $keys->{passwd},   '... should delete "passwd" if exporting' );
ok( !exists $keys->{lasttime}, '... should delete "lasttime" if exporting' );

# verifyFieldUpdate()

foreach my $field (qw( title karma lasttime ))
{
	ok( !verifyFieldUpdate( $mock, $field ),
		"verifyFieldUpdate should return false for '$field' field" );
}
$mock->set_series( SUPER => 1, 0 );
ok(
	verifyFieldUpdate( $mock, 'absent' ),
	'... should return false if SUPER() call does'
);
ok( !verifyFieldUpdate( $mock, 'title' ),
	'... and false if field is restricted here, but not in parent' );

ok( !conflictsWith(), 'conflictsWith() should return false' );

ok( !updateFromImport(), 'updateFromImport() should return false' );

ok( !restrictTitle( {} ), 'restrictTitle() should return false with no title' );
ok(
	!restrictTitle( { title => 'foo|' } ),
	'... or false with bad chars in title'
);
ok(
	restrictTitle( { title => 'some user_name' } ),
	'... or true if it has only good chars'
);

can_ok( $module, 'getNodelets' );
my $nodelets = { nodelets => '1,2,4' };
$mock->set_always( getVars => $nodelets );
is_deeply(
	getNodelets($mock),
	[ 1, 2, 4 ],
	'getNodelets() should return nodelets vars in array ref, if they exist'
);

delete $nodelets->{nodelets};
$mock->set_always( getNode => $mock )->set_series( isOfType => 1, 0 );

$nodelets->{nodelet_group} = $mock;
$mock->{group} = [ 4, 2, 1 ];
is_deeply(
	getNodelets($mock),
	[ 4, 2, 1 ],
	'... or from user nodelet group, if specified'
);

delete $nodelets->{nodelet_group};

$mock->{group} = [ 8, 6, 1 ];
$mock->clear();

is_deeply(
	getNodelets( $mock, 'default' ),
	[ 8, 6, 1 ],
	'... or from default group'
);
( $method, $args ) = $mock->next_call(2);
is( $args->[1], 'default', '... so should fetch default group' );
