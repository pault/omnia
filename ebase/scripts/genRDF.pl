#!/usr/bin/perl 

########################################################################
#
#	genRDF.pl  the most phat RDF generatin' in da house!
#
#	Nathan Oostendorp 2000
#
#	This script generates .RDF files for an Everything site -- so that you
#	can be featured as a "channel" on Netcenter or a Slashbox on Slashdot
#
#	first, edit the script (change your @types, initEverything, and numnodes)
#	then test it out (the script prints to STDOUT)
#	then create a crontab entry to run it at regular intervals, and have it
#	redirect to "headlines.rdf" in your DocumentRoot directory.  
#	
#	Presto!  Meta-data!

use Everything;
use Everything::HTML;
use Everything::XML;
use strict;
use XML::Generator;


initEverything 'everything';
my @types = ("document");
#these are the nodetypes you want it to list

my $numnodes = 12;
#number of nodes that you want to export
#NOTE: these should be put in a setting before release



my $XMLGEN = new XML::Generator;
my $SNODE = getNode 'system settings', 'setting';
my $SETTINGS = getVars $SNODE;


sub genTag { Everything::XML::genTag(@_); }


#first the channel tag
my $doc = ""; 

my $url = $$SETTINGS{site_url};

$url .= "/" unless $url =~ /\/$/;

$doc .= $XMLGEN->channel(
	"\n\t".genTag("title", $$SETTINGS{site_name}) .
	"\t".genTag("link", $url) .
	"\t".genTag("description", $$SETTINGS{site_description})
	)."\n";

foreach (@types) {
	$_ = getId(getType($_));
}
my $wherestr = $DB->genWhereString({type_nodetype => \@types});
my $csr = $DB->sqlSelectMany("*", "node", $wherestr, "ORDER BY createtime DESC LIMIT $numnodes");

while (my $N = $csr->fetchrow_hashref) {
	$doc .= $XMLGEN->item(
		"\n\t".genTag("title", $$N{title}) .
		"\t".genTag("link", $url."?node_id=".$$N{node_id})
	)."\n";
}
$csr->finish;
print $XMLGEN->RDF("\n".$doc);

