package Everything::Node::FormObject;

#############################################################################
#   Everything::Node::FormObject
#		Package the implements the base FormObject functionality.
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
#		This generates the HTML necessary to make a form item on the
#		page.  This is the base implementation of a form object.  It
#		just sets up some data fields on this object in preparation
#		for the derived classes to do something interesting.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this textfield is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this textfield is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#
#	Returns
#		The generated HTML for this object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name) =
		getParamArray("query, bindNode, field, name", @_); 

	return $this->genBindField($query, $bindNode, $field, $name);
}


#############################################################################
#	Sub
#		cgiVerify
#
#	Purpose
#		This is called by the system when it is attempting to update nodes.
#		cgiVerify() is responsible for examining the CGI params associated
#		with it and verifying that the USER has permission to update the
#		node it is bound with.
#
#	Parameters
#		$query - the CGI object that contains the incoming CGI parameters
#		$name - the $name passed to genObject() so this can reconstruct
#			the fields that it generated and retrieve the needed data
#		$USER - the user attempting to do this update, for authorization.
#
#	Returns
#		A hashref that contains the following fields:
#			node - the ID of the node that this object would update if it is
#				bound.
#			failed - if the verify fails for any reason, this should
#				be filled with a text string explaining the reason
#				why the verify failed.  ie: "User does not have permission"
#
sub cgiVerify
{
	my ($this, $query, $name, $USER) = @_;

	my $bindNode = $this->getBindNode($query, $name);
	my $result = {};

	if($bindNode)
	{
		$$result{node} = $bindNode->getId();
		$$result{failed} = "User does not have permission"
			unless($bindNode->hasAccess($USER, 'w'));
	}
	
	return $result;
}


#############################################################################
#	Sub
#		cgiUpdate
#
#	Purpose
#		This is called by the system if all cgiVerify()'s have succeeded
#		and it is time to update the node(s).  This will only be called
#		if this object is bound to a node that it needs to update.
#		This default implementation just assigns the value of the CGI
#		object to the bound node{field}.
#
#	Parameters
#		$query - the CGI object that contains the incoming CGI parameters.
#			This is used to find any associated parameters that this
#			object created.
#		$name - the $name passed to genObject() so this can reconstruct
#			the fields that it generated and retrieve the needed data
#		$NODE - the node object that this field is bound to (as reported by
#			cgiVerify).  This is the node that all updates should be made
#			to.  NOTE!  Do not call update() on this node!  That will be
#			handled by the system.
#		$overrideVerify - If (for some reason) this should not check to
#			to see if the nodetype would allow us to update this field.
#			Basically, opUpdate() in HTML.pm will pass true if the user
#			doing this update is a god, and therefore should have complete
#			access to everything.  True if we should allow anything, false
#			if we need to check with the nodetype.
#
#	Returns
#		1 (true) if successful, 0 (false) otherwise
#
sub cgiUpdate
{
	my ($this, $query, $name, $NODE, $overrideVerify) = @_;
	my $value = $query->param($name);
	my $field = $this->getBindField($query, $name);

	# Make sure this is not a restricted field that we cannot update
	# directly.
	return 0 unless($overrideVerify or $NODE->verifyFieldUpdate($field));

	$value ||= "";

	$$NODE{$field} = $value;

	return 1;
}


#############################################################################
#	Sub
#		genBindField
#
#	Purpose
#		If this form object is bound to a node and field, we generate a
#		hidden form field that contains the information we need to know
#		what node/field we are bound to on CGI post.
#
#	Parameters
#		$query - the CGI object used to generate this tag
#		$bindNode - a node ref of the node that we are to bind on
#		$field - the name of the field that we are bound to.  This can be
#			more than just a field name of the form object needs more info.
#		$name - the name of the HTML form object so that this knows what
#			we are associated with and gives us a unique name
#
#	Returns
#		The HTML for this hidden form field
#
sub genBindField
{
	my ($this, $query, $bindNode, $field, $name) = @_;

	return "" unless($bindNode);

	my $order = $$this{updateExecuteOrder};
	$order ||= 50;
	return $query->hidden(
		-name => 'formbind_' . $$this{type}{title} . '_' . $name,
		-value => "$order:$$bindNode{node_id}:$field", -override => 1);
}


#############################################################################
#	Sub
#		getBindNode
#
#	Purpose
#		Get the node that this object is bound to.  This is the same
#		node that was passed to genObject() as $bindNode
#
#	Paramters
#		$query - CGI object so we can go revieve our info
#		$name - the name of this form object (the same $name passed to
#			genObject)
#
#	Returns
#		The node object if successful, undef otherwise
#
sub getBindNode
{
	my ($this, $query, $name) = @_;

	my $value = $query->param('formbind_' . $$this{type}{title} . '_' . $name);
	return undef unless($value);

	$value =~ /^\d\d\:(.*?)\:/;

	return $$this{DB}->getNode($1);
}


#############################################################################
#	Sub
#		getBindField
#
#	Purpose
#		Get the field that this object is bound to.  This is essentially
#		the '$field' data passed to genObject()
#
#	Parameters
#		$query - the CGI object so we can access our parameters
#		$name - the name of the form object.  The same $name that was
#			passed to genObject
#
#	Returns
#		The field data if it exists.  undef otherwise.
#
sub getBindField
{
	my ($this, $query, $name) = @_;

	my $param = 'formbind_' . $$this{type}{title} . '_' . $name;
	my $value = $query->param($param);
	return undef unless($value);

	my $field;
	$value =~ /^\d\d\:.*?\:(.*)/;
	$field = $1;

	return $field;
}


#############################################################################
# End of package
#############################################################################

1;
