package Everything::HTML::FormObject::AuthorMenu;

#############################################################################
#   Everything::HTML::FormObject::AuthorMenu
#		Package the implements the base AuthorMenu functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;
use Everything::HTML;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");

#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this AuthorMenu
#		form object.  This creates a text field and a popup menu that
#		allows the entry and selection of any user or usergroup.  The
#		menu lists all usergroups and has a selection to allow an
#		individual user to be specified.  If 'specify user' is selected
#		in the menu, a user name can be entered into the text field.
#		The reason the AuthorMenu is done this way is because some sites
#		can have hundreds or thousands of users.  If we put all users
#		in a menu, the HTML for the menu form object would be huge and
#		could possibly crash some systems.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - (optional) a node ref if this AuthorMenu is to be bound
#			to a field on a node.
#		$field - the field on the node that this AuthorMenu is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object in the HTML.  If not specified,
#			the name of the form object defaults to $field
#		$txtdefault - (optional) the default that the "name" text area
#			should be set to.  If undef, this will default to be what is
#			appropriate based on $$bindNode{$field}.
#		$menudefault - (optional) the value that the menu should be set to
#			Same as $txtdefault if undef
#
#	Returns
#		The generated HTML for this AuthorMenu object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $txtdefault, $menudefault) =
		getParamArray(
		"query, bindNode, field, name, txtdefault, menudefault", @_);
	
	$name ||= $field;

	my $html = $this->SUPER::genObject($query, $bindNode, $field, $name) . "\n";
	
	$this->addHash({ 'specify user' => -1 }, 1);
	$this->addType('usergroup', -1, 'r', 'labels');
	
	if($bindNode)
	{
		my $author = $DB->getNode($$bindNode{$field});
		if($author && $author->isOfType('user'))
		{
			$txtdefault ||= $$author{title};
			$menudefault ||= -1;
		}
		elsif($author)
		{
			$txtdefault ||= "";
			$menudefault ||= $$author{node_id};
		}
	}

	$html .= $query->textfield(-name => $name . '_input',
		-default => $txtdefault, -size => 15, -maxlength => 255,
		-override => 1) . "\n";
	$html .= $this->genPopupMenu($query, $name, $menudefault);

	return $html;
}


#############################################################################
#	Sub
#		cgiVerify
#
#	Purpose
#		This checks to make sure the specified user exists.
#
sub cgiVerify
{
	my ($this, $query, $name, $USER) = @_;

	my $bindNode = $this->getBindNode($query, $name);
	my $author = $query->param($name);
	my $result = {};

	if($author == -1)
	{
		my $authorname = $query->param($name . '_input');
		my $AUTHOR = $DB->getNode($authorname, 'user');

		if($AUTHOR)
		{
			# We have an author!!  Set the CGI param so that the
			# inherited cgiUpdate() will just do what it needs to!
			$query->param($name, $$AUTHOR{node_id});
		}
		else
		{
			$$result{failed} = "User '$authorname' does not exist!";
		}
	}
	
	if($bindNode)
	{
		$$result{node} = $bindNode->getId();
		$$result{failed} = "You do not have permission"
			unless($bindNode->hasAccess($USER, 'w'));
	}
	
	return $result;
}


#############################################################################
# End of package
#############################################################################

1;


