package Everything::Auth::Test::EveryAuth;

use base 'Everything::Test::Abstract';
use Test::More;
use Test::MockObject;
use SUPER;
use CGI;
use strict;

sub startup : Test(startup=> 2) {
    my $self   = shift;
    my $module = $self->module_class();
    my $mock   = Test::MockObject->new;
    $mock->fake_module('Everything');
    $mock->fake_module('Everything::HTML');
    my $cgi = CGI->new;
    no strict 'refs';
    *{ $module . '::query' } = \$cgi;
    *{ $module . '::DB' }    = \$mock;
    use strict 'refs';
    use_ok($module) or exit;
    $self->{class} = $module;
    my $instance = $self->{class}->new;
    isa_ok( $instance, $self->{class} );
    $self->{instance} = $instance;
    $self->{mock}     = $mock;
    $self->{cgi}      = $cgi;

}

sub fixture : Test(setup) {
    my $self  = shift;
    my $class = $self->{class};
    my $cgi   = CGI->new;
    no strict 'refs';
    *{ $class . '::query' } = \$cgi;
    use strict 'refs';
    $self->{cgi} = $cgi;
}

##
## returns a node of type "user" setting $user->{cookie}.

sub test_login_user : Test(5) {
    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};
    my $cgi      = $self->{cgi};
    my $mock     = $self->{mock};
    $mock->clear;
    can_ok( $class, 'loginUser' );

    my @args = ();
    no strict 'refs';
    local *{ $class . '::confirmUser' };
    *{ $class . '::confirmUser' } = sub {
	@args = @_;
        return { user => { a => 'user' } };
    };
    use strict 'refs';

    $mock->set_always( 'getNode', $mock );
    $mock->{title} = "a user title";

    $cgi->param( 'user',   'username' );
    $cgi->param( 'passwd', 'pw' );

    my $result = $instance->loginUser;
    my ( $method, $args ) = $mock->next_call;
    is( $method, 'getNode', '...should get a user node.' );
    is( $args->[1], 'username', '... with args passed by the cgi object.' );

    ## and calls the confirm user sub
    is_deeply(
        [@args],
        [ 'a user title', crypt( 'pw', 'a user title' ) ],
        '...calls confirmUser with correct args'
    );

    my $cookie = $cgi->cookie(
        -name  => "userpass",
        -value =>
          $cgi->escape( 'a user title' . '|' . crypt( 'pw', 'a user title' ) ),
        -expires => $cgi->param("expires")
    );
    is( $result->{cookie}, $cookie,
        '...and returns a hash containing the cookie.' );
}

## returns the node of type 'user' specified by $self->
sub test_logout_user : Test(4) {
    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};
    my $cgi      = $self->{cgi};
    my $mock     = $self->{mock};
    $mock->clear;
    can_ok( $class, 'logoutUser' );
    my $result = $instance->logoutUser;
    my ( $method, $args ) = $mock->next_call;
    is( $method, 'getNode', '...gets the guest user node' );
    is(
        $args->[1],
        $instance->{options}->{guest_user},
        '...using the guest user'
    );
    my $cookie = $cgi->cookie(
        -name  => "userpass",
        -value => ''
    );
    is( $result->{cookie}, $cookie, '...unsetting the cookie value.' );
}

## gets cookie and compares it with db using confirmUser.
## returns undef on failure. A node of type user on success.
sub test_auth_user : Test(4) {

    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};
    my $cgi      = $self->{cgi};
    my $mock     = $self->{mock};
    $mock->set_always( 'getNode', $mock );
    can_ok( $class, 'authUser' ) || return "Can't authUser";

    ## mock the $query global
    my $fake_cgi = Test::MockObject->new;
    no strict 'refs';
    local *{ $class . '::query' };
    *{ $class . '::query' } = \$fake_cgi;
    use strict 'refs';

    my $oldcookie = 'a cookie';
    $fake_cgi->set_always( 'cookie', $oldcookie );

    ## setup confirmUser behaviour
    my @a = ();
    my @rv = ( { cookie => 'a cookie' }, undef );
    no strict 'refs';
    local *{ $class . '::confirmUser' };
    *{ $class . '::confirmUser' } = sub {
	@a = @_;
        return shift @rv;
    };
    use strict 'refs';

    my $result = $instance->authUser;
    is( "@a", $oldcookie, '...should grab the old cookie.' );
    is( $result->{cookie}, $oldcookie, '...returns the user with the cookie.' );

    $result = $instance->authUser;
    is( $result, undef, '...and returns undef on failure.' );
}

## takes two args.  The username and a hash of the password
## if no such username or passwords don't match returns undef
## other returns the user node.
sub test_confirm_user : Test(3) {

    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};
    my $cgi      = $self->{cgi};
    my $mock     = $self->{mock};

    can_ok( $class, 'confirmUser' ) || return "Can't confirmUser";

    my $pw          = 'password';
    my $name        = 'name';
    my $expected_rv =
      { title => $name, passwd => $pw, lasttime => 'timestamp' };
    my $crypted = crypt( $pw, $name );
    $mock->set_series( 'getNode', undef, $expected_rv );
    $mock->set_true('getType');
    $mock->set_always( 'sqlSelect', 'timestamp' );

    my $confirmUser = \&{ $class . '::confirmUser' };
    my $result = $confirmUser->( $name, $crypted );
    is( $result, undef, '..returns undef if getNode doesn\'t get a node.' );

    $result = $confirmUser->( $name, $crypted );
    is_deeply( $result, $expected_rv, '...returns node if passwords match.' );
}

1;
