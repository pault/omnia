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
	$this->{author_user} = $id;

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
	my $GODS = $this->{DB}->getNode('gods', 'usergroup');

	return 0 unless $GODS;

	return $GODS->inGroup($this) if $recurse;
	return $GODS->inGroupFast($this);
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

	my $SYS  = $this->{DB}->getNode('system settings', 'setting') or return 1;
	my $VARS = $SYS->getVars() or return 1;

	return ($VARS->{guest_user} == $this->{node_id});
}
	

#############################################################################
sub getNodeKeys
{
	my ($this, $forExport) = @_;
	my $keys = $this->SUPER();

	# Remove these fields if we are exporting user nodes.
	delete @$keys{qw( passwd lasttime )} if $forExport;

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
		title    => 1,
		karma    => 1,
		lasttime => 1,
	};

	my $verify = not exists $restrictedFields->{$field};
	return $verify && $this->SUPER();
}

# no conflicts if the user exists
sub conflictsWith { 0 }

# we don't allow user nodes to update
sub updateFromImport { 0 }

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
	my $title  = $this->{title} or return;

	return $title =~ tr/-<> !a-zA-Z0-9_//c ? 0 : 1;
}


=cut

=head2 C<getNodelets>

Purpose:
	Get the nodelets for the user, using the defaults if necessary.

Takes:
	$defaultGroup, the default nodelet group to use

Returns:
	a reference to a list of nodelets to display

=cut

sub getNodelets
{
	my ($this, $defaultGroup) = @_;
	my $VARS = $this->getVars();

	my @nodelets;
	@nodelets = split(/,/, $VARS->{nodelets}) if exists $VARS->{nodelets};

	return \@nodelets if @nodelets;

	my $NODELETGROUP;
	$NODELETGROUP = $this->{DB}->getNode($VARS->{nodelet_group})
		if exists $VARS->{nodelet_group};

	push @nodelets, @{ $NODELETGROUP->{group} }
		if $NODELETGROUP and $NODELETGROUP->isOfType('nodeletgroup');

	return \@nodelets if @nodelets;

	# push default nodelets on
	return $this->{DB}->getNode($defaultGroup)->{group};
}


#############################################################################
# End of package
#############################################################################

1;
