#!/usr/bin/perl -w

use Everything::Test::Auth;

Everything::Test::Auth->runtests;

__END__


# BEGIN
#   {
#       chdir 't' if -d 't';
#       unshift @INC, '../lib', '../blib/lib', 'lib';
#   }

# use strict;
# use File::Path;
# use File::Spec;

# use Test::More tests => 32;

# use Test::Exception;
# use Test::MockObject;

my ( $result, $method, $args, @le );



can_ok( $package, 'generateSession' );
my $mock = Test::MockObject->new();
$mock->{options} = { guest_user => 'guest' };
$mock->set_always( getVars => 'vars' );

$db->set_false('getNode')->clear();

throws_ok { Everything::Auth::generateSession($mock) } qr/Unable to get user!/,
	'generateSession() should die with no user';
( $method, $args ) = $db->next_call();
is( $method, 'getNode', '... so should fetch a user given none' );
is( $args->[1], 'guest', '... using guest user option' );

my @results = Everything::Auth::generateSession( $mock, $mock );
is_deeply( \@results, [ $mock, 'vars' ], '... returning user and user vars' );
