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



#############################################################################
#	Sub
#		insert
#
#	Purpose
#		We want all users to default to be owned by themselves.
#
sub insert
{
	my ($this, $USER) = @_;

	my $id = $this->SUPER() or return;

	# Make all new users default to owning themselves.
	$$this{author_user} = $id;

	$this->update($USER);

	return $id;
}


#############################################################################
#	Sub
#		isGod
#
#	Purpose
#		Checks to see if the given user is a god (in the gods group).
#
#	Parameters
#		$recurse - for speed purposes, this assumes that the gods group
#			is flat (it does not contain any other nodegroups that it would
#			need to traverse).  However, if the gods group does contain
#			nested groups, you can pass true here to check everything.
#			Note that turning this on is significantly slower.
#
#	Returns
#		True if the given user is a "god".  False otherwise.
#
sub isGod
{
	my ($this, $recurse) = @_;
	my $GODS = $$this{DB}->getNode('gods', 'usergroup');

	return 0 unless($GODS);

	if ($recurse) {
		return $GODS->inGroup($this);
	} else {
		return $GODS->inGroupFast($this);
	}
}


#############################################################################
#	Sub
#		isGuest
#
#	Purpose
#		Checks to see if the given user is the guest user.  Certain
#		system nodes need to exist for this check, if they do not,
#		this will default to true for security purposes.
#
#	Returns
#		True if the user is the guest user.  False if the user is not.
#
sub isGuest
{
	my ($this) = @_;
	my $SYS = $$this{DB}->getNode('system settings', 'setting') or return 1;

	my $VARS = $SYS->getVars() or return 1;

	return ($$VARS{guest_user} == $$this{node_id});
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
#	Sub
#		verifyFieldUpdate
#
#	Purpose
#		See Everything::Node::node::verifyFieldUpdate() for info.
#
sub verifyFieldUpdate
{
	my ($this, $field) = @_;

	my $restrictedFields = {
		'title' => 1,
		'karma' => 1,
		'lasttime' => 1
	};

	my $verify = (not exists $$restrictedFields{$field});
	return ($verify && $this->SUPER());
}

sub conflictsWith {
	#no conflicts if the user exists
	0;
}

sub updateFromImport {
	#we don't allow user nodes to update
	0;
}

=cut

=head2 C<restrictTitle>

Purpose:
	Prevent invalid characters in usernames (and optional near-duplicates)

Takes:
	$node, the node containing a C<title> field to check

Returns:
	true, if the title is allowable, false otherwise
=cut
sub restrictTitle
{
	my ($this) = @_;
	my $title  = $$this{title} or return;

	return if $title =~ tr/-<> !a-zA-Z0-9_//c;
	return 1;
}


#############################################################################
# End of package
#############################################################################

1;
