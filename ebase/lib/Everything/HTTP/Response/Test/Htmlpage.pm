package Everything::HTTP::Response::Test::Htmlpage;

use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Scalar::Util 'blessed';
use Everything::HTTP::Response::Htmlpage;
use Everything::HTTP::Request;

use base 'Test::Class';
use strict;
use warnings;

sub module_class {
    my $self = shift;
    my $name = blessed($self);
    $name =~ s/Test:://;
    return $name;
}

sub startup : Test(startup=>2) {
    my $self = shift;
    $self->{class} = $self->module_class();
    use_ok( $self->{class} ) || die $self->{class};
    my $mock = Test::MockObject->new;

    $mock->set_always( getNode => $mock );
    $mock->set_true( 'set_theme', 'param', 'get_type_nodetype' );
    $mock->set_always( 'get_user_vars' => {} );
    $mock->set_always( '-get_theme',    $mock );
    $mock->set_always( '-get_node',     $mock );
    $mock->set_always( '-get_nodebase', $mock );
    $mock->set_always( '-get_cgi',      $mock );
    $mock->set_always( 'getType',       $mock );
    $mock->{title} = 'a title';
    $self->{mock}  = $mock;
    isa_ok( $self->{instance} = $self->{class}->new($mock), $self->{class} );

}

sub test_http_response : Test(2) {
    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};
    can_ok( $class, 'create_http_body' );
    can_ok( $class, 'content_type' );

}

sub test_check_permissions : Test(7) {
    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};

    my $mock = $self->{mock};
    $mock->clear;
    $instance->set_request($mock);
    $mock->set_always( -get_user             => $mock );
    $mock->set_always( -hasAccess            => 0 );
    $mock->set_always( -get_permissionneeded => 'r' );
    $mock->set_always( -get_system_vars =>
          { permissionDenied_node => 999, nodeLocked_node => 1001 } );

    ok( !$instance->check_permissions,
        '...if no access check permissions returns false.' );
    is( $instance->get_redirect, 999,
        '...and redirects to the permission deniend page.' );

    $mock->set_always( -hasAccess => 1 );
    ok( $instance->check_permissions,
        '...returns true if the user has the correct permissions.' );

    ## check node locking
    $mock->clear;
    $mock->set_always( -get_permissionneeded => 'w' );
    $mock->set_true('lock');
    ok( $instance->check_permissions,
        '...access to edit htmlpage if we can obtain node lock.' );

    $mock->clear;
    $mock->set_false('lock');
    ok( !$instance->check_permissions,
        '...but no access to edit htmlpage without the node lock.' );
    my ( $method, $args ) = $mock->next_call(2);
    is(
        "$method@$args",
        "param$mock displaytype display",
        '...and sets param on cgi to "display".'
    );
    is( $instance->get_redirect, 1001, '...and redirects to nodeLocked_node.' );
}

sub test_get_theme : Test(2) {

    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};
    my $e        = $instance->get_request;
    can_ok( $class, 'getTheme' ) || return;
    my $mock = $self->{mock};
    $mock->set_always( 'get_user_vars', { key => 'value' } );

    $e->set_always( get_system_vars => { one => 'two' } )
      ->set_always( get_db => $mock );
    $mock->set_series( isOfType => 1, 0 )
      ->set_always( 'getVars', { var1 => 'one', var2 => 'two' } );
    ok( $instance->getTheme( $instance->get_request ) );

}

sub test_select_htmlpage : Test(8) {

    my $self     = shift;
    my $class    = $self->{class};
    my $instance = Test::MockObject::Extends->new( $self->{instance} );

    my $mock = $self->{mock};
    $mock->clear;

    $instance->set_request($mock);

    $mock->set_always( -get_theme     => $mock );
    $mock->set_always( -get_user_vars => {} );
    $mock->set_always( -get_cgi       => $mock );
    $mock->set_always( param          => 'adisplaytype' );
    $mock->set_always( '-get_user_vars', { key => 'value' } );

    $mock->set_always( getType            => $mock );
    $mock->set_always( -get_type_nodetype => 222 );
    $mock->set_always( -get_nodebase      => $mock );

    $instance->set_always( get_page_for_type => $mock );

    is( $instance->select_htmlpage, $mock, '...should retrieve an htmlpage.' );

    my ( $method, $args ) = $mock->next_call();
    is( $method . $$args[1],
        'paramdisplaytype', '...gets display type from cgi.' );
    ( $method, $args ) = $mock->next_call();
    is( $method . $$args[1], 'getType222', '...retrieves htmlpage nodetype.' );
    ( $method, $args ) = $instance->next_call();
    is(
        "$method@$args",
        "get_page_for_type$instance $mock adisplaytype",
        '...gets display type calling with display name.'
    );

    $mock->set_always( param => '' );

    $instance->set_always( get_page_for_type => 'htmlpagenode' );

    is( $instance->select_htmlpage, 'htmlpagenode',
        '...should retrieve a page if param is not set.' );
    ( $method, $args ) = $instance->next_call();
    is(
        "$method@$args",
        "get_page_for_type$instance $mock display",
        '...and gets the "display" displaytype.'
    );

    $mock->set_always(
        -get_user_vars => { 'displaypref_a title' => 'varsdisplaytype' } );

    $instance->select_htmlpage;
    ( $method, $args ) = $instance->next_call();
    is(
        "$method@$args",
        "get_page_for_type$instance $mock varsdisplaytype",
        '...and get the display type specified by user vars.'
    );

    $mock->set_always( -get_user_vars => {} );
    $mock->{'displaypref_a title'} = 'themedisplaytype';
    $instance->select_htmlpage;
    ( $method, $args ) = $instance->next_call();
    is(
        "$method@$args",
        "get_page_for_type$instance $mock themedisplaytype",
        '...or gets the display type specified by the theme.'
    );

}

1;
