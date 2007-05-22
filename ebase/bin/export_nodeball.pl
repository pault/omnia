#!/usr/bin/perl

use strict;
use warnings;

use Everything::NodeBase;
use Everything::Storage::Nodeball;
use Everything::XML::Node;
use Everything::CmdLine qw/get_options usage_options/;
use Carp;

$SIG{__WARN__} = \&Carp::cluck;
my $opts = get_options();

usage_options("\nUsage:\n\n\t$0 [options] <nodeball title> [filepath]\n\nThe <noeball title> argument is the name of the nodeball to be exported. \n\n[filepath] is optional. It is either the filename to be exported to or a directory.  If it is omitted Everything will construct a file name based on the nodeball name and version number.\n\n") unless @ARGV >= 1;


$$opts{type} ||= 'sqlite';
my $nodebase_string =  join ':', $$opts{database}, $$opts{user}, $$opts{password}, $$opts{host};
my $nb = Everything::NodeBase->new(
    $nodebase_string,
    1, $$opts{type}
);

die "Can't connect to nodebase $nodebase_string of type $$opts{type}" unless $nb;

my $ball = Everything::Storage::Nodeball->new( nodebase => $nb );

if ( -d $ARGV[1]) {
    $ball->export_nodeball_to_directory( $ARGV[0], $ARGV[1] );
} elsif ($ARGV[1]) {
    $ball->export_nodeball_to_file( $ARGV[0], $ARGV[1] );
} else {
    $ball->export_nodeball_to_file( $ARGV[0] );
}

