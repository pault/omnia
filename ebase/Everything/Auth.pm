package Everything::Auth;

#############################################################################
#       Everything authentication routines
#       Copyright 2002 Everything Development Company
#       http://www.everydevel.com/
#
#       Format: tabs = 4 spaces
#
#############################################################################

use strict;
use Everything;

sub BEGIN {
        use Exporter ();
        use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
        @ISA=qw(Exporter);
        @EXPORT=qw(
                loginUser
                logoutUser
                authUser
                );
        }

#############################################################################
#
#	Sub
#		new
#
#	Purpose
#		We need to instantiate the $AUTH object once per fork, and 
#		this handles it. The aggrigation to each of the interfaces is
#		supposedly seemless; IE, Everything::HTML doesn't really
#		need to know that another plugin is there.  We should be able
#		to swap them out without changing anything.


sub new
{
        my ($class, $options) = @_;
	$options ||= {};

	#We may not always get the guest user pref (if ever). We can default to plain Guest User
	$options->{guest_user} ||= $DB->getNode("Guest User", "user")->{node_id};

	my $plugin = $options->{Auth};

	$plugin ||= "EveryAuth";  #default module
	my $authtype = "Everything::Auth::$plugin";
	my $this;
	my $obj; 
	eval("use $authtype; \$obj = new $authtype");

	die "No authentication plugin!" unless $obj;

	$this->{type} = $plugin;
	$this->{plugin} = $obj;
	$this->{plugin}->{options} = $options;
	$this->{options} = $options;
	return bless $this, $class;
}


#############################################################################
#
#	Sub
#		loginUser
#
#	Purpose
#		This simply aggrigates to the plugin's loginUser().
#		It is called by opLogin

sub loginUser
{
	my $this = shift;
	my $user = $this->{plugin}->loginUser(@_);

	return $this->generateSession($user);
	
}

#############################################################################
#
#	Sub
#		authUser
#
#	Purpose
#		This simply aggrigates to the plugin's authUser().
#		It should be called every pageload


sub authUser
{
	my $this = shift;
	my $user = $this->{plugin}->authUser(@_);

	return $this->generateSession($user);

}

#############################################################################
#
#	Sub
#		logoutUser
#
#	Purpose
#		This simply aggrigates to the plugin's logoutUser().
#		It should be called by opLogout();


sub logoutUser
{
	my $this = shift;
	my $user = $this->{plugin}->logoutUser(@_);

	return $this->generateSession($user);
}


#############################################################################
#
#	Sub
#		generateSession
#
#	Purpose
#		While a plugin could generate the guestUser information on
#		it's own on failure, generateSession can handle this. Also
#		this populates what is to become the VARS hash for the user
#		saving each auth module the trouble of having to do so. 


sub generateSession
{
	my $this = shift;
	my $user = shift;

	$user ||= $DB->getNode($this->{options}->{guest_user});

	#No user yet? Now would be a good time to cry...
	die "Unable to get user!" unless ($user);

	return ($user, $user->getVars());

}

1;
