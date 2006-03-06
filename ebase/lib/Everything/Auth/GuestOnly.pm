package Everything::Auth::GuestOnly;

#############################################################################
#       Everything Pass-Through Autentication
#       Copyright 2002 Everything Development Company
#       http://www.everydevel.com/
#
#       Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;



sub new
{
        my $class = shift;
        my $this;
	$this->{Auth} = "GuestOnly";
        return bless $this,$class;
}

#############################################################################
#
#	loginUser, logoutUser, authUser
#
#	This module is completely implemented despite the emptiness seen 
#	below.  When returning undef from all of these applications
#	the code will default to guestUser in all cases, speeding up the
#	site greatly.


sub loginUser
{
	return undef;
}

sub logoutUser
{
	return undef;
}

sub authUser
{
	return undef;
}

1;
