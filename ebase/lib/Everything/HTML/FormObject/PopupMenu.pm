
=head1 Everything::HTML::FormObject::PopupMenu

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base PopupMenu functionality.

=cut

package Everything::HTML::FormObject::PopupMenu;

use strict;
use Everything;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");

=cut


=head2 C<genObject>

This is called to generate the needed HTML for this PopupMenu form object.
NOTE!!!! This cannot be called from

  [{nodeFormObject:...}] 

style htmlcode.  This is due to the fact that you need to call the
addHash/addArray/addType/addGroup functions to populate this menu before
calling this.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this PopupMenu is to be bound to a field on a node.  undef if
this item is not bound.

=item * $field

The field on the node that this PopupMenu is bound to.  If $bindNode is undef,
this is ignored.

=item * $name

The name of the form object, i.e., E<lt>input type=text name=$nameE<gt>.

=item * $default

The value this object will contain as its initial default.  Specify 'AUTO' if
you want to use the value of the field this object is bound to, if it is bound.

=back

Returns the generated HTML for this PopupMenu object.

=cut

sub genObject
{
	my $this = shift @_;
	my ( $query, $bindNode, $field, $name, $default ) =
		getParamArray( "query, bindNode, field, name, default", @_ );

	my $html = $this->SUPER::genObject(@_) . "\n";

	$name    ||= $field;
	$default ||= 'AUTO';

	if ( $default eq "AUTO" )
	{
		$default = "";
		$default = $$bindNode{$field} if ( ref $bindNode );
	}

	$html .= $this->genPopupMenu( $query, $name, $default );

	return $html;
}

1;
