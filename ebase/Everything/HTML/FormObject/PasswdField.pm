package Everything::HTML::FormObject::PasswdField;

#############################################################################
#   Everything::HTML::FormObject::PasswdField
#		Package the implements the base PasswdField functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;

use Everything::HTML::FormObject;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject");

#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this PasswdField
#		form object.
#
#		NOTE! The password fields will always be empty.  This is to
#		prevent the password showing up in the HTML and in the cache
#		If the user submits the page with the password and confirmation
#		fields blank, this will not update the bound field.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this PasswdField is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this PasswdField is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$vertical - true if the two fields should be on stacked vertically,
#			false if they should be side-by-side horizontally.
#
#	Returns
#		The generated HTML for this PasswdField object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $vertical, $labels) =
		getParamArray(
		"query, bindNode, field, name, vertical, labels", @_);

	my $html = $this->SUPER::genObject(@_) . "\n";
	my $default = "";
	$default = $$bindNode{$field} if(ref $bindNode);
	$vertical ||= 1;
	$labels ||= 0;

	$html .= "<table border=0>\n";
	$html .= "<tr>\n";
	$html .= "<td>Password:</td>\n" if($labels);
	
	$html .= "<td>";
	$html .= $query->password_field(-name => $name, -default => '',
		-size => 10, -maxlength => 20, -override => 1);
	$html .= "</td>\n";

	$html .= "</tr><tr>\n" if($vertical);

	$html .= "<td>Re-Confirm:</td>\n" if($labels);
	$html .= "<td>";
	$html .= $query->password_field(-name => $name . '_confirm',
		-default => '', -size => 10, -maxlength => 20,
		-override => 1);
	$html .= "</td></tr></table>";
	
	return $html;
}


#############################################################################
#	Sub
#		cgiVerify
#
#	Purpose
#		This is called by the system when it is attempting to update nodes.
#		We need to verify that the password and the confirmation are the
#		same, and the password is at least 4 characters long.
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
	
	my $passwd1 = $query->param($name);
	my $passwd2 = $query->param($name . '_confirm');

	if($passwd1 ne $passwd2)
	{
		$$result{failed} = "Password and confirmation are different!";
	}
	elsif(length($passwd1) < 4 && length($passwd1) > 0)
	{
		# If they pass nothing as their passwords, it means that nothing
		# was changed.
		$$result{failed} = "Password too short!";
	}

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

	# If the password fields contained nothing, this means that the
	# user did not want to change the password, so we just omit the
	# update of this field.
	return 1 unless($value && $value ne "");
	
	shift @_;
	return $this->SUPER::cgiUpdate(@_);
}


#############################################################################
# End of package
#############################################################################

1;

