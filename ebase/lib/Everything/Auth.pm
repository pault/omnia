=cut


=head1 Everything::Auth

Everything authentication routines

=cut

#############################################################################
#
#  Copyright 2002 - 2003 Everything Development Company
#  http://www.everydevel.com/
#
#  Format: tabs = 4 spaces
#
#############################################################################

package Everything::Auth;

use strict;
use Everything qw/$DB/;

=cut


=head2 C<new>

We need to instantiate the $AUTH object once per fork, and this handles it. The
aggrigation to each of the interfaces is supposedly seemless; IE,
Everything::HTML doesn't really need to know that another plugin is there.  We
should be able to swap them out without changing anything.

It takes one argument, a hash ref.  The hash ref takes the following key => value pairs.

=over

=item Auth => name of the authorisation module to use.
Defaults to EveryAuth.

=item guest_user => a node object that is the Guest User to use.

The authorisation modules may accept other options.  Check their document.

=back

=cut

sub new
{
	my ( $class, $options ) = @_;
	$options ||= {};

	# We may not always get the guest user pref (if ever). We can default to
	# plain Guest User

	$options->{guest_user} ||= $DB->getNode( 'Guest User', 'user' )->{node_id};

	# default module
	my $plugin   = $options->{Auth} || 'EveryAuth';
	my $authtype = "Everything::Auth::$plugin";

	my $obj = eval {
		( my $path = $authtype . '.pm' ) =~ s!::!/!g;
		require $path or print "NOPE\n";
		$authtype->new($options);
	};

	die "No authentication plugin!" if $@ or !$obj;

	$obj->{options} = $options;

	bless {
		type    => $plugin,
		plugin  => $obj,
		options => $options,
	}, $class;
}

=cut


=head2 C<loginUser>

This simply delegates to the plugin's loginUser().  It is called by opLogin.

=cut

sub loginUser
{
	my $this = shift;
	my $user = $this->{plugin}->loginUser(@_);

	return $this->generateSession($user);
}

=cut


=head2 C<authUser>

This simply delegates to the plugin's authUser().  It should be called every
pageload.

=cut

sub authUser
{
	my $this = shift;
	my $user = $this->{plugin}->authUser(@_);

	return $this->generateSession($user);
}

=cut


=head2 C<logoutUser>

This simply delegates to the plugin's logoutUser().  It should be called by
opLogout().

=cut

sub logoutUser
{
	my $this = shift;
	my $user = $this->{plugin}->logoutUser(@_);

	return $this->generateSession($user);
}

=cut


=head2 C<generateSession>

While a plugin could generate the guestUser information on its own on failure,
generateSession can handle this. Also this populates what is to become the VARS
hash for the user saving each auth module the trouble of having to do so. 

=cut

sub generateSession
{
	my ( $this, $user ) = @_;

	$user ||= $DB->getNode( $this->{options}->{guest_user} );

	# No user yet? Now would be a good time to cry...
	die "Unable to get user!" unless $user;

	return ( $user, $user->getVars() );
}

1;
