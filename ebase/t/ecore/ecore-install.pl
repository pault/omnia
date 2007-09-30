#!/usr/bin/perl

use Everything::NodeBase;
use Everything::Nodeball;
use Everything::Install;
use Everything::Test::Ecore::Install;
use Everything::CmdLine qw/get_options abs_path/;
use File::Copy;
use File::Spec;
use Test::More;
use DBI;
use Carp qw/cluck confess croak/;
use File::Temp qw/tempfile/;


use strict;
use warnings;
#$SIG{__DIE__} = \&confess;


my $opts = get_options( usage(), [ 'db_rootuser=s', 'db_rootpassword=s' ]);


my $ball = $ARGV[0];

#usage() unless $ball;

my $tests = Everything::Test::Ecore::Install->new;

$tests->{nodeball} = abs_path( $ball );

my $installer = Everything::Install->new;

$installer->set_nodeball( Everything::Storage::Nodeball->new( nodeball => abs_path( $ball ) ) );
$$opts{ type } ||= 'sqlite';
$installer->create_storage( $opts );

my $nb = $installer->get_nodebase;

$tests->{nb}           = $nb;
$tests->{db_type}      = $$opts{ type };
$tests->{installer} = $installer;

$tests->runtests;

my $tests_run = $tests->expected_tests;
my $builder   = $tests->builder;

my @tests = $builder->summary;

my @failed;
foreach ( 0 .. $#tests ) {
    push @failed, $_ + 1 unless $tests[$_];
}

print "\nNumber of Tests run: "
  . scalar(@tests)
  . " of $tests_run expected tests";

if (@failed) {
    print "\nList of failed tests: @failed";
}
else {
    print "\nAll tests succesful.";
}

print "\n";

exit;

sub usage {

    "\nUsage:\n\t$0 [options] <path to nodeball>\n\n" .
    "Takes the following addtional options:
      db_rootuser: root user of the db
      db_rootpassword: root db password";

}
