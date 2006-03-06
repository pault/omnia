=head1 Everything::HTML::FormObject::TextField

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base TextField functionality.

=cut

package Everything::HTML::FormObject::TextField;

use strict;
use Everything;

use Everything::HTML::FormObject;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject");

=cut

=head2 C<genObject>

This is called to generate the needed HTML for this TextField form object.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this TextField is to be bound to a field on a node.  undef if
this item is not bound.

=item * $field

The field on the node that this TextField is bound to.  If $bindNode is undef,
this is ignored.

=item * $name

The name of the form object, i.e., E<lt>input type=text name=$nameE<gt>.

=item * $default

The value this object will contain as its initial default.  If undef, this will
default to what the field of the bindNode is.

=item * $size

The width in characters of the TextField.

=item * $maxlen

The maximum number of characters this TextField will accept.

=back

Returns the generated HTML for this TextField object.

=cut

sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $default, $size, $maxlen) =
		getParamArray(
		"query, bindNode, field, name, default, size, maxlen", @_);

	$name ||= $field;
	$default ||= 'AUTO';
	$size ||= 20;
	$maxlen ||= 255;

	my $html = $this->SUPER::genObject($query, $bindNode, $field, $name) . "\n";

	if($default eq "AUTO")
	{
		$default = "";
		$default = $$bindNode{$field} if(ref $bindNode);
	}

	$html .= $query->textfield(-name => $name, -default => $default,
		-size => $size, -maxlength => $maxlen, -override => 1);

	return $html;
}

1;
