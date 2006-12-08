package Everything::Test::Util;

use base 'Everything::Test::Abstract';
use Test::More;
use strict;

sub startup :Test(startup => +0) {
    my $self = shift;
    $self->SUPER;
    my $class = $self->{class};
    my $file;
    ($file = $class) =~ s/::/\//g;

    $file .= '.pm';

    require $file;
    $class->import(qw/escape unescape/); # expressly import these subs

}

sub test_escape :Test(4){

    my $self = shift;
    can_ok( $self->{class}, 'escape' );
    my $encoded = escape('abc|@# _123');
    $self->{encoded} = $encoded;
    like( $encoded, qr/^abc.+_123$/, 'escape() should not modify alphanumerics' );
    my @encs = $encoded =~ m/%([a-fA-F\d]{2})/g;
    is( scalar @encs, 4, '... should encode all nonalphanumerics in string' );
    is( join( '', map { chr( hex($_) ) } @encs ),
	'|@# ', '... using ord() and hex()' );



}

sub test_unescape :Test(2) {
    my $self = shift;
    my $encoded = $self->{encoded};
    can_ok( $self->{class}, 'unescape' );
    is( unescape($encoded), 'abc|@# _123', 'unescape() should reverse escape()' );


}

1;
