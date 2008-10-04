#!/usr/bin/perl 

use lib 't/lib';
use Everything::Test::Ecore::Compile;
use DBTestUtil qw/skip_cond nodebase/;
use Test::More;
use strict;
use warnings;

use Carp;

my $skip = skip_cond();
my $nodebase;

if ( $skip ) {
    Everything::Test::Ecore::Compile->SKIP_CLASS( $skip );
} else {
    $nodebase = nodebase();
}

my $tests = Everything::Test::Ecore::Compile->new( nodebase => $nodebase );

$tests->runtests;
