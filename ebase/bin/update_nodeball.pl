#!/usr/bin/perl

use strict;
use warnings;

use Everything::NodeBase;
use Everything::Storage::Nodeball;
use Everything::XML::Node;
use Everything::CmdLine qw/get_options usage_options make_nodebase/;
use Carp;

$SIG{__WARN__} = \&Carp::cluck;
$SIG{__DIE__} = \&Carp::confess;
my $opts = get_options();

usage_options("\nUsage:\n\n\t$0 [options] <nodeball path>\n\nThe <nodeball path> argument is the path to the file of the nodeball we are updating from. \n\n[filepath] is optional.") unless @ARGV >= 1;


my $nb = make_nodebase( $opts );

die "No Nodebase" unless $nb;

my $ball = Everything::Storage::Nodeball->new( nodebase => $nb, nodeball =>  $ARGV[0]);

$Everything::DB = $nb;

my $update_node_sub = sub {

    my ( $nodeball, $node ) =@_;

    my $handle_conflict_sub = sub {

	my ( $nodeball, $newnode ) = @_;

	warn "There is a conflict with node " . $newnode->get_title . " of type " . $newnode->type_title . " not updating."

    };

    $nodeball->update_node_to_nodebase( $node, $handle_conflict_sub );

};



$ball->update_nodebase_from_nodeball( undef, $update_node_sub );
