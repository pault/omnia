=head1 Everything::HTML::FormObject::GroupEditor

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base groupEditor functionality.

=cut

package Everything::HTML::FormObject::GroupEditor;

use strict;
use Everything;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");

=cut

=head2 C<genObject>

This is called to generate the needed HTML for this groupEditor form object.
It consists of a list box in a table with buttons to the right that allow the
user to move an item up or down in the group order, or remove it from the
group.

When using this form object, you will need to include two javascript functions,
findFormObject() and moveGroupItem().  ie on the page that you use this form
object do:

  [{includeJS: findFormObject, moveGroupItem}]

Can be passed as either -paramname =E<gt> value, or an array of values of the
following order:

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this groupEditor is to be bound to a field on a node, undef if
this item is not bound.

=item * $name

The name of the form object, i.e. E<lt>input type=text name=$nameE<gt>.

=item * $color

A hex string (i.e., '#ffcc00') for the background color of this group editor.

=back

Returns the generated HTML for this groupEditor object.

=cut

sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $name, $USER, $perm, $color) = getParamArray(
		"query, bindNode, name, USER, perm, color", @_);

	return "No Node to get group from!" unless(ref $bindNode);

	$color ||= '#cc99ff';

	$this->clearMenu();
	my $html = "<table border='0' bgcolor='$color' cellspacing='0'>\n";
	$html .= "<tr><td>\n";

	$html .= $this->SUPER::genObject($query, $bindNode, 'GROUP', $name) . "\n";
	$this->addGroup($bindNode, 1);
	$html .= $this->genListMenu($query, $name, undef, 20);

	# Generate the hidden form field that holds the list of node id's for us.
	# This is what we actually get our data from when the form is submitted.
	my $group = $$bindNode{group};
	my $values = join(',', @$group);
	$html .= $query->hidden(-name => $name . '_values', -value => $values,
		-override => 1);
	
	# This checkbox allows the user to specify if they would like duplicate
	# nodes (by id) to be removed from the group.  When working with large
	# nodeballs, you can sometimes add the same node twice by mistake.  This is
	# a good way to make sure that there are no duplicates in your group if you
	# don't want any.
	$html .= "<br>\n";
	$html .= $query->checkbox(-name => $name . '_dupes',
		-checked => 0, -value => 'remove',
		-label => 'Remove Duplicates');

	$html .= "</td><td valign='center' align='center'>\n";
	$html .= $query->button(-name => $name . "_up", -value => "Up",
		-onClick => "moveSelectItem('$name', -1)",
		-onDblClick => "moveSelectItem('$name', -1)");
	$html .= "<br>\n";
	$html .= $query->button(-name => $name . "_down", -value => "Down",
		-onClick => "moveSelectItem('$name', 1)", 
		-onDblClick => "moveSelectItem('$name', 1)") . "\n";
	$html .= "<p><br><br><br><br>\n";
	$html .= $query->button(-name => $name . "_remove", -value => "Remove",
		-onClick => "moveSelectItem('$name', 0)") . "\n";
	$html .= "</td></tr></table>\n";

	return $html;
}

=cut

=head2 C<cgiUpdate>

This is called by the system if all cgiVerify()'s have succeeded and it is time
to update the node(s).  This will only be called if this object is bound to a
node that it needs to update.  This default implementation just assigns the
value of the CGI object to the bound node{field}.

=over 4

=item * $query

The CGI object that contains the incoming CGI parameters.  This is used to find
any associated parameters that this object created.

=item * $name

The $name passed to genObject() so this can reconstruct the fields that it
generated and retrieve the needed data.

=item * $NODE

The node object that this field is bound to (as reported by cgiVerify).  This
is the node that all updates should be made to.  NOTE!  Do not call update() on
this node!  That will be handled by the system.

=item * $overrideVerify

If (for some reason) this should not check to to see if the nodetype would
allow us to update this field.  Basically, opUpdate() in HTML.pm will pass true
if the user doing this update is a god, and therefore should have complete
access to everything.  True if we should allow anything, false if we need to
check with the nodetype.

=back

Returns 1 (true) if successful, 0 (false) otherwise.

=cut

sub cgiUpdate
{
	my ($this, $query, $name, $NODE, $overrideVerify) = @_;
	my $values = $query->param($name . '_values');
	my @values = split(',', $values);

	if($query->param($name . '_dupes'))
	{
		# The remove duplicates checkbox was checked.  We need to make
		# sure there are no duplicates in this group, and remove any
		# that we find while maintaining the order as best we can.
		my %found;
		my @nodupes;

		foreach my $id (@values)
		{
			next if($found{$id});

			push @nodupes, $id;
			$found{$id} = 1;
		}

		undef @values;
		push @values, @nodupes;
	}

	$NODE->replaceGroup(\@values, -1);

	return 1;
}

1;
