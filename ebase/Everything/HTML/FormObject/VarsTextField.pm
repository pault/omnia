=head1 Everything::HTML::FormObject::VarsTextField

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base VarsTextField functionality.

=cut

package Everything::HTML::FormObject::VarsTextField;

use strict;
use Everything;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");

=cut

=head2 C<genObject>

This is called to generate the needed HTML for this VarsTextField form object.
This textfield object can be made to either edit key name, or the value of a
hash entry.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this VarsTextField is to be bound to a field on a node.  undef if
this item is not bound.

=item * $field

The field on the node that this VarsTextField is bound to.  If $bindNode is
undef, this is ignored.

=item * $name

The name of the form object, i.e., E<gt>input type=text name=$nameE<lt>.

=item * $default

The value this object will contain as its initial default.  If undef, this will
default to what the field of the bindNode is.

=item * $size

The width in characters of the VarsTextField.

=item * $maxlen

The maximum number of characters this VarsTextField will accept.

=back

Returns the generated HTML for this VarsTextField object.

=cut

sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $var, $key, $default, $size, $maxlen) =
		getParamArray(
		"query, bindNode, field, var, key, default, size, maxlen", @_);

	if($key)
	{
		$key = "key";
		$$this{updateExecuteOrder} = 50;
	}
	else
	{
		# We need to have the values updated before the keys.
		$$this{updateExecuteOrder} = 45;
		$key = "value";
	}

	my $name = $field . "_" . $var . "_" . $key;
	$default ||= 'AUTO';
	$size ||= 20;
	$maxlen ||= 255;

	my $html = $this->SUPER::genObject($query, $bindNode,
		$field . ":$var", $name) . "\n";

	if($default eq "AUTO" && (ref $bindNode))
	{
		my $vars = $bindNode->getHash($field);
		$default = "";

		if(exists $$vars{$var})
		{
			$default = $var if($key eq 'key');
			$default = $$vars{$var} if($key eq 'value');
		}
	}

	$html .= $query->textfield(-name => $name, -default => $default,
		-size => $size, -maxlength => $maxlen, -override => 1);

	if($key eq "value")
	{
		$this->clearMenu();
		$this->addHash( { 'Literal Value' => '0' }, 1);
		$this->addType('nodetype', -1, 'r', 'labels');

		$html .= "<font size='1'>" .
			$this->genPopupMenu($query, $name . "_type", 0) . "</font>";
	}

	return $html;
}

=cut

=head2 C<cgiUpdate>

Called by the system to update this node.

=over 4

=item * $query

The CGI object used to fetch parameters.

=item * $name

The name of the object to update.  This will be the 'fieldname_varname_key' or
'fieldname_varname_value' that was generated in the genObject method.

=item * $NODE

The node that we were bound to and need to update.

=item * $overrideverify

Should we skip the verification that we can update this particular var?  True
if so, false otherwise.

=back

Returns 0 (false) if failure, 1 (true) if successful.

=cut

sub cgiUpdate
{
	my ($this, $query, $name, $NODE, $overrideVerify) = @_;
	my $param = $query->param($name);
	my $field = $this->getBindField($query, $name);
	my $value;
	
	# Make sure this is not a restricted field that we cannot update directly.
	return 0 unless($overrideVerify or $NODE->verifyFieldUpdate($field));
	my $var;
	($field, $var) = split('::', $field);
        my $vars = $NODE->getHash($field);
	
        $NODE->setHash($vars, $field);
	if($name =~ /_value$/)
	{
		# The value is specified by a textfield/popup menu combo.  We
		# need to get both to determine what was actually specified.

		my $menuname = $name . "_type";
		my $type = $query->param($menuname);
		my $value = $query->param($name);

		if($type > 0)
		{
			my $N = $DB->getNode($value, $type);
			$value = $$N{node_id} if($N);
		}

		$$vars{$var} = $value if(defined $value);
	}
	elsif($name =~ /_key$/ && $var ne $param)
	{
		# They changed the name of the key!  We need to assign
		# the value of the old key to the new key and delete the
		# old key.

		$$vars{$param} = $$vars{$var} if($param ne "");
		delete $$vars{$var} if(exists $$vars{$var});
	}

	$NODE->setHash($vars, $field);

	return 1;
}

1;
