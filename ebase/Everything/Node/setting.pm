package Everything::Node::setting;

#############################################################################
#   Everything::Node::setting
#       Package the implements the base functionality for setting
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything::Node::node;
use Everything::Security;
use Everything::Util;
use Everything::XML;

#############################################################################
sub construct
{
	my ($this) = @_;

	# Just do what our parent does...
	$this->SUPER();
	
	return 1;
}


#############################################################################
sub destruct
{
	my ($this) = @_;

	$this->SUPER();
}


#############################################################################
#	Sub
#		getVars
#
#	Purpose
#		All setting nodes join on the setting table.  The vars field in
#		that table contains a string that is an '&' delimited hash.  This
#		function will grab that string and construct a perl hash out of it.
#
sub getVars 
{
	my ($this) = @_;

	return $this->getHash("vars");
}


#############################################################################
#	Sub
#		setVars
#
#	Purpose
#		This takes a hash of variables and assigns it to the 'vars' of the
#		given node.  NOTE!  This will not update the node.  It will only
#		update the local version of the vars for this node instance.  If
#		you want to update the node in the database, you will need to
#		call update on this node.
#
#	Parameters
#		$varsref - the hashref to get the vars from
#
#	Returns
#		Nothing
#
sub setVars
{
	my ($this, $vars) = @_;

	$this->setHash($vars, "vars");

	return undef;
}


#############################################################################
sub hasVars
{
	return 1;
}


#############################################################################
#	Sub
#		fieldToXML
#
#	Purpose
#		This is called when the node is being exported to XML.  The base
#		node knows how to export fields to XML, but if the node contains
#		some more complex data structures, that nodetype needs to export
#		that data structure itself.  In this case, we have a settings
#		field (hash) that needs to get exported.
#
#	Parameters
#		$XMLGEN - an XML::Generator object used to generate the XML
#		$field - the field of this node that needs to be exported as XML
#
#	Returns
#		The XML for the given field
#
sub fieldToXML
{
	my ($this, $XMLGEN, $field) = @_;
	my $xml;

	if($field eq "vars")
	{
		my $vars = $this->getVars();
		my @raw = keys %$vars;
		my @vars = sort { $a cmp $b } @raw;

		foreach my $var (@vars)
		{
			$xml .= genBasicTag($XMLGEN, "var", $var, $$vars{$var});
			$xml .= "\n";
		}

		$xml = indentXML($xml);

		$xml = $XMLGEN->vars({}, "\n" . $xml);
	}
	else
	{
		$xml = $this->SUPER();
	}

	return $xml;
}


#############################################################################
sub xmlTag
{
	my ($this, $TAG) = @_;
	my $tagname = $TAG->getTagName();

	if($tagname eq "vars")
	{
		my @fixes;
		my @childFields = $TAG->getChildNodes();

		foreach my $child (@childFields)
		{
			next if($child->getNodeType() == XML::DOM::TEXT_NODE());

			my $PARSE = parseBasicTag($child, 'setting');

			my $vars = $this->getVars();
			if(exists $$PARSE{where})
			{
				$$vars{$$PARSE{name}} = -1;

				# The where contains our fix
				push @fixes, $$PARSE{where};
			}
			else
			{
				$$vars{$$PARSE{name}} = $$PARSE{$$PARSE{name}};
			}

			$this->setVars($vars);
		}
	
		return \@fixes;
	}
	else
	{
		return $this->SUPER();
	}
}


#############################################################################
sub applyXMLFix
{
	my ($this, $FIX, $printError) = @_;

	if($$FIX{fixBy} ne "setting")
	{
		$this->SUPER();
		return;
	}

	my $vars = $this->getVars();
	
	my $NODE = $$this{DB}->getNode($$FIX{title}, $$FIX{type_nodetype});

	unless($NODE)
	{
		print "Error! Unable to find '$$FIX{title}' of type '$$FIX{type_nodetype}'".
			"\nfor field $$FIX{field}\n" if($printError);
		return $FIX;
	}

	$$vars{$$FIX{field}} = $$NODE{node_id};

	$this->setVars($vars);

	return undef;
}


#############################################################################
# End of package
#############################################################################

1;

