package Everything::Node::setting;

#############################################################################
#   Everything::Node::setting
#       Package the implements the base functionality for setting
#
#   Copyright 2000 - 2003 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything::Security;
use Everything::Util;
use Everything::XML;
use XML::DOM;

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

	return;
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
#		$DOC - an XML::DOM::Document object that this field belongs to
#		$field - the field of this node that needs to be exported as XML
#		$indent - String that contains the amount that this will be indented
#			(used for formatting purposes)
#
#	Returns
#		The XML::DOM::Element that represents this field
#
sub fieldToXML
{
	my ($this, $DOC, $field, $indent) = @_;
	$indent ||= '';

	if($field eq "vars")
	{
		my $VARS = new XML::DOM::Element($DOC, "vars");
		my $vars = $this->getVars();
		my @raw = keys %$vars;
		my @vars = sort { $a cmp $b } @raw;
		my $tag;
		my $indentself = "\n" . $indent;
		my $indentchild = $indentself . "  ";

		foreach my $var (@vars)
		{
			$VARS->appendChild(new XML::DOM::Text($DOC, $indentchild));
			$tag = genBasicTag($DOC, "var", $var, $$vars{$var});
			$VARS->appendChild($tag);
		}

		$VARS->appendChild(new XML::DOM::Text($DOC, $indentself));

		return $VARS;
	}
	else
	{
		return $this->SUPER();
	}
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

		# On import, this could start out as nothing and we want it to be
		# at least defined to empty string.  Otherwise, we will get warnings
		# when we call getVars() below.
		$$this{vars} ||= "";
	
		my $vars = $this->getVars();

		foreach my $child (@childFields)
		{
			next if($child->getNodeType() == XML::DOM::TEXT_NODE());

			my $PARSE = parseBasicTag($child, 'setting');

			if(exists $$PARSE{where})
			{
				$$vars{$$PARSE{name}} = -1;

				# The where contains our fix
				push @fixes, $PARSE;
			}
			else
			{
				$$vars{$$PARSE{name}} = $$PARSE{$$PARSE{name}};
			}
		}
	
		$this->setVars($vars);
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

	return unless $FIX and UNIVERSAL::isa( $FIX, 'HASH' );
	for my $required (qw( fixBy field where ))
	{
		return unless exists $FIX->{$required};
	}

	unless ($FIX->{fixBy} eq 'setting')
	{
		$this->SUPER();
		return;
	}

	my $vars = $this->getVars();

	my $where = Everything::XML::patchXMLwhere($FIX->{where});
	my $TYPE  = $where->{type_nodetype};
	my $NODE  = $this->{DB}->getNode($where, $TYPE);

	unless ($NODE)
	{
		Everything::logErrors('', 
			"Unable to find '$FIX->{title}' of type '$FIX->{type_nodetype}'\n" .
			"for field '$FIX->{field}' in '$this->{title}'" .
			"of type '$this->{nodetype}{title}'"
		) if $printError;
		return $FIX;
	}

	$vars->{ $FIX->{field} } = $NODE->{node_id};

	$this->setVars($vars);

	return;
}

sub getNodeKeepKeys
{
	my ($this) = @_;

	my $nodekeys      = $this->SUPER();
	$nodekeys->{vars} = 1; 

	return $nodekeys;
}

# vars are preserved upon import
sub updateFromImport
{
	my ($this, $NEWNODE, $USER) = @_;

	my $V    = $this->getVars;
	my $NEWV = $NEWNODE->getVars;

	@$NEWV{keys %$V} = values %$V;

	$this->setVars($NEWV);
	$this->SUPER();
}


#############################################################################
# End of package
#############################################################################

1;
