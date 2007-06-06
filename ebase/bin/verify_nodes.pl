#!/usr/bin/perl

use strict;
use warnings;

use Everything::NodeBase;
use Everything::Storage::Nodeball;
use Everything::XML::Node;
use Text::Reform;
use Everything::CmdLine qw/get_options usage_options make_nodebase/;
use Carp;

my $opts = get_options();

usage_options(
"\nUsage:\n\n\t$0 [options] <nodeball path>\n\nThe <nodeball path> argument is the path to the file of the nodeball we are verifying. \n\n"
) unless @ARGV >= 1;

my $nb = make_nodebase($opts);

die "No Nodebase" unless $nb;

my $ball =
  Everything::Storage::Nodeball->new( nodebase => $nb, nodeball => $ARGV[0] );

my ( $in_nodeball, $in_nodebase, $diffs ) = $ball->verify_nodes;

if ( !@$in_nodeball && !@$in_nodebase && !@$diffs ) {
    print "OK\n";
    exit;
}

my $head_form =
  "            ||||||||||||||||||||||||||||||||||||||||||||||||||||           ";
my $head_column =
"[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[    [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[";
my $column =
"ball\> [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[    base\> [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[";

print form $head_form, "The following nodes are not in the Nodebase"
  if @$in_nodeball;

foreach (@$in_nodeball) {
    print form $column,
      sprintf( "Title: '%s' Type: '%s'\n", $_->get_title, $_->get_nodetype ),
      "Not in nodebase.";
}
print "\n\n";

print form $head_form, "The following nodes are not in the Nodeball"
  if @$in_nodebase;

foreach (@$in_nodebase) {
    print form $column,    "Not in nodeball",
      sprintf( "Title: '%s' Type: '%s'\n",
        $_->get_title, $_->get_type->get_title );
}

print "\n\n";


foreach (@$diffs) {

    my $diff    = $$_[1];
    my $xmlnode = $$_[0];

    print form $head_form, "For Node "
      . sprintf( "Title: '%s' Type: '%s'\n",
        $xmlnode->get_title, $xmlnode->get_nodetype );

    foreach ( grep { $_->is_attribute || $_->is_var } @$diff ) {

        my $att_name = $_->get_name || '';

        my $attribute_type = $_->is_attribute ? 'attribute' : 'var';

        if ( !$_->is_noderef ) {

            my $xmlcontent = $_->get_xmlnode_content || '';
            my @xmllines = split /\n/, $xmlcontent;

            my @baselines = split /\n/, $_->get_nb_node_content || '';
            print form $head_form, "$attribute_type '$att_name'\n";

            print form $head_column,
              "In the Nodeball\n$attribute_type '$att_name' is:",
              "In the Nodebase\n$attribute_type '$att_name' is:";
            print "\n\n";
            print form $column, \@xmllines, \@baselines;

            print "\n\n";
        }
        else {
            my $name = $_->get_xmlnode_ref_name || '';
            my $type = $_->get_xmlnode_ref_type || '';

            my $nb_name = $_->get_nb_node_ref_name || '';
            my $nb_type = $_->get_nb_node_ref_type || '';

            print form $head_form, "$attribute_type $att_name";
            print form $column,    "references '$name' of type '$type'",
              "references '$nb_name' of type '$nb_type'\n\n";
            print "\n\n";
        }
    }

    foreach ( grep { $_->is_groupmember } @$diff ) {

        my $in_nodeball = $_->get_xmlnode_additional;
        my $in_nodebase = $_->get_nb_node_additional;

        foreach (@$in_nodeball) {

            print form $head_form,
              sprintf( "A node '%s' of type '%s' is:", @$_{ 'title', 'type' } );
            print form $column, "Is in the nodeball", "Not in the nodebase";
        }

        foreach (@$in_nodebase) {

            print form $head_form,
              sprintf( "A node '%s' of type '%s' is:",
                $_->get_title, $_->get_type->get_title );
            print form $column, "Not in the nodeball", "Is in the nodebase";
        }

        print "\n\n";
    }

}
