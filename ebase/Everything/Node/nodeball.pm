package Everything::Node::nodeball;

#############################################################################
#   Everything::Node::nodeball
#       Package the implements the base functionality for nodeball
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;


#############################################################################
#	Sub
#		insert
#
#	Purpose
#		Override the default insert to have the nodeball created with
#		some defaults.
#
sub insert
{
	my ($this, $USER) = @_;
	my $insert_id = $this->SUPER();

	unless($insert_id)
	{
		print "got bad insert id!\n";
		return 0;
	}
	
	my $VARS;
	
	$VARS = $this->getVars();
	
	# If the node was not inserted with some vars, we need to set some.
	unless($VARS)
	{
		my $user = getNode($USER);
		my $title = "ROOT";

		$title = $$user{title} if($user && (ref $user));
		
		$VARS = { 
			author => $title,
			version => "0.1.1",
			description => "No description" };
		
		$this->setVars($VARS, $USER);
	}

	return $insert_id;
}


#############################################################################
sub getVars
{
	my ($this) = @_;
	
	return $this->getHash("vars");
}


#############################################################################
sub setVars
{
	my ($this, $vars, $USER) = @_;
	
	$this->setHash($vars, $USER, "vars");
}


#############################################################################
sub hasVars
{
	return 1;
}


#############################################################################
#	Sub
#		getFieldDatatype
#
#	Purpose
#		Nodeballs also have some "setting" type info.  We need to provide
#		that info here.
#
sub getFieldDatatype
{
	my ($this, $field) = @_;

	return "vars" if($field eq "vars");
	return $this->SUPER();
}


#############################################################################
# End of package
#############################################################################

1;
