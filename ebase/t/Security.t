#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN
{
	chdir 't' if -d 't';
	use lib '../blib/lib', '..', 'lib/';
}

use Test::More tests => 14;

my $package = 'Everything::Security';

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "${package}::$AUTOLOAD";

	if ( defined &{$sub} )
	{
		*{$AUTOLOAD} = \&{$sub};
		goto &{$sub};
	}
}

use_ok($package);

# inheritPermissions()
can_ok( $package, 'inheritPermissions' );
is( inheritPermissions( '----', 'rwxd' ),
	'----',
	'inheritPermissions() should not modify uninheritable permissions' );
is( inheritPermissions( 'i-i-', 'rwxd' ),
	'r-x-', '... and should inherit the inheritable' );

my @le;
local *Everything::logErrors;
*Everything::logErrors = sub { push @le, [@_] };

ok( !inheritPermissions( '---', '----' ),
	'... should fail with permission length mismatch' );
is( @le, 1, '... logging a warning' );
like( $le[0][0], qr/permission length mismatch/i, '... and warn about it' );

# checkPermissions()
can_ok( $package, 'checkPermissions' );

@le = ();
ok( !checkPermissions('rwx-'),
	'check() should return false unless modes are passed' );
is( @le, 0, '... and should not warn' );

ok( checkPermissions( 'rwxd', 'rw' ),
	'... should return true if op is permitted' );
ok( !checkPermissions( 'rwxd', 'rwxdc' ), '... and false if op is prohibited' );
ok( !checkPermissions( '',  'r' ), '... and false if no perms are present' );
ok( !checkPermissions( 'i', '' ),  '... and false if no modes are present' );
