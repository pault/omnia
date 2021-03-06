
=head1 Everything::HTML::FormObject::SubsetSelector

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base SubsetSelector functionality.

=cut

package Everything::HTML::FormObject::SubsetSelector;

use strict;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");

=cut


=head2 C<genObject>

This is called to generate the needed HTML for this SubsetSelector form object.
It consists of a list box in a table with buttons to the right that allow the
user to move an item up or down in the group order, or remove it from the
group.

When using this form object, you will need to include two javascript functions,
findFormObject() and moveGroupItem().  On the page that you use this form
object, do:

  [{includeJS: findFormObject, moveGroupItem}]

Parameters can be passed as either -paramname =E<gt> value, or an array of
values of the following order:

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this SubsetSelector is to be bound to a field on a node.  undef
if this item is not bound.

=item * $name

The name of the form object, i.e., E<lt>input type=text name=$nameE<gt>.

=item * $color

A hex string (ie '#ffcc00') for the background color of this group editor.

=back

Returns the generated HTML for this SubsetSelector object.

=cut

sub genObject
{
	my $this = shift @_;
	my (
		$query, $bindNode, $field,    $name, $default,
		$size,  $color,    $srclabel, $destlabel
		)
		= $this->getParamArray(
		"query, bindNode, field, name, default, size, color, "
			. "srclabel, destlabel",
		@_
		);

	my $select = new Everything::HTML::FormObject::FormMenu();
	my ( $key, $var ) = split( ':', $field );
	my $srcname = $name . "_src";

	$default ||= 'AUTO';
	$size    ||= 20;

	if ( $default eq "AUTO" && ( ref $bindNode ) )
	{
		if ($var)
		{
			my $vars = $bindNode->getHash($key);
			$default = $$vars{$var};
		}
		else
		{
			$default = $$bindNode{$key};
		}
	}

	my @selected = split( ',', $default );
	my $removed = $this->removeItems( \@selected );
	$select->addArray( \@selected );
	$select->addLabels( $removed, 0 );

	$color = "bgcolor='$color'" if ($color);
	$color ||= "";
	my $html = "<table border='0' $color cellspacing='0'>\n";
	$html .= "<tr><td>\n";

	$html .= "<b><font size=2>$srclabel</font></b><br>\n" if ($srclabel);
	$html .= $this->SUPER::genObject( $query, $bindNode, $field, $name ) . "\n";
	$html .= $this->genListMenu( $query, $srcname, undef, $size );

	# Generate the hidden form field that holds the list of node id's for us.
	# This is what we actually get our data from when the form is submitted.
	$html .= $query->hidden(
		-name     => $name . '_values',
		-value    => $default,
		-override => 1
	);

	$html .= "</td><td valign='center' align='center'>\n";
	$html .= $query->button(
		-name       => $name . "_add",
		-value      => ">>>",
		-onClick    => "selectItem('$srcname', '$name')",
		-onDblClick => "selectItem('$srcname', '$name')"
	);
	$html .= "<br>\n";
	$html .= $query->button(
		-name       => $name . "_remove",
		-value      => "<<<",
		-onClick    => "selectItem('$srcname', '$name', 0)",
		-onDblClick => "selectItem('$srcname', '$name', 0)"
		)
		. "\n";
	$html .= "</td><td>\n";

	$html .= "<b><font size=2>$destlabel</font></b><br>\n" if ($destlabel);
	$html .= $select->genListMenu( $query, $name, undef, $size );
	$html .= "</td><td valign='center' align='center'>\n";
	$html .= $query->button(
		-name       => $name . "_up",
		-value      => "Up",
		-onClick    => "moveSelectItem('$name', -1)",
		-onDblClick => "moveSelectItem('$name', -1)"
	);
	$html .= "<br>\n";
	$html .= $query->button(
		-name       => $name . "_down",
		-value      => "Down",
		-onClick    => "moveSelectItem('$name', 1)",
		-onDblClick => "moveSelectItem('$name', 1)"
		)
		. "\n";
	$html .= "</td></tr></table>\n";

	return $html;
}

=cut


=head2 C<cgiUpdate>

This is called by the system if all cgiVerify() calls have succeeded and it is
time to update the node(s).  This will only be called if this object is bound
to a node that it needs to update.  This default implementation just assigns
the value of the CGI object to the bound node{field}.

=over 4

=item * $query

The CGI object that contains the incoming CGI parameters.  This is used to find
any associated parameters that this object created.

=item * $name

The $name passed to genObject() so this can reconstruct the fields that it
generated and retrieve the needed data.

=item * $NODE

The node object that this field is bound to (as reported by cgiVerify()).  This
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
	my ( $this, $query, $name, $NODE, $overrideVerify ) = @_;
	my $values = $query->param( $name . '_values' );
	my $field = $this->getBindField( $query, $name );
	my $var;

	( $field, $var ) = split( ':', $field );

	if ($var)
	{
		my $vars = $NODE->getHash($field);
		$$vars{$var} = $values;
		$NODE->setHash( $vars, $field );
	}
	else
	{
		$$NODE{$field} = $values;
	}

	return 1;
}

1;
