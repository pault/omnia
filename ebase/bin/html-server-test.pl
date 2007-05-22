#!/usr/bin/perl

use strict;
use warnings;
use Carp qw/croak confess cluck/;
use Everything::CmdLine qw/abs_path get_options make_nodebase/;
use Everything::Test::Ecore::SimpleServer;
use Test::More;
use WWW::Mechanize;
use HTML::Lint;

$SIG{__DIE__} =\&confess;
#$SIG{__WARN__} =\&cluck;

$|++;

my $opts = get_options( undef, [ 'listenport=i'] );
my $nb = make_nodebase( $opts );

my $nodes = $nb->getNodeWhere();

my $num_nodes = scalar  @$nodes;

plan tests => $num_nodes * 2;

$$opts{type} ||= 'sqlite';
$$opts{listenport} ||= 8080;

my $server = Everything::Test::Ecore::SimpleServer->new( { mod_perlInit => ["$$opts{database}:$$opts{user}:$$opts{password}:$$opts{host}", { dbtype => $$opts{type}} ], listenport => $$opts{'listenport'} } );

my $pid = $server->background;

croak "Server won't start" unless $pid;

my $base_url = "http://localhost:$$opts{'listenport'}";

my $mech = WWW::Mechanize->new;

for (1..$num_nodes) {
    my $url =  $base_url . "?node_id=$_";
    my $r = $mech->get ( $url );
    my $lint = HTML::Lint->new;
    ok ($r->is_success, "...successfully retrieved node id $_.") || diag "Error fetching $url\n" . $r->status_line;
    $lint->parse( $r->content );
    is( scalar $lint->errors, 0, "...the HTML produced for node id $_ has no errors.")
      ||
	do {
	    diag $_->as_string foreach $lint->errors;
	    diag $r->content;
	    exit;
	};
}

kill 9, $pid;
