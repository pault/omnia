
=head1 Everything::HTML::FormObject::RemoveVarCheckbox

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base RemoveVarCheckbox functionality.

=cut

package Everything::HTML::FormObject::RemoveVarCheckbox;

use strict;
use Everything qw/$DB getParamArray/;

use Everything::HTML::FormObject::Checkbox;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::Checkbox");

=cut


=head2 C<genObject>

This is called to generate the needed HTML for this RemoveVarCheckbox form
object.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this checkbox is to be bound to a field on a node.  undef if this
item is not bound.

=item * $field

The field on the node that the vars are stored.

=item * $var

The var in the hash to remove.

=back

Returns the generated HTML for this RemoveVarCheckbox object.

=cut

sub genObject
{
	my $this = shift;
	my ( $query, $bindNode, $field, $var ) =
		getParamArray( "query, bindNode, field, var", @_ );

	# Form objects for updating the key/value pairs are < 55.  This way this
	# will get executed after them, guaranteeing that they will be deleted.
	$this->{updateExecuteOrder} = 55;

	$var =~ s/:/::/g;
	my $name = "remove_" . $field . "_" . $var;
	my $html = $this->SUPER::genObject( $query, $bindNode, $field . ":$var",
		$name, "remove", "UNCHECKED" )
		. "\n";

	return $html;
}

sub cgiUpdate
{
	my ( $this, $query, $name, $NODE, $overrideVerify ) = @_;
	my $param = $query->param($name);

	# We will not be set unless we are checked
	return 0 unless ($param);

	my $field = $this->getBindField( $query, $name );
	my $var;

	( $field, $var ) = split( /::(?!:)/, $field, 2 );

	# Make sure this is not a restricted field that we cannot update directly.
	return 0 unless ( $overrideVerify or $NODE->verifyFieldUpdate($field) );

	my $vars = $NODE->getHash($field);

	$var =~ s/::UNCHECKED$//;

	delete $vars->{$var};
	$NODE->setHash( $vars, $field );

	return 1;
}

1;
