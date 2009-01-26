#!/usr/bin/perl

use lib 't/lib';
use DBTestUtil qw/config_file skip_cond/;
use Everything::DB::Test::Live;
use strict;
use warnings;


# touch 't/lib/db/run-tests' to run.
my $RUN_TESTS = -e 't/lib/db/run-tests';

my $msg;

my $config_file = 't/lib/db/Pg.conf';

my @config_args;

push @config_args, file => $config_file if -e $config_file;

my $config = Everything::Config->new( @config_args );

if ( ! $RUN_TESTS ) {

    Everything::DB::Test::Live->SKIP_CLASS('Time consuming live database tests skipped by default.') unless $RUN_TESTS;

} elsif ( !  $config->database_superuser ) {

    Everything::DB::Test::Live->SKIP_CLASS('Skipping tests database super user must be set.')

}

my $tests = Everything::DB::Test::Live->new( config => $config, SKIP => $msg ) ;


$tests->runtests;


__END__
