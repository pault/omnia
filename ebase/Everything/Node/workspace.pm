package Everything::Node::workspace;

#############################################################################
#   Everything::Node::workspace
#       Package the implements the base functionality for workspaces 
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;


#############################################################################
sub nuke  
{
	my ($this, $USER) = @_;

	return 0 unless($this->hasAccess($USER, "d"));

	$this->{DB}->sqlDelete("revision", "inside_workspace=$$this{node_id}");	
	$this->SUPER();
	
}


#############################################################################
# End of package
#############################################################################

1;
