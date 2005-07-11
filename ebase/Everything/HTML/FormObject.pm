=head1 Everything::HTML::FormObject

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base FormObject functionality.

=cut

package Everything::HTML::FormObject;

use strict;
use Everything;

=cut

=head2 C<new>

This creates the base FormObject class object that all FormObject classes use.
There should never be any need for any derived classes of FormObject to
override this.

Returns the blessed FormObject class.

=cut

sub new
{
	my $class = shift @_;
	my $this = { };

	bless $this, $class;

	# Strip off the name of the object and store it
	$class =~ /^.*::(.+)$/;
	$this->{objectName} = $1;

	# default to an order of 50.  Other form objects can change this in their
	# genObject() method.
	$this->{updateExecuteOrder} = 50;

	return $this;
}

=cut

=head2 C<genObject>

This generates the HTML necessary to make a form item on the page.  This is the
base implementation of a form object.  It just sets up some data fields on this
object in preparation for the derived classes to do something interesting.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this textfield is to be bound to a field on a node.  undef if
this item is not bound.

=item * $field

The field on the node that this textfield is bound to.  If $bindNode is undef,
this is ignored.  If the name of the field contains a ':'.  It is assumed that
the text preceding the ':' is the name of the field that contains a hash
(retrieved with Node::getHash()) and the string following the ':' is the name
of the key in the hash.  This way any form object can instantly edit hash
fields by specifying the field name of 'field:key'.

=item * $name

The name of the form object, i.e. E<lt>input type=text name=$nameE<gt>.

=back

Returns the generated HTML for this object.

=cut

sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name) =
		getParamArray("query, bindNode, field, name", @_); 

	return $this->genBindField($query, $bindNode, $field, $name);
}

=cut

=head2 C<cgiVerify>

This is called by the system when it is attempting to update nodes.
cgiVerify() is responsible for examining the CGI params associated with it and
verifying that the USER has permission to update the node it is bound with.

=over 4

=item * $query

The CGI object that contains the incoming CGI parameters.

=item * $name

The $name passed to genObject() so this can reconstruct the fields that it
generated and retrieve the needed data.

=item * $USER

The user attempting to do this update, for authorization.

=back

Returns a hashref that contains the following fields:

=over 4

=item * node

The ID of the node that this object would update if it is bound.

=item * failed

If the verify fails for any reason, this should be filled with a text string
explaining the reason why the verify failed, i.e., "User does not have
permission".

=back

=cut

sub cgiVerify
{
	my ($this, $query, $name, $USER) = @_;

	my $bindNode = $this->getBindNode($query, $name);
	my $result = {};

	if($bindNode)
	{
		$$result{node} = $bindNode->getId();
		$$result{failed} = "User does not have permission"
			unless($bindNode->hasAccess($USER, 'w'));
	}

	return $result;
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

The node object that this field is bound to (as reported by cgiVerify()).  This
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
	my ($this, $query, $name, $NODE, $overrideVerify) = @_;
	my $value = $query->param($name);
	my $field = $this->getBindField($query, $name);
	my $var;

	# If the stored field name is separated by a ':', this form object is bound
	# to a hash value.
	($field, $var) = split(/::(?!:)/, $field, 2);

	# Make sure this is not a restricted field that we cannot update directly.
	return 0 unless($overrideVerify or $NODE->verifyFieldUpdate($field));

	$value = "" unless defined $value;
	if($var)
	{
		my $vars = $NODE->getHash($field);

		if($vars)
		{
			$vars->{$var} = $value;
			$NODE->setHash($vars, $field);
		}
	}
	else
	{
		$$NODE{$field} = $value;
	}

	return 1;
}

=cut

=head2 C<genBindField>

If this form object is bound to a node and field, we generate a hidden form
field that contains the information we need to know what node/field we are
bound to on CGI post.

=over 4

=item * $query

The CGI object used to generate this tag.

=item * $bindNode

A node ref of the node that we are to bind on.

=item * $field

The name of the field that we are bound to.  This can be more than just a field
name of the form object needs more info.

=item * $name

The name of the HTML form object so that this knows what we are associated with
and gives us a unique name.

=back

Returns the HTML for this hidden form field.

=cut

sub genBindField
{
	my ($this, $query, $bindNode, $field, $name) = @_;

	return "" unless($bindNode);

	# Make sure any single digit "order" numbers are preceeded by a zero
	my $order = sprintf( "%02d", $this->{updateExecuteOrder} || 50 );
	my $bindid;

	if (ref $bindNode)
	{
		$bindid = $bindNode->{node_id};
	}
	elsif ($bindNode eq 'new')
	{
		$bindid = 'new';
	}

	s/:/::/g for ($bindid, $field);

	return $query->hidden(
		-name => 'formbind_' . $$this{objectName} . '_' . $name,
		-value => "$order:$bindid:$field", -override => 1);
}

=cut

=head2 C<getBindNode>

Get the node that this object is bound to.  This is the same node that was
passed to genObject() as $bindNode

=over 4

=item * $query

The CGI object so we can go revieve our info.

=item * $name

The name of this form object (the same $name passed to genObject()).

=back

Returns the node object if successful, undef otherwise.

=cut

sub getBindNode
{
	my ($this, $query, $name) = @_;

	my $value = $query->param('formbind_' . $this->{objectName} . '_' . $name);
	return undef unless($value);

	if ($value =~ /^\d\d:(.*?):(?!:)/)
	{

		my $nodeid = $1;
		$nodeid    = $query->param('node_id') if $nodeid eq 'new';

		return $DB->getNode($nodeid);
	}
}

=cut

=head2 C<getBindField>

Get the field that this object is bound to.  This is essentially the '$field'
data passed to genObject().

=over 4

=item * $query

The CGI object so we can access our parameters.

=item * $name

The name of the form object.  The same $name that was passed to genObject().

=back

Returns the field data if it exists, undef otherwise.

=cut

sub getBindField
{
	my ($this, $query, $name) = @_;

	my $param = 'formbind_' . $this->{objectName} . '_' . $name;
	my $value = $query->param($param);
	return undef unless $value;

	my $field;
	if ( $value =~ /^\d\d:.*?:((?!:).*)/ )
	{
		$field = $1;
	}

	return $field;
}

1;
