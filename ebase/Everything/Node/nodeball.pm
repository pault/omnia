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
use Everything::Node::setting;


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
		my $user = $$this{DB}->getNode($USER);
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
	my ($this, $vars) = @_;
	
	$this->setHash($vars, "vars");
}


#############################################################################
sub hasVars
{
	return 1;
}


#############################################################################
#	Sub
#		fieldToXML
#
#	Purpose
#		A nodeball has both setting and group type information.  A nodeball
#		derives from nodegroup, but we also need to handle our setting
#		info.  The base setting object will handle that and pass the rest
#		to our parent.
#
sub fieldToXML
{
	my ($this, $field) = @_;

	if($field eq 'vars')
	{
		return Everything::Node::setting::fieldToXML($this, $field);
	}
	else
	{
		return $this->SUPER();
	}
}


#############################################################################
sub xmlTag
{
	my ($this, $TAG) = @_;
	my $tagname = $TAG->getTagName();

	if($tagname =~ /vars/i)
	{
		# Since we derive from nodegroup, but also have some setting
		# type functionality, we need to use the setting stuff here.
		return Everything::Node::setting::xmlTag($this, $TAG);
	}
	else
	{
		return $this->SUPER(); 
	}
}


#############################################################################
sub applyXMLFix
{
	my ($this, $FIX, $printError) = @_;

	if($$FIX{fixBy} eq "setting")
	{
		return Everything::Node::setting::applyXMLFix($this, $FIX, $printError);
	}
	else
	{
		return $this->SUPER();
	}
}


#############################################################################
# End of package
#############################################################################

1;
