package Everything::Node::textfield;

#############################################################################
#   Everything::Node::textfield
#		Package the implements the base textfield functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;


#############################################################################
#	Sub
#		genItem
#
#	Purpose
#		This is called to generate the needed HTML for this textfield
#		form object.
#
#	Parameters
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this textfield is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this textfield is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$size - the width in characters of the textfield
#		$maxlen - the maximum number of characters this textfield will accept
#
#	Returns
#		The generated HTML for this textfield object
#
sub genItem
{
	my ($this, $query, $bindNode, $field, $name, $default, $size, $maxlen) = @_;
	my $html = $this->SUPER() . "\n";

	my $override = 1;
	
	if($default eq "AUTO")
	{
		$override = 0;
		$default = "";
		$default = $$bindNode{$field} if($bindNode);
	}

	$html .= $query->textfield(-name => $title, -default => $default,
		-size => $size, -maxlength => $maxlen, -override => $override);
	
	return $html;
}



sub cgiVerify
{
	# The basic textfield allows anything
	return 1;
}


sub cgiUpdate
{
	my ($this, $cgi, $USER) = @_;

	$cgi =~ /formobject_textfield_(.*)/;
	
	my $object = $1;
	my $param = $$this{form_query}->param($cgi);
	my $value = $$this{form_query}->param($object);
	my ($id, $field) = split(':', $param);

	my $node = $$this{DB}->getNode($id);

	$$node{$field} = $value;
}

#############################################################################
# End of package
#############################################################################

1;
