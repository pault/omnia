
=head1 Everything::HTML::FormObject::FormMenu

Package that implements the base FormMenu functionality.

Copyright 2001 - 2003 Everything Development Inc.

This is the base of all pop-up or listbox menus.  This package does not
directly support the standard API for form objects.  It is not intended to be
used in that manner, because this just implements the base functionality that
all menus will use.

You can use this directly to do make some very custom menus if needed.
However, the derived classes of this will provide specific functionality that
will make certain types of menus easier to do.

Use the various addX() functions to add items to the menu. Once the menu is
populated with the desired items, call genPopupMenu() or genListMenu()

=cut

package Everything::HTML::FormObject::FormMenu;

use strict;
use Everything;

use Everything::HTML::FormObject;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject");

sub getValuesArray
{
	my ($this) = @_;

	$$this{VALUES} ||= [];
	return $$this{VALUES};
}

sub getLabelsHash
{
	my ($this) = @_;

	$$this{LABELS} ||= {};
	return $$this{LABELS};
}

sub clearMenu
{
	my ($this) = @_;
	$$this{VALUES} = [];
	$$this{LABELS} = {};
}

=cut


=head2 C<sortMenu>

Utility function used to sort the menu listing by certain criteria.

=over 4

=item * $sortby

This specifies the order in which to sort the values.  Either 'labels', 'labels
reverse', 'values', or 'values reverse'.

=item * $values

(optional) An array ref of values for the menu.  If undef, it is assumed that
you want to sort what is in the menu at the time this function is called.

=item * $labels

(not needed if sorting by values) Hash ref of 'value' =E<gt> 'label name'.

=back

Returns an array ref of the sorted values for the menu.

=cut

sub sortMenu
{
	my ( $this, $sortby, $values, $labels ) = @_;
	my @sorted;
	my $sortThis = 0;

	unless ($values)
	{
		$values   = $this->getValuesArray();
		$labels   = $this->getLabelsHash();
		$sortThis = 1;
	}

	if ( $sortby eq 'labels' )
	{
		@sorted = sort { $$labels{$a} cmp $$labels{$b} } @$values;
	}
	elsif ( $sortby eq 'reverse labels' )
	{
		@sorted = sort { $$labels{$b} cmp $$labels{$a} } @$values;
	}
	elsif ( $sortby eq 'values' )
	{
		@sorted = sort { $a cmp $b } @$values;
	}
	elsif ( $sortby eq 'reverse values' )
	{
		@sorted = sort { $b cmp $a } @$values;
	}

	$$this{VALUES} = \@sorted if ($sortThis);

	return \@sorted;
}

=cut


=head2 C<removeItems>

Sometimes you may want to populate the menu with a general group of items
(addType(), etc), but then you want to remove a certain subset.  This function
allows you to remove those items.

=over 4

=item * $items

An array ref of values to remove from this menu.  The values passed can include
those that this menu does not have.  Trying to remove something the menu does
not have will do nothing.

=back

Returns a hashref of "value =E<gt> label" of all the items removed.

=cut

sub removeItems
{
	my ( $this, $items ) = @_;
	my $gLabels = $this->getLabelsHash();
	my $gValues = $this->getValuesArray();
	my %remove;
	my @newValues;
	my %return;

	foreach (@$items)
	{
		$remove{$_} = 1;
	}

	foreach (@$gValues)
	{
		if ( $remove{$_} )
		{
			if ( exists $$gLabels{$_} )
			{
				$return{$_} = $$gLabels{$_};
				delete $$gLabels{$_};
			}
			else
			{
				$return{$_} = $_;
			}
		}
		else
		{
			push @newValues, $_;
		}
	}

	$$this{VALUES} = \@newValues;

	return \%return;
}

=cut


=head2 C<addType>

Add all nodes of the given type to the menu.  This is useful for given an
option to select a given user, nodetype, etc.

=over 4

=item * $type

The string name of the nodetype of the nodes to add.

=item * $USER

(optional) The user trying to do this.  If a user is passed this will omit the
nodetypes that the user does not have access to (access specified by $perm).

=item * $perm

(optional) The permission needed for the user to have a node in the menu.  This
is required if you specify a user.

=item * $sortby

This specifies the order in which to sort the values.  Either 'labels', 'labels
reverse', 'values', or 'values reverse'.

=back

Returns true if successful, false otherwise.

=cut

sub addType
{
	my ( $this, $type, $USER, $perm, $sortby ) = @_;
	my $TYPE   = $DB->getType($type);
	my $typeid = $$TYPE{node_id} if ( defined $TYPE );
	my $NODES  = $DB->getNodeWhere( { type_nodetype => $typeid } );
	my $NODE;
	my $gValues = $this->getValuesArray();
	my $gLabels = $this->getLabelsHash();
	my @values;

	foreach $NODE (@$NODES)
	{
		next unless ( ( not $USER ) or ( $NODE->hasAccess( $USER, $perm ) ) );
		$$gLabels{ $$NODE{node_id} } = $$NODE{title};
		push @values, $$NODE{node_id};
	}

	if ($sortby)
	{
		my $sort = $this->sortMenu( $sortby, \@values, $gLabels );
		push @$gValues, @$sort;
	}
	else
	{
		push @$gValues, @values;
	}

	return 1;
}

=cut


=head2 C<addGroup>

Given the name of the group, add all of the nodes in that group.

=over 4

=item * $GROUP

The group node in which to add its group members to the menu.

=item * $USER

(optional) The user trying to do this.  If a user is passed this will omit
nodes in the group that the user cannot access.

=item * $perm

(optional) The permission needed for the user to have a node in the menu.  This
is required if you specify a user.

=item * $sortby

This specifies the order in which to sort the values.  Either 'labels', 'labels
reverse', 'values', or 'values reverse'.

=back

Returns true if successful, false otherwise.

=cut

sub addGroup
{
	my ( $this, $GROUP, $showType, $USER, $perm, $sortby ) = @_;
	my $groupnode;
	my $NODE;
	my $GROUPNODES;
	my $gValues = $this->getValuesArray();
	my $gLabels = $this->getLabelsHash();
	my @values;

	$GROUPNODES = $$GROUP{group};
	foreach $groupnode (@$GROUPNODES)
	{
		$NODE = $DB->getNode($groupnode);
		next unless ( ( not $USER ) or ( $NODE->hasAccess( $USER, $perm ) ) );

		my $label = $$NODE{title};
		$label .= " ($$NODE{type}{title})" if ($showType);

		$$gLabels{ $$NODE{node_id} } = $label;
		push @values, $$NODE{node_id};
	}

	if ($sortby)
	{
		my $sort = $this->sortMenu( $sortby, \@values, $gLabels );
		push @$gValues, @$sort;
	}
	else
	{
		push @$gValues, @values;
	}

	return 1;
}

=cut


=head2 C<addHash>

Given a hashref, add the contents to the menu.  The keys of the hash should be
the values of the menu.  The values of the hash should be the string that is to
be seen by the user.  For example, if you want a popup menu with labels of
"yes" and "no" and values of '1' and '0', your hash should look like:

  { 1 => 'yes', 0 => 'no' }

=over 4

=item * $hashref

The reference to the hash that you want to add to the menu.

=item * $keysAreLabels

True if the keys of the hash should be what is visible to the user in the menu.
False if the values of the hash are what should be the labels.  This is so you
can use your hash data structure as it is without needing to make it conform to
what this expects.  For example, pass true if you have a hash like: 

  { yes => 1, no => 0 }

=item * $sortby

(optional) This specifies the order in which to sort the values. Either
'labels', 'labels reverse', 'values', or 'values reverse'.

=back

Returns true if successful, false otherwise.

=cut

sub addHash
{
	my ( $this, $hashref, $keysAreLabels, $sortby ) = @_;
	my $key;
	my $gValues = $this->getValuesArray();
	my $gLabels = $this->getLabelsHash();
	my @values;

	foreach $key ( keys %$hashref )
	{
		if ($keysAreLabels)
		{

			# the labels hash must labels{value} = 'label name'
			$$gLabels{ $$hashref{$key} } = $key;
			push @values, $$hashref{$key};
		}
		else
		{
			$$gLabels{$key} = $$hashref{$key};
			push @values, $key;
		}
	}

	if ($sortby)
	{
		my $sort = $this->sortMenu( $sortby, \@values, $gLabels );
		push @$gValues, @$sort;
	}
	else
	{
		push @$gValues, @values;
	}

	return 1;
}

=cut


=head2 C<addArray>

If you just have an array of items you want, you can pass them to this method
to have them added.  It is assumed that the array is in the order that you want
the items to appear in the list.

=over 4

=item * $values

An array ref of the values to add to the list.

=back

Returns true if successful, false otherwise.

=cut

sub addArray
{
	my ( $this, $values ) = @_;

	return unless ($values);
	my $gValues = $this->getValuesArray();

	push @$gValues, @$values;

	return 1;
}

=cut


=head2 C<addLabels>

Add new labels to the menu.

=cut

=over 4

=item * $labels

A hashref of labels to add.  It can be either 'value' =E<gt> 'label', or
'label' =E<gt> 'value'.  Just specify $keysAreLabels as appropriate.

=item * $keyAreLabels

True if the keys of the hash are to be the visible labels, false if the values
of the hash are to be the visible labels.

=back

Returns true if successful, false otherwise.

=cut

sub addLabels
{
	my ( $this, $labels, $keysAreLabels ) = @_;

	return unless ($labels);
	my $gLabels = $this->getLabelsHash();

	$keysAreLabels ||= 0;

	if ($keysAreLabels)
	{
		@$gLabels{ values %$labels } = keys %$labels;
	}
	else
	{
		@$gLabels{ keys %$labels } = values %$labels;
	}

	return 1;
}

=cut


=head2 C<genPopupMenu>

Based on how the menu was set up, generate the HTML for the popup menu and
return it.

=over 4

=item * $cgi

The CGI object that we should use to create the HTML.

=item * $name

The string name of the form item.

=item * $selected

The option that is selected by default.  This should be one of the values in
the values array.

=back

Returns the HTML for the popup menu.

=cut

sub genPopupMenu
{
	my ( $this, $cgi, $name, $selected ) = @_;

	return $cgi->popup_menu(
		-name    => $name,
		-values  => $this->getValuesArray(),
		-default => $selected,
		-labels  => $this->getLabelsHash()
	);
}

=cut


=head2 C<genListMenu>

Create the HTML needed for a scrolling list form item.

=over 4

=item * $cgi

The CGI object that we should use to generate the HTML.

=item * $name

The string name of the form item.

=item * $selected

The name of the option that is selected by default.  An array reference if the
default selection is more than one.  If blank, then nothing is selected by
default.

=item * $size

(optional) The number of options (lines) visible.

=item * $multi

(optional) 1 (true) if this list item should allow multiple selections and 0
(false) if not.

=back

Returns the HTML for this scrolling list form item.

=cut

sub genListMenu
{
	my ( $this, $cgi, $name, $selected, $size, $multi ) = @_;

	# We want an array.  If we have a scalar, make it an array with one elem
	$selected = [$selected] unless ( ref $selected eq "ARRAY" );

	$multi ||= 0;
	$size  ||= 6;

	return $cgi->scrolling_list(
		-name     => $name,
		-values   => $this->getValuesArray(),
		-default  => $selected,
		-size     => $size,
		-multiple => $multi,
		-labels   => $this->getLabelsHash()
	);
}

=cut


=head2 C<genObject>

This is called to generate the needed HTML for this menu object.  NOTE!!! This
does virtually nothing!  You will either need to call genPopupMenu or
genListMenu manually if you want to use this object directly.  Basically, this
object can be used create custom menus that the other derived objects of this
object do not provide.

=cut

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this popupmenu is to be bound to a field on a node.  undef if
this item is not bound.

=item * $field

The field on the node that this popupmenu is bound to.  If $bindNode is undef,
this is ignored.

=item * $name

The name of the form object, i.e. E<lt>input type=text name=$nameE<gt>.

=back

Returns the generated HTML for this popupmenu object.

=cut

sub genObject
{
	my $this = shift @_;

	return $this->SUPER::genObject(@_);
}

1;
