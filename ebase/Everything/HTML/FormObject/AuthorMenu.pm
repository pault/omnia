=head1 Everything::HTML::FormObject::AuthorMenu

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base AuthorMenu functionality.

=cut

package Everything::HTML::FormObject::AuthorMenu;

use strict;
use Everything;
use Everything::HTML;

use Everything::HTML::FormObject;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject");

=cut

=head2 C<genObject>

This is called to generate the needed HTML for this AuthorMenu form object.
This creates a text field and a popup menu that allows the entry and selection
of any user or usergroup.  The menu lists all usergroups and has a selection to
allow an individual user to be specified.  If 'specify user' is selected in the
menu, a user name can be entered into the text field.  The reason the
AuthorMenu is done this way is because some sites can have hundreds or
thousands of users.  If we put all users in a menu, the HTML for the menu form
object would be huge and could possibly crash some systems.

=over 4

=item * $query 

The CGI object we use to generate the HTML.

=item * $bindNode 

(optional) A node ref if this AuthorMenu is to be bound to a field on a node.

=item * $field 

The field on the node that this AuthorMenu is bound to.  If $bindNode is undef,
this is ignored.

=item * $name 

The name of the form object in the HTML.  If not specified, the name of the
form object defaults to $field.

=item * $txtdefault 

(optional) The default that the "name" text area should be set to.  If undef,
this will default to be what is appropriate based on $bindNode-E<gt>{$field}.

=item * $menudefault 

(optional) The value that the menu should be set to.  Same as $txtdefault if
undef

=back

Returns the generated HTML for this AuthorMenu object.

=cut

sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $default) =
		getParamArray(
		"query, bindNode, field, name, default", @_);

	$name ||= $field;

	my $html = $this->SUPER::genObject($query, $bindNode, $field, $name) . "\n";

	if(ref $bindNode)
	{
		my $author = $DB->getNode($$bindNode{$field});
		if($author && $author->isOfType('user'))
		{
			$default ||= $$author{title};
		}
		elsif($author)
		{
			$default ||= "";
		}
	}

	$html .= $query->textfield(-name => $name,
		-default => $default, -size => 15, -maxlength => 255,
		-override => 1) . "\n";

	return $html;
}

=cut

=head2 C<cgiVerify>

This checks to make sure the specified user exists.

=cut

sub cgiVerify
{
	my ($this, $query, $name, $USER) = @_;

	my $bindNode = $this->getBindNode($query, $name);
	my $author = $query->param($name);
	my $result = {};

	if($author)
	{
		my $AUTHOR = $DB->getNode($author, 'user');

		if($AUTHOR)
		{
			# We have an author!!  Set the CGI param so that the
			# inherited cgiUpdate() will just do what it needs to!
			$query->param($name, $$AUTHOR{node_id});
		}
		else
		{
			$$result{failed} = "User '$author' does not exist!";
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

1;


