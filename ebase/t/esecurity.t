#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	use lib '../blib/lib', '..', 'lib/';
}

use Test::More tests => 9;

use_ok( 'Everything::Security' );
use subs qw( check inherit );
*check		= \&Everything::Security::checkPermissions;
*inherit	= \&Everything::Security::inheritPermissions;

# inheritPermissions
is( inherit('----', 'rwxd'), '----', 
	'inheritPermissions() should not modify uninheritable permissions' );
is( inherit('i-i-', 'rwxd'), 'r-x-', '... and should inherit the inheritable' );

my $warn;
local $SIG{__WARN__} = sub {
	$warn .= join('', @_);
};

TODO: {
	local $TODO = 'parameter length checking not implemented';
	ok( !inherit('---', '----'), 
		'... should fail with permission length mismatch' ); 
	like( $warn, qr/permission length mismatch/i, '... and warn about it' );
}

# checkPermissions
$warn = '';
is( check('rwx-'), 0, 'check() should return false unless modes are passed' );
TODO: {
	local $TODO = 'check $modes for undef in checkPermissons';
	is( $warn, '', '... and should not warn' );
}

is( check('rwxd', 'rw'), 1, '... should return true if op is permitted' );
is( check('rwxd', 'rwxdc'), 0, '... and false if op is prohibited' );
