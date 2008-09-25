#!/usr/bin/perl

use lib 't/lib';
use Everything::Test::Ecore::Install;
use Everything::Config;
use Everything::CmdLine qw/abs_path/;
use DBTestUtil qw/config_file skip_cond/;
use strict;
use warnings;

my $ball = '../ecore';

#my $config_file = 't/lib/db/Pg.conf';
my $config_file = config_file();

my $skip = skip_cond();

Everything::Test::Ecore::Install->SKIP_CLASS( $skip ) if $skip;

my $config = Everything::Config->new( file => $config_file );

my $tests = Everything::Test::Ecore::Install->new( nodeball => abs_path( $ball ), config => $config );

$tests->runtests;
