#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 28;

my $node = FakeNode->new();

# fake this up -- imported from Everything::NodeBase
local *Everything::Node::node::DB;
*Everything::Node::node::DB = \$node;

my $result;
{
	$INC{'DBI.pm'} = $INC{'Everything.pm'} =
		$INC{'Everything/NodeBase.pm'} = $INC{'Everything/XML.pm'} = 1;

	local (*DBI::import, *Everything::import, *Everything::NodeBase::import,
		*Everything::XML::import);

	my %import;
	*DBI::import = *Everything::import = *Everything::NodeBase::import = 
		*Everything::XML::import = sub {
			$import{+shift}++;
	};

	use_ok( 'Everything::Node::node' );
	is( scalar keys %import, 4, 
		'Everything::Node::node should use several packages' );
}


# construct()
ok( construct(), 'construct() should return true' );

# destruct()
ok( destruct(), 'destruct() should return true' );

# insert()

# update()

# nuke()

# getNodeKeys()

# isGroup()
ok( ! isGroup(), 'isGroup() should return false' );

# getFieldDatatype()
$node->{a_field} = 111;
is( getFieldDatatype($node, 'a_field'), 'noderef',
	'getFieldDatatype() should mark node references as "noderef"' );

$node->{b_field} = 'foo';
$node->{cfield} = 112;
is( getFieldDatatype($node, 'b_field'), 'literal_value',
	'... but references without ids are literal' );
is( getFieldDatatype($node, 'bfield'), 'literal_value',
	'... and so are fields without underscores' );

# hasVars()
ok( ! hasVars(), 'hasVars() should return false' );

# clone()

# fieldToXML()
{
	local *Everything::Node::node::genBasicTag;

	my @gbt;
	*Everything::Node::node::genBasicTag = sub {
		push @gbt, [ @_ ];
		return 'tag';
	};

	$node->{afield} = 'thisfield';
	is( fieldToXML($node, $node, 'afield'), 'tag',
		'fieldToXML() should return an XML tag element' );
	is( scalar @gbt, 1, '... and should call genBasicTag()' );
	is( join(' ', @{ $gbt[0] }), "$node field afield thisfield", 
		'... with the correct arguments' );
}

# xmlTag()

# xmlFinal()

# applyXMLFix()

# commitXMLFixes()
commitXMLFixes($node);
is( join(' ', @{ $node->{_calls}[-1] }), 'update -1 nomodify',
	'commitXMLFixes() should call update() on node' );

# getIdentifyingFields()
is( getIdentifyingFields($node), undef, 
	'getIdentifyingFields() should return undef' );

# updateFromImport()

# conflictsWith()

# getNodeKeepKeys()
$result = getNodeKeepKeys($node);
isa_ok( $result, 'HASH', 'getNodeKeepKeys() should return a hash reference' );
foreach my $class (qw( author group other guest )) {
	ok( $result->{"${class}access"}, "... and should contain $class access" );
	ok( $result->{"dynamic${class}_permission"}, 
		"... and $class permission keys" );
}
ok( $result->{loc_location}, '... and location key' );

# verifyFieldUpdate()

# getRevision()

# logRevision()

# undo()

# canWorkspace()
my $ws = $node->{type} = { canworkspace => 1};

ok( Everything::Node::node::canWorkspace($node), 
	'canWorkspace() should return true if nodetype can be workspaced' );

$ws->{canworkspace} = 0;
ok( ! canWorkspace($node), '... and false if it cannot' );

$ws->{canworkspace} = -1;
$ws->{derived_canworkspace} = 0;
ok( ! canWorkspace($node), '... or false if inheriting and parent cannot' );
$ws->{derived_canworkspace} = 1;
ok( canWorkspace($node), '... and true if inheriting and parent can workspace');

# getWorkspaced()

# updateWorkspaced()

sub AUTOLOAD {
    return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::Node::node::$AUTOLOAD";

	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}
