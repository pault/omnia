package Everything::HTML::FormObject::PermissionMenu;

#############################################################################
#   Everything::HTML::FormObject::PermissionMenu
#		Package the implements the base PermissionMenu functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");

my %masks = (
	r => 0,
	w => 1,
	x => 2,
	d => 3,
	c => 4,
);

my %labels = (
	r => 'Read',
	w => 'Write',
	x => 'Execute',
	d => 'Delete',
	c => 'Create',
);

#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this PermissionMenu
#		form object.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this PermissionMenu is to be bound to a field
#			on a node.
#		$field - the field on the node that this PermissionMenu is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$default - value this object will contain as its initial default.
#			Specify 'AUTO' if you want to use the value of the field this
#			object is bound to, if it is bound
#
#	Returns
#		The generated HTML for this PermissionMenu object
#
sub genObject
{
	my $this = shift;
	my ($query, $bindNode, $field, $name, $perm, $default) = 
		getParamArray( 'query, bindNode, field, name, perm, default', @_ );

	$name    ||= $field;
	$default ||= 'AUTO';
	unless($perm && defined $masks{$perm})
	{
		Everything::logErrors( 'Incorrect Permission (need r, w, x, d, or c)' );
		return '';
	}

	my $html = $this->SUPER::genObject($query, $bindNode,
		"${field}:$perm", $name) . "\n";
	
	if ($default eq 'AUTO' && UNIVERSAL::isa( $bindNode, 'Everything::Node' ))
	{
		my $perms = $bindNode->{$field};
		$default = substr($perms, $masks{$perm}, 1);
	}
	else
	{
		$default = undef;
	}

	$this->addHash( { $labels{$perm} => $perm }, 1);
	$this->addHash( { 'disable' => '-' }, 1);
	$this->addHash( { 'inherit' => 'i' }, 1);
	$html .= $this->genPopupMenu($query, $name, $default);

	return $html;
}


#############################################################################
sub cgiUpdate
{
	my ($this, $query, $name, $NODE, $overrideVerify) = @_;
	my $value = $query->param($name);
	my $field = $this->getBindField($query, $name);

	($field, my $perm) = split(':', $field);

	# Make sure this is not a restricted field that we cannot update directly.
	return 0 unless($overrideVerify or $NODE->verifyFieldUpdate($field));

	$value ||= 'i';

	# Perl at its best.  Assigning a value to a substring to overwrite
	# the old permission setting.
	substr($NODE->{$field}, $masks{$perm}, 1) = $value;

	return 1;
}


#############################################################################
# End of package
#############################################################################

1;


