package Everything::Node::FormObject;

#############################################################################
#   Everything::Node::FormObject
#		Package the implements the base FormObject functionality.
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
#		This generates the HTML necessary to make a form item on the
#		page.  This is the base implementation of a form object.  It
#		just sets up some data fields on this object in preparation
#		for the derived classes to do something interesting.
#
sub genItem
{
	my ($this, $query, $bindNode, $field, $title) = @_; 

	$$this{form_query} = $query;
	$$this{form_bindNode} = $bindNode;
	$$this{form_field} = $field;
	$$this{form_title} = $title;

	return $this->genBindField();
}


sub cgiVerify
{
	my ($this, $cginame) = @_;

	die "cgiVerify() not implemented!";
}


sub cgiUpdate
{
	my ($this, $cginame) = @_;

	die "cgiUpdate() not implemented!";
}

sub genBindField
{
	my ($this, $value) = @_;
	my $bindNode = $$this{form_bindNode};

	return "" unless($bindNode);

	$value ||= $$this{form_field};
	return $$this{form_query}->hidden(
		-name => 'formbind_' . $$this{type}{title} . '_' . $$this{form_title},
		-value => "$$bindNode{node_id}:$value", -override => 1);
}

#############################################################################
# End of package
#############################################################################

1;
