package Everything::Node::nodelet;

#############################################################################
#   Everything::Node::nodelet
#       Package the implements the base nodelet functionality
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;


#############################################################################
#	Sub
#		insert
#
#	Purpose
#		We need to set up some default settings when a nodelet is
#		inserted.
#
sub insert
{
	my ($this, $USER) = @_;

	my $GNC = $$this{DB}->getNode("general nodelet container", "container");

	# If this gets set to something inappropriate, we can have some
	# infinite container loops.
	if($GNC)
	{
		$$this{parent_container} = $$GNC{node_id};
	}
	else
	{
		$$this{parent_container} = 0;
	}

	$this->SUPER();
}

#############################################################################
# End of package
#############################################################################

1;