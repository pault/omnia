package Everything::Node::permissionmenu;

#############################################################################
#   Everything::Node::permissionmenu
#		Package the implements the base permissionmenu functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;


#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this permissionmenu
#		form object.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this permissionmenu is to be bound to a field
#			on a node.
#		$field - the field on the node that this permissionmenu is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$default - value this object will contain as its initial default.
#			Specify 'AUTO' if you want to use the value of the field this
#			object is bound to, if it is bound
#
#	Returns
#		The generated HTML for this permissionmenu object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $perm, $default) =  getParamArray(
		"query, bindNode, field, name, perm, default", @_);

	$name ||= $field;
	$default ||= "AUTO";

	my %masks;
	$masks{r} = 0;
	$masks{w} = 1;
	$masks{x} = 2;
	$masks{d} = 3;
	$masks{c} = 4;

	my %labels;
	$labels{r} = 'Read';
	$labels{w} = 'Write';
	$labels{x} = 'Execute';
	$labels{d} = 'Delete';
	$labels{c} = 'Create';

	unless($perm && defined $masks{$perm})
	{
		warn("Incorrect Permission! (need r,w,x,d, or c)");
		return "";
	}

	my $html = $this->SUPER($query, $bindNode, $field.":$perm", $name) . "\n";
	
	if($default eq "AUTO" && $bindNode)
	{
		my $perms = $$bindNode{$field};
		$default = substr($perms, $masks{$perm}, 1);
	}
	elsif(not $bindNode)
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
	my $perm;

	($field, $perm) = split(':', $field);

	# Make sure this is not a restricted field that we cannot update
	# directly.
	return 0 unless($overrideVerify or $NODE->verifyFieldUpdate($field));

	my %masks;
	$masks{r} = 0;
	$masks{w} = 1;
	$masks{x} = 2;
	$masks{d} = 3;
	$masks{c} = 4;

	$value ||= "i";

	# Perl at it's best.  Assigning a value to a substring to overwrite
	# the old permission setting.
	substr($$NODE{$field}, $masks{$perm}, 1) = $value;

	return 1;
}


#############################################################################
# End of package
#############################################################################

1;


