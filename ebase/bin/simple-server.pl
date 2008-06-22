#!/usr/bin/perl

use strict;
use warnings;
use Carp qw/croak confess cluck/;
use Everything::CmdLine qw/abs_path get_options make_nodebase config/;
use Everything::Test::Ecore::SimpleServer;

$SIG{__DIE__} = \&confess;

#$SIG{__WARN__} =\&cluck;

$|++;

my $opts = get_options( undef, ['listenport=i'] );
$$opts{type} ||= 'sqlite';

my $config = config($opts);

my $server = Everything::Test::Ecore::SimpleServer->new( {
    config     => $config,
    listenport => $$opts{'listenport'}
}
);
$server->run;
