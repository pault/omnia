package Everything::Node::nodetypemenu;

#############################################################################
#   Everything::Node::nodetypemenu
#		Package the implements the base nodetypemenu functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;


#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this nodetypemenu
#		form object. 
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this nodetypemenu is to be bound to a field
#			on a node.
#		$field - the field on the node that this nodetypemenu is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$omitutil - Omit "utility" types.  Utility types are those that
#			inherit from "utility".  All types that derive from utilty
#			*cannot* be instantiated.  utility types exist for the sole
#			purpose of providing methods.  They are not nodes in the database.
#			You may want to turn this on if you want a menu to select types
#			when creating new nodes.  Since nodes of "utility" types cannot
#			be created, you will probably want to omit them.
#		$USER - used for authorization.  If given, the menu will only
#			show the types that the user has permission to create.
#		$none - (optional) true if the menu should contain an option of
#			'None' (with value of $none).
#		$inherit - (optional) true if the menu should contain an option of
#			'Inherit' (with value of $inherit).
#
#
#	Returns
#		The generated HTML for this nodetypemenu object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $omitutil, $USER, $none,
		$inherit, $inherittxt) = getParamArray(
		"query, bindNode, field, name, omitutil, USER, none, " .
		"inherit, inherittxt", @_);

	$omitutil ||= 0;
	$USER ||= -1;

	$$this{omitutil} = $omitutil;
	my $html = $this->SUPER($query, $bindNode, $field, $name, 'nodetype',
		'AUTO', $USER, 'c', $none, $inherit);

	return $html;
}


#############################################################################
sub addTypes
{
	my ($this, $type, $USER, $perm, $none, $inherit) = @_;
	
	$USER ||= -1;
	$perm ||= 'r';
	$this->addHash({"None" => $none}, 1) if(defined $none);
	$this->addHash({"Inherit" => $inherit}, 1) if(defined $inherit);

	my @RAWTYPES = $$this{DB}->getAllTypes();
	my %types;
	my $omitutil = $$this{omitutil};
	my @SORTED;
	my @TYPES;

	@SORTED = sort { $$a{title} cmp $$b{title} } @RAWTYPES;

	foreach my $TYPE (@SORTED)
	{
		next unless($TYPE->hasTypeAccess($USER, 'c'));
		next if($omitutil && $TYPE->derivesFrom("utility"));
		push @TYPES, $TYPE;
	}

	my $MENU = $this->createTree(\@TYPES, 0);
	my %labels;
	my @array;
	
	foreach my $item (@$MENU)
	{
		$labels{$$item{label}} = $$item{value};
		push @array, $$item{value};
	}

	$this->addArray(\@array);
	$this->addLabels(\%labels, 1);	

	return 1;
}


#############################################################################
sub createTree
{
	my ($this, $types, $current) = @_;
	my $type;
	my @list;

	foreach $type (@$types)
	{
		next if($$type{extends_nodetype} ne $current);

		my $tmp = { 'label' => " + " . $$type{title},
			'value' => $$type{node_id} };
		push @list, $tmp;

		my $sub;
		$sub = $this->createTree($types, $$type{node_id});

		foreach my $item (@$sub)
		{
			$$item{label} = " - -" . $$item{label};
		}

		push @list, @$sub;
	}

	return \@list;
}

#############################################################################
# End of package
#############################################################################

1;


