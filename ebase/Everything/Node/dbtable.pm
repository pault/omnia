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
#		Allowed characters and length limits are taken from MySQL table naming
#		conventions.
#
sub insert
{
	my ($this, $USER) = @_;
	my $title = $$this{title};

	# sanity checks -- valid node titles may be invalid database table names
	my $bad_title = 0;

	# limit is 61 characters, as we append '_id' to title for primary key name
	if (length $title > 61) {
		Everything::logErrors('dbtable name must not exceed 61 characters!',
			'', '', '');
		$bad_title = 1;
	}

	# check for allowed characters
	if ($title =~ tr/A-Za-z0-9_$//c ) {
		Everything::logErrors('dbtable name contains invalid characters.
		 	 Only alphanumerics and the underscore are allowed.  No spaces!',
			 '', '', '');
		$bad_title = 1;
	}
	return if $bad_title;

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
