package Everything::HTML::FormObject::TypeMenu;

#############################################################################
#   Everything::HTML::FormObject::TypeMenu
#		Package the implements the base TypeMenu functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");


#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this TypeMenu
#		form object.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this TypeMenu is to be bound to a field
#			on a node.
#		$field - the field on the node that this TypeMenu is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$type - string name of the nodetype (ie 'document' will cause the
#			menu to be populated with the names of all the documents in
#			the system)
#		$default - value this object will contain as its initial default.
#			Specify 'AUTO' if you want to use the value of the field this
#			object is bound to, if it is bound
#		$USER - (optional) the user that we are generating this menu for.
#			This is to control which nodes are in the menu (user may not
#			have access to some nodes so we don't want to display them)
#		$perm - (optional) the permission to check against for the given
#			user (either r,w,d,x, or c)
#		$none - (optional) true if the menu should contain an option of
#			'None' (with value of $none).
#		$inherit - (optional) true if the menu should contain an option of
#			'Inherit' (with value of $inherit).
#		$inherittxt - (optional) a string that is to be displayed with
#			the inherit option.  ie "inherit ($inherittxt)".  Useful
#			for letting the user know what is being inherited.
#
#	Returns
#		The generated HTML for this TypeMenu object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $type, $default, $USER,
		$perm, $none, $inherit, $inherittxt) =  getParamArray(
		"query, bindNode, field, name, type, default, USER, " .
		"perm, none, inherit, inherittxt", @_);

	$name ||= $field;
	$type ||= "nodetype";
	$default ||= "AUTO";
	$USER ||= -1;
	$perm ||= 'r';

	my $html = $this->SUPER::genObject($query, $bindNode, $field, $name) . "\n";
	
	if($default eq "AUTO" && (ref $bindNode))
	{
		$default = $$bindNode{$field};
	}
	else
	{
		$default = undef;
	}

	$this->addTypes($type, $USER, $perm, $none, $inherit, $inherittxt);
	$html .= $this->genPopupMenu($query, $name, $default);

	return $html;
}


#############################################################################
#	Sub
#		addTypes
#
#	Purpose
#		Add the given type to this menu.  The reason we have this method
#		rather than just calling formmenu::addType() directly, is so
#		derived classes can override this and insert nodes differently in
#		perhaps different orders.
#
sub addTypes
{
	my ($this, $type, $USER, $perm, $none, $inherit, $inherittxt) = @_;
	
	$USER ||= -1;
	$perm ||= 'r';

	my $label = "inherit";
	$label .= " ($inherittxt)" if($inherittxt);
	$this->addHash({'None' => $none}, 1) if(defined $none);
	$this->addHash({ $label => $inherit}, 1) if(defined $inherit);
	$this->addType($type, $USER, $perm, 'labels');
	return 1;
}


#############################################################################
# End of package
#############################################################################

1;


