package Everything::Test::Security;

use base 'Everything::Test::Abstract';
use Test::More;
use strict;
use warnings;


sub test_inherit_permissions :Test(6) {

    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'inheritPermissions' );
    is( Everything::Security::inheritPermissions( '----', 'rwxd' ),
	'----',
	'inheritPermissions() should not modify uninheritable permissions' );
    is( Everything::Security::inheritPermissions( 'i-i-', 'rwxd' ),
	'r-x-', '... and should inherit the inheritable' );

    my @le;
    local *Everything::logErrors;
    *Everything::logErrors = sub { push @le, [@_] };

    ok( ! Everything::Security::inheritPermissions( '---', '----' ),
	'... should fail with permission length mismatch' );
    is( @le, 1, '... logging a warning' );
    like( $le[0][0], qr/permission length mismatch/i, '... and warn about it' );

}

sub test_check_permissions :Test(7) {

    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'checkPermissions' );

    my @le = ();
    ok( !Everything::Security::checkPermissions('rwx-'),
	'check() should return false unless modes are passed' );
    is( @le, 0, '... and should not warn' );

    ok( Everything::Security::checkPermissions( 'rwxd', 'rw' ),
	'... should return true if op is permitted' );
    ok( ! Everything::Security::checkPermissions( 'rwxd', 'rwxdc' ), '... and false if op is prohibited' );
    ok( ! Everything::Security::checkPermissions( '',  'r' ), '... and false if no perms are present' );
    ok( ! Everything::Security::checkPermissions( 'i', '' ),  '... and false if no modes are present' );

}

1;
