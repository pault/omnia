
=head1 Everything::HTML::FormObject::RadioGroup

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base RadioGroup functionality.

=cut

package Everything::HTML::FormObject::RadioGroup;

use strict;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");

=cut


=head2 C<genObject>

This is called to generate the needed HTML for this RadioGroup form object.
NOTE!!!! This cannot be called from

  [{nodeFormObject:...}] 

style htmlcode.  You need to set this up by calling the various add() functions
(see FormMenu.pm)

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this RadioGroup is to be bound to a field on a node.  undef if
this item is not bound.

=item * $field

The field on the node that this RadioGroup is bound to.  If $bindNode is undef,
this is ignored.

=item * $name

The name of the form object, i.e. E<lt>input type=text name=$nameE<gt>.

=item * $default

The value this object will contain as its initial default.  Specify 'AUTO' if
you want to use the value of the field this object is bound to, if it is bound.

=item * $vertical

If true, it will format the radio buttons vertically by placing a E<lt>brE<gt>
between each one.

=back

Returns the generated HTML for this RadioGroup object.

=cut

sub genObject
{
	my $this = shift @_;
	my ( $query, $bindNode, $field, $name, $default, $vertical ) =
		$this->getParamArray( "query, bindNode, field, name, default, vertical", @_ );

	my $html = $this->SUPER::genObject(@_) . "\n";

	if ( $default eq "AUTO" )
	{
		$default = "";
		$default = $$bindNode{$field} if ( ref $bindNode );
	}

	my $values  = $this->getValuesArray();
	my $labels  = $this->getLabelsHash();
	my @buttons = $query->radio_group(
		-name    => $name,
		-default => $default,
		-values  => $values,
		-labels  => $labels
	);

	if ($vertical)
	{
		$html .= join( "<br>\n", @buttons );
	}
	else
	{
		$html .= join( "\n", @buttons );
	}

	return $html;
}

1;
