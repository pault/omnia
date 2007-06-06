
=head1 Everything::HTML::FormObject::Checkbox

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base Checkbox functionality.

=cut

package Everything::HTML::FormObject::Checkbox;

use strict;

use Everything::HTML::FormObject;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject");

=cut


=head2 C<genObject>

This is called to generate the needed HTML for this checkbox form object.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this checkbox is to be bound to a field on a node.  undef if this
item is not bound.

=item * $field

The field on the node that this checkbox is bound to.  If $bindNode is undef,
this is ignored.

=item * $name

The name of the form object, i.e. E<lt>input type=check name=$nameE<gt>.

=item * $checked

A string value of what should be set if the checkbox is checked.

=item * $uncheched

A string value of what should be set if the checkbox is NOT checked.

=item * $default

Either 1 (checked), 0 (not checked) or "AUTO", where AUTO will set it based on
whatever the bound node's field value is.

=item * $label

A text string that is to be a visible label for the checkbox.

=back

Returns the generated HTML for this checkbox object.

=cut

sub genObject
{
	my $this = shift @_;
	my (
		$query,   $bindNode,  $field,   $name,
		$checked, $unchecked, $default, $label
		)
		= $this->getParamArray(
		"query, bindNode, field, name, checked, unchecked, default, label",
		@_ );

	my $CHECK = '';
	$checked   ||= 1;
	$unchecked ||= 0;
	$default   ||= "AUTO";
	$label     ||= '';

	my $html =
		$this->SUPER::genObject( $query, $bindNode, $field . ":$unchecked",
		$name )
		. "\n";

	if ( $default eq 'AUTO' )
	{
		$CHECK =
			( ref $bindNode && ( $checked eq $bindNode->{$field} ) ) ? 1 : 0;
	}
	else
	{
		$CHECK = $default;
	}

	$html .= $query->checkbox(
		-name    => $name,
		-checked => $CHECK,
		-value   => $checked,
		-label   => $label
	);

	return $html;
}

sub cgiUpdate
{
	my ( $this, $query, $name, $NODE, $overrideVerify ) = @_;
	my $value = $query->param($name);
	my $field = $this->getBindField( $query, $name );

	( $field, my $unchecked ) = split( ':', $field );

	# Make sure this is not a restricted field that we cannot update directly.
	return 0 unless $overrideVerify or $NODE->verifyFieldUpdate($field);

	$value ||= $unchecked;
	$NODE->{$field} = $value;

	return 1;
}

1;
