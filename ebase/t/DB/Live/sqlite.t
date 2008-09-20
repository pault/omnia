#!/usr/bin/perl

use Everything::DB::Test::Live::sqlite;
use strict;
use warnings;

# set to 0 to run tests
my $RUN_TESTS = -e 't/lib/db/run-tests';


my $msg;

my $config = Everything::Config->new( file => 't/lib/db/sqlite.conf' );

Everything::DB::Test::Live::sqlite->SKIP_CLASS('Time consuming live database tests skipped by default.') unless $RUN_TESTS;
my $tests = Everything::DB::Test::Live::sqlite->new( config => $config, SKIP => $msg ) ;


$tests->runtests;

__END__

