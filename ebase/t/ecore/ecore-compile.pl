#!/usr/bin/perl

use Everything::NodeBase;
use Everything::CmdLine qw/get_options abs_path make_nodebase/;
use Everything::Test::Ecore::Compile;
use Test::Harness::Straps '0.26';
use IO::Tee;
use Carp qw/cluck confess croak/;
use CGI;
use strict;
use warnings;

$SIG{__DIE__} = \&confess;

my $opts = get_options('', ['log=s']);

my $nb = make_nodebase($opts);

my $tests = Everything::Test::Ecore::Compile->new;

$tests->{nodebase} = $nb;

my $builder   = $tests->builder;

my $cfh;
my $capture;
open ($cfh, '>', \$capture);

my $tee = IO::Tee->new( \*STDOUT, $cfh);
$builder->output( $tee );

$tests->runtests;

my $strap = Test::Harness::Straps->new;

my @lines = split("\n", $capture);
my %results = $strap->analyze( $0, \@lines );

my @failed = ();
my $details = $results{details};
foreach (0..$#$details) {
    push @failed, $_ + 1 unless $$details[$_]->{ok};
}

printf <<ENDREPORT, $0, $results{max}, $results{seen}, $results{ok}, $results{skip}, $results{todo}, $results{bonus};

Test Report for %s:

    Expected tests:         %d
    Tests run:              %d
    Tests passed:           %d
    Tests skipped:          %d
    TODO tests:             %d
    TODO passed:            %d

ENDREPORT

print "Failed tests: @failed\n" if @failed;

exit;
