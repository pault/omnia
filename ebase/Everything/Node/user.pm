package Everything::Node::user;

#############################################################################
#   Everything::Node::user
#       Package the implements the base node functionality
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;


sub isGod
{
	my ($this) = @_;
	my $GODS = $$this{DB}->getNode('gods', 'usergroup');

	return 0 unless($GODS);
	return $GODS->inGroup($this);
}
	

#############################################################################
sub getNodeKeys
{
	my ($this, $forExport) = @_;
	my $keys = $this->SUPER();
	
	if($forExport)
	{
		# Remove these fields if we are exporting user nodes.
		delete $$keys{passwd};
		delete $$keys{lasttime};
	}

	return $keys;
}


#############################################################################
# End of package
#############################################################################

1;
