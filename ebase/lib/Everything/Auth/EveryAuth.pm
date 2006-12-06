package Everything::Auth::EveryAuth;

#############################################################################
#       Standard Everything Autentication
#       Copyright 2002 Everything Development Company
#       http://www.everydevel.com/
#
#       Format: tabs = 4 spaces
#
#############################################################################

use strict;
use Everything;
use Everything::HTML;
use Everything::Util;

#############################################################################
#
#	Sub
#		new
#	Purpose
#		Vanilla constructor for this module.

sub new
{
	my $class = shift;
	my $this;
	$this->{Auth} = "EveryAuth";
	return bless $this, $class;
}

#############################################################################
#
#	Sub
#		loginUser
#	Purpose
#		Determine who is logging in, inside of opLogin
#	Parameters
#		(none)
#	Returns
#		The $USER hash to be pushed into global context or undef for
#		the guest user;

sub loginUser
{

	my $this   = shift;
	my $user   = $query->param("user");
	my $passwd = $query->param("passwd");
	my $cookie;

	my $U = $DB->getNode( $user, 'user' );
	$user = $$U{title} if $U;

	my $USER_HASH;

	$USER_HASH = confirmUser( $user, crypt( $passwd, $user ) ) if $user;

	# If the user/passwd was correct, set a cookie on the users
	# browser.
	$cookie = $query->cookie(
		-name    => "userpass",
		-value   => $query->escape( $user . '|' . crypt( $passwd, $user ) ),
		-expires => $query->param("expires")
		)
		if $USER_HASH;

	$$USER_HASH{cookie} = $cookie if ( $cookie and $USER_HASH );

	return $USER_HASH;

}

#############################################################################
#
#	Sub
#		logoutUser
#	Purpose
#		Destroys the current session
#	Parameters
#		(none)
#	Returns
#		The $USER hash to be pushed into global context (logout
#		failed?) or undef to be kicked back to the guest user.  It
#		is in theory possible to be kicked back to another user, esp
#		if we were to implement some kind of su-like authentication
#		scheme, and you weren't currently at your old user

sub logoutUser
{

	my $this = shift;

	# The user is logging out.  Nuke their cookie.
	my $cookie = $query->cookie( -name => 'userpass', -value => "" );

#We need to force the guest user on logouts here, otherwise the cookie won't get cleared.
	my $user = $DB->getNode( $this->{options}->{guest_user} );
	$$user{cookie} = $cookie if ($cookie);

	return $user;

}

#############################################################################
#
#	Sub
#		authUser
#	Purpose
#		Per page load, figure out who is requesting data
#	Parameters
#		(none)
#	Returns
#		The $USER hash of the person who is requesting information
#		or undef to become the guest user

sub authUser
{
	my $this = shift;
	my $USER_HASH;

	if ( my $oldcookie = $query->cookie("userpass") )
	{
		$USER_HASH =
			confirmUser(
			split( /\|/, Everything::Util::unescape($oldcookie) ) );
	}
	return unless $USER_HASH;
	return $USER_HASH;

}

#############################################################################
#       Sub
#               confirmUser
#
#       Purpose
#               Given a username and the passwd they entered in encrypted form,
#               verify that the passwd/username combo is correct.
#
#       Parameters
#               $nick - the user name
#               $crpasswd - the passwd that the user entered, encrypted
#
#       Returns
#               The USER node if everything checks out.  undef if the
#               username/passwd combo failed.
#
sub confirmUser
{
	my ( $nick, $crpasswd ) = @_;
	my $user = $DB->getNode( $nick, $DB->getType('user') );
	my $genCrypt;

	return undef unless ($user);

	$genCrypt = crypt( $$user{passwd}, $$user{title} );

	if ( $genCrypt eq $crpasswd )
	{
		$$user{lasttime} = $DB->sqlSelect("NOW()");
		return $user;
	}

	return undef;
}

1;
