package Everything::HTTP::Test::Request;

use Test::More;
use Test::MockObject;
use Scalar::Util qw/blessed/;
use base 'Test::Class';
use strict;
use warnings;

sub module_class {
    my $self = shift;
    my $name = blessed($self);
    $name =~ s/Test:://;
    return $name;
}

sub startup : Test(startup => 3) {
    my $self = shift;

    my $mock = Test::MockObject->new();
    my $class = $self->module_class;

    $mock->fake_module( 'Everything', initEverything => sub { undef; }, import => sub { $Everything::HTTP::Request::DB = $mock } );

    $mock->fake_module('Everything::HTML::Node::OpcodeGroup');
    $mock->fake_new('Everything::HTML::Node::OpcodeGroup');
    $mock->set_true('execOpCode');

    $mock->set_always( 'getNode', $mock );
    $mock->set_true( 'resetNodeCache', 'getType' );

    ## Mock a variable exported by Everything.pm
    *Everything::HTTP::Request::DB = \$mock;

    my $hashref = { key1 => 'value', key2 => 'value2' };
    $mock->set_always( 'getVars', $hashref );

    $mock->fake_module('Everything::Auth');
    $mock->fake_new('Everything::Auth');
    $mock->set_list( "authUser", $mock, $hashref );

    ## we mock this because HtmlPage tests haven't been written yet
    $mock->fake_module('Everything::HTML::Node::HtmlPage');

    ## Mock this because we don't really want to test it.
    $mock->fake_module('Everything::HTTP::ResponseFactory');
    $mock->fake_new('Everything::HTTP::ResponseFactory');
    $self->{mock}  = $mock;
    $self->{class} = $class;
    use_ok( $self->{class} ) or die;

    can_ok( $self->{class}, 'new' );
    my $instance = $self->{class}->new;
    isa_ok( $instance, $self->{class}, 'Is properly blessed' );
    $self->{instance} = $instance;
}

sub test_set_cgi_standard : Test(1) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    can_ok( $package, 'set_cgi_standard' );
}

sub test_setup_standard_system_vars : Test(1) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    can_ok( $package, 'setup_standard_system_vars' );
}

sub test_setup_nodebase_object : Test(1) {
    my $self     = shift;
    my $package  = $self->{class};
    my $mock = $self->{mock};
    $mock->set_true ( 'resetNodeCache' );
    my $instance = $self->{instance};
    my $hashref  = { key1 => 'value', key2 => 'value2' };
    my $string   = "db:init:string";
    local *Everything::initEverything;
    *Everything::initEverything = sub { $mock };
    ok( $instance->setup_nodebase_object( $string, $hashref, $hashref ) );

}

sub test_authorise_user : Test(1) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    can_ok( $package, 'authorise_user' );

}

sub test_get_set_system_vars : Test(4) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    my $hashref  = { one => 'two' };
    can_ok( $package, 'set_system_vars' );
    can_ok( $package, 'get_system_vars' );
    is_deeply( $instance->set_system_vars($hashref),
        $hashref, 'Does it return the correct value?' );
    is_deeply( $instance->get_system_vars, $hashref,
        "Do we get the right value?" );
}

sub test_get_set_user_vars : Test(4) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    my $hashref  = { one => 'two', three => 'four' };
    can_ok( $package, 'set_user_vars' );
    can_ok( $package, 'get_user_vars' );
    is_deeply( $instance->set_user_vars($hashref),
        $hashref, 'Does it return the correct value?' );
    is_deeply( $instance->get_user_vars, $hashref,
        "Do we get the right value?" );

}

sub test_get_set_options : Test(4) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $hashref  = { one => 'two' };

    can_ok( $package, 'set_options' );
    can_ok( $package, 'get_options' );
    is_deeply( $instance->set_options($hashref),
        $hashref, 'Does it return the correct value?' );
    is_deeply( $instance->get_options, $hashref, "Do we get the right value?" );

}

sub test_get_set_user : Test(4) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $mock     = $self->{mock};

    can_ok( $package, 'get_user' );
    can_ok( $package, 'set_user' );
    is_deeply( $instance->set_user($mock),
        $mock, 'Does it return the correct value?' );
    is_deeply( $instance->get_user, $mock, "Do we get the right value?" );

}

sub test_get_set_node : Test(4) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $mock     = $self->{mock};

    can_ok( $package, 'get_user' );
    can_ok( $package, 'set_user' );
    is_deeply( $instance->set_node($mock),
        $mock, 'Does it return the correct value?' );
    is_deeply( $instance->get_node, $mock, "Do we get the right value?" );

}

sub test_get_set_theme : Test(4) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    my $hashref  = { one => 'two' };

    can_ok( $package, 'set_options' );
    can_ok( $package, 'get_options' );
    is_deeply( $instance->set_theme($hashref),
        $hashref, 'Does it return the correct value?' );
    is_deeply( $instance->get_theme, $hashref, "Do we get the right value?" );

}

sub test_get_set_initializer : Test(4) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $hashref  = { key1 => 'value', key2 => 'value2' };
    can_ok( $package, 'set_initializer' );
    can_ok( $package, 'get_initializer' );
    is_deeply( $instance->set_initializer($hashref),
        $hashref, 'Does it return the correct value?' );
    is_deeply( $instance->get_initializer, $hashref,
        "Do we get the right value?" );

}

sub test_get_set_cgi : Test(4) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $mock     = $self->{mock};

    can_ok( $package, 'set_cgi' );
    can_ok( $package, 'get_cgi' );
    is_deeply( $instance->set_cgi($mock),
        $mock, 'Does it return the correct value?' );
    is_deeply( $instance->get_cgi, $mock, "Do we get the right value?" );

}

sub test_http_header : Test(7) {
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    my $mock     = $self->{mock};

    can_ok( $package, 'http_header' );

    local $ENV{SCRIPT_NAME} = 'http://foo/bar/';
    $instance->set_cgi( CGI->new( $ENV{SCRIPT_NAME} ) );
    like(
        $instance->http_header,
        qr{Content-Type: text/html},
        'With no args should just have a content type header'
    );
    $instance->set_user($mock);
    $instance->get_user->{cookie} = 'foobar';
    like(
        $instance->http_header,
        qr{Cookie: foobar},
        'When we set cookie in user should appear in header'
    );
    like(
        $instance->http_header,
        qr{Content-Type: text/html},
        'Even though cookie is set, content type should still be text/html'
    );

    like(
        $instance->http_header('text/text'),
        qr{Content-Type: text/text},
        'A single text arg should set the content type'
    );
    like(
        $instance->http_header('text/text'),
        qr{Cookie: foobar},
        '...and the cookie should stay the same'
    );

    like( $instance->http_header( { -Cost => '2p' } ),
        qr{Cost: 2p}, 'A hashref arg allows arbitrary headers' );

}

1;
