package Everything::Node::htmlpage;

#############################################################################
#   Everything::Node::htmlpage
#       Package the implements the base htmlpage functionality
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
#		We need to set up some default settings when a htmlpage is
#		inserted.
#
sub insert
{
	my ($this, $USER) = @_;

 # If there is no parent container set, we need a default
 unless($$this{parent_container})
 {
 my $GNC = $$this{DB}->getNode("general nodelet container", "container");
 $$this{parent_container} = 0;
 $$this{parent_container} = $GNC if($GNC);
 }

$this->SUPER();




}

#############################################################################
# End of package
#############################################################################

1;
