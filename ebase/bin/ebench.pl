#!/usr/bin/perl -w

use strict;
use Benchmark;
use Everything;

##############################################################
#
#	ebench.pl -- a program to benchmark the Everything system
#
#############################################################

my $database = shift;
$database or die "usage: ebench.pl database_name [count]";
my $count = shift;
$count ||= 10000;

sqlConnect $database;
loadTypes;

my $limit;
($limit) = Everything::sqlSelect('MAX(node_id)', 'node');

sub getNodeNoCache {
	my $node_id = int (rand ($limit));
	my ($NODE) = getNodeById $node_id; 
	delete $Everything::NODES{$node_id};
}

sub getNodeCache {
	my $node_id = int (rand ($limit));
	my ($NODE) = getNodeById $node_id; 
}
print "There are $limit nodes in the database\n";

my $t = timethese($count, { cache_on => 'getNodeNoCache', cache_off => 'getNodeCache'});

