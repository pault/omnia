#!/usr/bin/perl

use lib 't/lib';
use DBTestUtil qw/config_file skip_cond/;
use Everything::Test::Ecore::Install;
use Everything::Config;
use Everything::CmdLine qw/abs_path/;
use strict;
use warnings;

my $ball = '../ecore';

my $config_file = config_file();

my @config_args;

push @config_args, file => $config_file if -e $config_file;

my $skip = skip_cond();

Everything::Test::Ecore::Install->SKIP_CLASS( $skip ) if $skip;

my $config = Everything::Config->new( @config_args );

my $tests = Everything::Test::Ecore::Install->new( nodeball => abs_path( $ball ), config => $config );

local *Everything::logErrors;
*Everything::logErrors = sub { warn "@_" };

$tests->runtests;
