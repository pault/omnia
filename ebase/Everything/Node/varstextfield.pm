package Everything::Node::varstextfield;

#############################################################################
#   Everything::Node::varstextfield
#		Package the implements the base varstextfield functionality.
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
#		This is called to generate the needed HTML for this varstextfield
#		form object.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this varstextfield is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this varstextfield is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$default - value this object will contain as its initial default.
#			If undef, this will default to what the field of the bindNode is.
#		$size - the width in characters of the varstextfield
#		$maxlen - the maximum number of characters this varstextfield will accept
#
#	Returns
#		The generated HTML for this varstextfield object
#
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

	my $html = $this->SUPER($query, $bindNode, $field . ":$var", $name) . "\n";
	
	if($default eq "AUTO" && $bindNode)
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


#############################################################################
#	Sub
#		cgiUpdate
#
#	Purpose
#		Called by the system to update this node
#
#	Parameters
#		$query - the CGI object used to fetch parameters
#		$name - the name of the object to update.  This will be the
#			'fieldname_varname_key' or 'fieldname_varname_value'
#			that was generated in the genObject method
#		$NODE - the node that we were bound to and need to update
#		$overrideverify - should we skip the verification that we
#			can update this particular var?  True if so, false otherwise.
#
#	Returns
#		0 (false) if failure, 1 (true) if successful
#
sub cgiUpdate
{
	my ($this, $query, $name, $NODE, $overrideVerify) = @_;
	my $param = $query->param($name);
	my $field = $this->getBindField($query, $name);
	my $value;

	
	# Make sure this is not a restricted field that we cannot update
	# directly.
	return 0 unless($overrideVerify or $NODE->verifyFieldUpdate($field));

	my $var;
	($field, $var) = split(':', $field);
	my $vars = $NODE->getHash($field);

	if($name =~ /_value$/)
	{
		# The value is specified by a textfield/popup menu combo.  We
		# need to get both to determine what was actually specified.

		my $menuname = $name . "_type";
		my $type = $query->param($menuname);
		my $value = $query->param($name);

		if($type > 0)
		{
			my $N = $$this{DB}->getNode($value, $type);
			$value = $$N{node_id} if($N);
		}

		$$vars{$var} = $value if($value);
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


#############################################################################
# End of package
#############################################################################

1;
