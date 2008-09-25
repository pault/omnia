#!/usr/bin/perl 

use lib 't/lib';
use DBTestUtil qw/drop_database skip_cond/;
use Test::More;

if ( my $skip = skip_cond() ) {
    plan skip_all => $skip;
} else {
    plan tests => 1;
}

ok( drop_database(), '...drops the test database.' );
