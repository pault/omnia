
=head1 Everything::HTML::FormObject::ListMenu

Package that implements the base ListMenu functionality.

Copyright 2001 - 2003 Everything Development Inc.

=cut

package Everything::HTML::FormObject::ListMenu;

use strict;
use Everything qw/$DB getParamArray/;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");

=cut


=head2 C<genObject>

This is called to generate the needed HTML for this listmenu form object.
NOTE!!!! This cannot be called from

  [{nodeFormObject:...}] 

style htmlcode.  You need to call nodeFormObject() as a function.  This is due
to the fact that the $values and $labels are array and hash refs.  You cannot
achieve the desired results calling this from htmlcode.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this listmenu is to be bound to a field
a node.  undef if this item is not bound.

=item * $field

The field on the node that this listmenu is bound to.  If
bindNode is undef, this is ignored.

=item * $name

The name of the form object, i.e. E<lt>input type=text name=$nameE<gt>.

=item * $default

Value this object will contain as its initial default.  This can be either a
single value, or an array ref of values are selected (these must exist in the
$values array).  Use 'AUTO' if you want to use the value of the field this is
bound to, if it is bound.

=item * $multiple

True (1) if this listmenu should allow multiple , false (0) if only single
items can be selected.

=item * $values

An array ref that contains the values of the items in menu.

=item * $size

The height in rows that should listmenu should be.

=item * $labels

(optional) A hashref containing

  hash{$values[0...]} = $readableLabel

=item * $sortby

This specifies the order in which to sort the values.  'labels', 'labels
reverse', 'values', or values reverse'.

=back

Returns the generated HTML for this listmenu object.

=cut

sub genObject
{
	my $this = shift @_;
	my (
		$query,    $bindNode, $field, $name,   $default,
		$multiple, $values,   $size,  $labels, $sortby
		)
		= getParamArray(
		"query, bindNode, field, name, default, multiple, values, "
			. "size, labels, sortby",
		@_
		);

	$this->clearMenu();

	my $html = $this->SUPER::genObject(@_) . "\n";

	if ( $default eq "AUTO" )
	{
		$default = "";
		$default = [ split( /\s*,\s*/, $$bindNode{$field} ) ]
			if ( ref $bindNode );
	}

	$this->addArray($values);
	$this->addLabels($labels);
	$this->sortMenu($sortby);

	$html .= $this->genListMenu( $query, $name, $default, $size, $multiple );

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
	my ( $this, $query, $name, $NODE, $overrideVerify ) = @_;
	my $field = $this->getBindField( $query, $name );

	# Make sure this is not a restricted field that we cannot update directly.
	return 0 unless ( $overrideVerify or $NODE->verifyFieldUpdate($field) );

	my @values = $query->param($name);
	my $value  = join( ',', @values );

	$value ||= "";
	$$NODE{$field} = $value;

	return 1;
}

1;
