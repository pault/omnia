#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use strict;
use vars qw( $AUTOLOAD );

use Test::More tests => 42;
use Test::MockObject;

# temporarily avoid sub redefined warnings
my $mock = Test::MockObject->new();
$mock->fake_module( 'Everything' );
$mock->fake_module( 'Everything::Util' );
$mock->fake_module( 'XML::Dom' );

my $package = 'Everything::Node';

sub AUTOLOAD
{
	$AUTOLOAD =~ s/main:://;
	if (my $sub = $package->can( $AUTOLOAD ))
	{
		no strict 'refs';
		*{ $AUTOLOAD} = $sub;
		goto &$AUTOLOAD;
	}
}

use_ok( $package ) or die;

my ($result, $method, $args, @le);

local *Everything::logErrors;
*Everything::logErrors = sub {
	push @le, [ @_ ];
};

can_ok( $package, 'new' );
# DESTROY()
can_ok( $package, 'getId' );
# AUTOLOAD()
can_ok( $package, 'SUPER' );
can_ok( $package, 'getNodeMethod' );
can_ok( $package, 'getClone' );
can_ok( $package, 'assignType' );
can_ok( $package, 'cache' );
can_ok( $package, 'removeFromCache' );
can_ok( $package, 'quoteField' );
can_ok( $package, 'isOfType' );
can_ok( $package, 'hasAccess' );
can_ok( $package, 'getUserPermissions' );
can_ok( $package, 'getUserRelation' );
can_ok( $package, 'deriveUsergroup' );
can_ok( $package, 'getDefaultPermissions' );
can_ok( $package, 'getDynamicPermissions' );
can_ok( $package, 'lock' );
can_ok( $package, 'unlock' );
can_ok( $package, 'updateLinks' );
can_ok( $package, 'updateHits' );

can_ok( $package, 'selectLinks' );

$mock->{node_id} = 11;
$mock->{DB}      = $mock;

$mock->set_series( sqlSelectMany => undef, $mock )
	 ->set_series( fetchrow_hashref => 'bar', 'baz' )
	 ->set_true( 'finish' )
	 ->clear();

$result = selectLinks( $mock );
($method, $args) = $mock->next_call();
is( $method, 'sqlSelectMany', 'selectLinks() should select from the database' );
is( join('-', @$args), "$mock-*-links-from_node=?--11",
	'... from links table for node_id' );
is( $result, undef, '... returning if that fails' );

is_deeply( selectLinks( $mock, 'order' ), [ 'bar', 'baz' ],
	'... returning an array reference of results' );
($method, $args) = $mock->next_call();
like( $args->[4], qr/ORDER BY order/, '... respecting order parameter' );

can_ok( $package, 'getTables' );

can_ok( $package, 'getHash' );
$mock->{hash_field} = 'stored';
is( getHash( $mock, 'field' ), 'stored',
	'getHash() should return stored hash if it exists' );

$mock->{node_id} = 11;
$mock->{title}   = 'title';

is( getHash( $mock, 'nofield' ), undef,
	'... returning nothing if field does not exist' );
is( @le, 1, '... logging a warning' );
like( $le[0][0], qr/nofield.+does not exist.+11.+title/,
	'... with the appropriate message' );

$mock->{falsefield} = 0;
is( getHash( $mock, 'falsefield' ), undef, '... returning if value is false' );

$mock->{realfield} = 'foo=bar&baz=quux&blat= ';
{
	local *Everything::Util::unescape;
	*Everything::Util::unescape = sub { reverse $_[0] };
	$result = getHash( $mock, 'realfield' );
}

is_deeply( $result, {
	foo  => 'rab',
	baz  => 'xuuq',
	blat => '',
}, '... returning hash reference of stored parameters' ); 

is( $mock->{hash_realfield}, $result, '... and caching it in node' );

can_ok( $package, 'setHash' );
can_ok( $package, 'getNodeDatabaseHash' );
can_ok( $package, 'isNodetype' );
can_ok( $package, 'getParentLocation' );
can_ok( $package, 'toXML' );
can_ok( $package, 'existingNodeMatches' );
