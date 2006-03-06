=head1 Everything::HTML::FormObject::TextArea

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base TextArea functionality.

=cut

package Everything::HTML::FormObject::TextArea;

use strict;
use Everything;

use Everything::HTML::FormObject;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject");

=cut

=head2 C<genObject>

This is called to generate the needed HTML for this TextArea form object.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this TextArea is to be bound to a field on a node.  undef if this
item is not bound.

=item * $field

The field on the node that this TextArea is bound to.  If $bindNode is undef,
this is ignored.

=item * $name

The name of the form object, i.e., E<lt>input type=text name=$nameE<gt>.

=item * $default

The value this object will contain as its initial default.  Specify 'AUTO' if
you want to use the value of the field this object is bound to, if it is bound.

=item * $cols

The number of colums wide the text area should be.

=item * $rows

The number of rows high the text area should be.

=item * $wrap

Any one of 'off', 'hard', 'physical', 'soft', or 'virtual'.  See HTML 4.0 docs
for info.

=back

Returns the generated HTML for this TextArea object.

=cut

sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $default, $cols,
		$rows, $wrap) = getParamArray(
		"query, bindNode, field, name, default, cols, rows, wrap", @_);

	$name ||= $field;
	$default ||= 'AUTO';
	$cols ||= 80;
	$rows ||= 20;
	$wrap ||= 'virtual';

	my $html = $this->SUPER::genObject($query, $bindNode, $field, $name) . "\n";

	if($default eq "AUTO")
	{
		$default = "";
		$default = $$bindNode{$field} if(ref $bindNode);
	}

	$html .= $query->textarea(-name => $name, 
		-default => $default, -cols => $cols,
		-rows => $rows, -wrap => $wrap);

	return $html;
}

1;
