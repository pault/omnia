#!/usr/bin/perl -w

use strict;


BEGIN
{

	use lib 'blib/lib', 'lib/';
}

use strict;
use vars qw( $AUTOLOAD );

use Test::More qw/no_plan/; #tests => 96;
use Test::MockObject;

my $mock = Test::MockObject->new;
$mock->fake_module('Everything');
$mock->fake_module('Everything::Auth');
$mock->fake_module('Everything::HTTP::Request');

my $package = "Everything::HTTP::ResponseFactory";

# temporarily avoid sub redefined warnings

use_ok( $package ) or die;

can_ok ($package, 'new');
