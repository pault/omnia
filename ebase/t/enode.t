#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use strict;
use vars qw( $AUTOLOAD );

use Test::More tests => 7;
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

my ($result, $method, $args);

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
