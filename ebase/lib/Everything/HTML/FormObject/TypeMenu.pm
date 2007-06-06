
=head1 Everything::HTML::FormObject::TypeMenu

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base TypeMenu functionality.

=cut

package Everything::HTML::FormObject::TypeMenu;

use strict;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");

=cut


=head2 C<genObject>

This is called to generate the needed HTML for this TypeMenu form object.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this TypeMenu is to be bound to a field on a node.

=item * $field

The field on the node that this TypeMenu is bound to.  If $bindNode is undef,
this is ignored.

=item * $name

The name of the form object, i.e., E<lt>input type=text name=$nameE<gt>.

=item * $type

The string name of the nodetype (i.e., 'document' will cause the menu to be
populated with the names of all the documents in the system).

=item * $default

The value this object will contain as its initial default.  Specify 'AUTO' if
you want to use the value of the field this object is bound to, if it is bound.

=item * $USER

(optional) The user that we are generating this menu for.  This is to control
which nodes are in the menu (the user may not have access to some nodes so we
don't want to display them).

=item * $perm

(optional) The permission to check against for the given user (any one of
r,w,d,x, or c).

=item * $none

(optional) True if the menu should contain an option of 'None' (with value of
$none).

=item * $inherit

(optional) True if the menu should contain an option of 'Inherit' (with value
of $inherit).

=item * $inherittxt

(optional) A string that is to be displayed with the inherit option, i.e.,
"inherit ($inherittxt)".  Useful for letting the user know what is being
inherited.

=back

Returns the generated HTML for this TypeMenu object.

=cut

sub genObject
{
	my $this = shift @_;
	my (
		$query, $bindNode, $field, $name,
		$type,  $default,  $USER,  $perm,
		$none,  $inherit,  $inherittxt
		)
		= $this->getParamArray(
		"query, bindNode, field, name, type, default, USER, "
			. "perm, none, inherit, inherittxt",
		@_
		);

	$name    ||= $field;
	$type    ||= "nodetype";
	$default ||= "AUTO";
	$USER    ||= -1;
	$perm    ||= 'r';

	my $html =
		$this->SUPER::genObject( $query, $bindNode, $field, $name ) . "\n";

	if ( $default eq "AUTO" && ( ref $bindNode ) )
	{
		$default = $$bindNode{$field};
	}
	else
	{
		$default = undef;
	}

	$this->addTypes( $type, $USER, $perm, $none, $inherit, $inherittxt );
	$html .= $this->genPopupMenu( $query, $name, $default );

	return $html;
}

=cut


=head2 C<addTypes>

Add the given type to this menu.  The reason we have this method rather than
just calling formmenu::addType() directly, is so derived classes can override
this and insert nodes differently in perhaps different orders.

=cut

sub addTypes
{
	my ( $this, $type, $USER, $perm, $none, $inherit, $inherittxt ) = @_;

	$USER ||= -1;
	$perm ||= 'r';

	my $label = "inherit";
	$label .= " ($inherittxt)" if ($inherittxt);
	$this->addHash( { 'None' => $none },    1 ) if ( defined $none );
	$this->addHash( { $label => $inherit }, 1 ) if ( defined $inherit );
	$this->addType( $type, $USER, $perm, 'labels' );
	return 1;
}

1;
