package Everything::Node::dbtable;

#############################################################################
#   Everything::Node::dbtable
#       Package the implements the base functionality for dbtable
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
#		We need to create the table in the database.  This gets the
#		node inserted into the database first, then creates the table.
#
sub insert
{
	my ($this, $USER) = @_;
	my $result = $this->SUPER();

	$$this{DB}->createNodeTable($$this{title}) if($result > 0);

	return $result;
}


#############################################################################
#	Sub
#		nuke
#
#	Purpose
#		Overrides the base node::nuke so we can drop the database table
sub nuke
{
	my ($this, $USER) = @_;
	my $title = $$this{title};
	my $result = $this->SUPER();
	
	$$this{DB}->dropNodeTable($$this{title}) if($result > 0);

	return $result;
}


#############################################################################
# End of package
#############################################################################

1;
