#!/usr/bin/perl

use Everything::CmdLine qw/config/;
use Everything::Install;
use Everything::Storage::Nodeball;
use strict;
use warnings;

my $nb = config()->nodebase;

my $s = Everything::Storage::Nodeball->new( nodeball => $ARGV[0], nodebase => $nb );

my $nodeball_vars = $s->nodeball_vars;
my $nodeball_title = $nodeball_vars->{title};

if ( $nb->getNode( $nodeball_title, 'nodeball' ) ) {
    die "Can't install nodeball, $nodeball_title, located at $ARGV[0], it already exists in nodebase, " . $nb->{dbname};
}

my $i = Everything::Install->new( nodeball => $s );
$i->set_nodebase( $nb );
$i->install_nodes;
