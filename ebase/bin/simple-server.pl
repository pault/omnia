#!/usr/bin/perl

use strict;
use warnings;
use Carp qw/croak confess cluck/;
use Everything::CmdLine qw/abs_path get_options make_nodebase/;
use Everything::Test::Ecore::SimpleServer;

$SIG{__DIE__} =\&confess;
#$SIG{__WARN__} =\&cluck;

$|++;

my $opts = get_options( undef, [ 'listenport=i'] );
$$opts{type} ||= 'sqlite';
my $server = Everything::Test::Ecore::SimpleServer->new( { mod_perlInit => ["$$opts{database}:$$opts{user}:$$opts{password}:$$opts{host}", { dbtype => $$opts{type}} ], listenport => $$opts{'listenport'} } );
$server->run;
