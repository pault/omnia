#!/usr/bin/perl

use strict;
use warnings;

use Everything::NodeBase;
use Everything::Storage::Nodeball;
use Data::Dumper;
use Everything::CmdLine qw/get_options usage_options make_nodebase/;
use Carp;

$SIG{__WARN__} = \&Carp::cluck;
my $opts = get_options();


my $ball = Everything::Storage::Nodeball->new( nodeball => $ARGV[0] );

my ($no_ME, $no_nb );
if ( ( $no_ME, $no_nb ) = $ball->check_nodeball_integrity ) {
    print Dumper $no_ME, $no_nb;
} else {
    print "\nAll OK\n\n";
}


