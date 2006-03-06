=head1 Everything::HTML::FormObject::NodetypeMenu

Copyright 2001 - 2003 Everything Development Inc.

Package that implements the base NodetypeMenu functionality.

=cut

package Everything::HTML::FormObject::NodetypeMenu;

use strict;
use Everything;

use Everything::HTML::FormObject::TypeMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::TypeMenu");

=cut

=head2 C<genObject>

This is called to generate the needed HTML for this NodetypeMenu form object. 

=cut

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this NodetypeMenu is to be bound to a field on a node.

=item * $field

The field on the node that this NodetypeMenu is bound to.  If $bindNode is
undef, this is ignored.

=item * $name

The name of the form object, i.e. E<lt>input type=text name=$nameE<gt>.

=item * $omitutil

Omit "utility" types.  Utility types are those that inherit from "utility".
All types that derive from utilty *cannot* be instantiated.  utility types
exist for the sole purpose of providing methods.  They are not nodes in the
database.  You may want to turn this on if you want a menu to select types when
creating new nodes.  Since nodes of "utility" types cannot be created, you will
probably want to omit them.

=item * $USER

Used for authorization.  If given, the menu will only show the types that the
user has permission to create.

=item * $none

(optional) True if the menu should contain an option of 'None' (with value of
$none).

=item * $inherit

(optional) True if the menu should contain an option of 'Inherit' (with value
of $inherit).

=back

Returns the generated HTML for this NodetypeMenu object.

=cut

sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $omitutil, $USER, $none,
		$inherit, $inherittxt) = getParamArray(
		"query, bindNode, field, name, omitutil, USER, none, " .
		"inherit, inherittxt", @_);

	$omitutil ||= 0;
	$USER ||= -1;

	$$this{omitutil} = $omitutil;
	my $html = $this->SUPER::genObject($query, $bindNode, $field, $name,
		'nodetype', 'AUTO', $USER, 'c', $none, $inherit);

	return $html;
}


#############################################################################
sub addTypes
{
	my ($this, $type, $USER, $perm, $none, $inherit) = @_;
	
	$USER ||= -1;
	$perm ||= 'r';
	$this->addHash({"None" => $none}, 1) if(defined $none);
	$this->addHash({"Inherit" => $inherit}, 1) if(defined $inherit);

	my @RAWTYPES = $DB->getAllTypes();
	my %types;
	my $omitutil = $$this{omitutil};
	my @SORTED;
	my @TYPES;

	@SORTED = sort { $$a{title} cmp $$b{title} } @RAWTYPES;

	foreach my $TYPE (@SORTED)
	{
		next unless($TYPE->hasTypeAccess($USER, 'c'));
		next if($omitutil && $TYPE->derivesFrom("utility"));
		push @TYPES, $TYPE;
	}

	my $MENU = $this->createTree(\@TYPES);
	my %labels;
	my @array;
	
	foreach my $item (@$MENU)
	{
		$labels{$$item{label}} = $$item{value};
		push @array, $$item{value};
	}

	$this->addArray(\@array);
	$this->addLabels(\%labels, 1);	

	return 1;
}


=cut

=head2 C<createTree>

This is the core of this object.  This generates a list of nodetypes base on
their inheritance.  They get indented for each level below the 'node' nodetype
and organized by type

=over 4

=item * $types

An array ref of all the nodetypes in the system.

=item * $current

Internal use only.  Don't pass anything when calling this.

=back

Returns an array ref of hashrefs that can be then be parsed apart and inserted
into the menu.

  { label => label, value => value } 

=cut

sub createTree
{
	my ($this, $types, $current) = @_;
	my $type;
	my @list;

	$current ||= 0;

	foreach $type (@$types)
	{
		next if($$type{extends_nodetype} ne $current);

		my $tmp = { 'label' => " + " . $$type{title},
			'value' => $$type{node_id} };
		push @list, $tmp;

		my $sub;
		$sub = $this->createTree($types, $$type{node_id});

		foreach my $item (@$sub)
		{
			$$item{label} = " - -" . $$item{label};
		}

		push @list, @$sub;
	}

	return \@list;
}

1;
