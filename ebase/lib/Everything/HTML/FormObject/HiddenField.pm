
=head1 Everything::HTML::FormObject::HiddenField

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base HiddenField functionality.

=cut

package Everything::HTML::FormObject::HiddenField;

use strict;

use Everything::HTML::FormObject;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject");

=cut


=head2 C<genObject>

This is called to generate the needed HTML for this HiddenField form object.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this HiddenField is to be bound to a field on a node.  undef if
this item is not bound.

=item * $field

The field on the node that this HiddenField is bound to.  If $bindNode is
undef, this is ignored.

=item * $name

The name of the form object, i.e. E<lt>input type=text name=$nameE<gt>.

=item * $default

The value this object will contain as its initial default.  If undef, this will
default to what the field of the bindNode is.

=back

Returns the generated HTML for this HiddenField object.

=cut

sub genObject
{
	my $this = shift @_;
	my ( $query, $bindNode, $field, $name, $default ) =
		$this->getParamArray( "query, bindNode, field, name, default", @_ );

	$name    ||= $field;
	$default ||= 'AUTO';

	my $html =
		$this->SUPER::genObject( $query, $bindNode, $field, $name ) . "\n";

	if ( $default eq "AUTO" )
	{
		$default = "";
		$default = $$bindNode{$field} if ($bindNode);
	}

	$html .= $query->hidden( -name => $name, -default => $default );

	return $html;
}

1;
