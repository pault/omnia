package Everything::HTTP::Test::CGI;

use base 'Everything::Test::Abstract';
use Test::More;
use Test::MockObject;
use strict;
use warnings;

BEGIN {
    Test::MockObject->fake_module('Everything::HTTP::ResponseFactory');
    Test::MockObject->fake_module('Everything::HTTP::Request');
}

sub test_handle : Test(17) {
    my $self    = shift;
    my $package = $self->{class};
    my $mock    = Test::MockObject->new;
    can_ok( $package, 'handle' );

    no strict 'refs';
    my $test_code = *{"${package}::handle"}{CODE};
    use strict 'refs';
    $mock->set_always( 'to_html', 'some random text' );
    $mock->set_true(
        'setVars',                    'update',
        'setup_standard_system_vars', '-get_initializer',
        'set_cgi_standard',           'set_node_from_cgi',
        'setup_everything_html',      'authorise_user',
        'execute_opcodes',            'print'
    );
    $mock->set_series( 'isOfType', 0, 0, 1, 1, 0, 1, 1, 0 );

    $mock->fake_new('Everything::HTTP::Request');

    $mock->fake_new('Everything::HTTP::ResponseFactory');

    local $ENV{SCRIPT_NAME} = 'http://foo/bar/';
    $mock->set_always( create_http_body => 'some text' )
      ->set_always( -get_http_body      => 'some text' )
      ->set_always( -get_mime_type      => 'foo/bar' )
      ->set_always( -get_options  => {} )->set_always( -get_cgi     => $mock )
      ->set_always( -get_nodebase => $mock )->set_always( -get_node => $mock )
      ->set_always( -get_user     => $mock )->set_always( get_theme => $mock )
      ->set_always( getType => $mock )->set_always( http_header => "a header" )
      ->set_always( get_system_vars => { key     => 'value' } )
      ->set_always( -get_user_vars  => { userkey => 'uservalue' } );

    $test_code->();
    my ( $method, $args ) = $mock->next_call;
    is( $method, 'setup_standard_system_vars', '...created request.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'set_cgi_standard', '...setup cgi.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'authorise_user', '...sets the user attribute.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'set_node_from_cgi',
        '...sets the node attribute from the request.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'setup_everything_html', '...sets up the code environment.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'execute_opcodes', '...runs those things called opcodes.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'create_http_body', '...create_http_body.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'http_header', '...create the header.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'print', '...prints header.' );
    is( $$args[1], 'a header', '...with the header.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'print', '...prints body.' );
    is( $$args[1], 'some text', '...with the body text.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'setVars', '...sets user vars' );
    is_deeply(
        $args,
        [ $mock, { userkey => 'uservalue' }, $mock ],
        '...with vars and user object.'
    );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'update', '...updates user to nodebase.' );
    is_deeply( $args, [ $mock, $mock ], '...user object as argument.' );

}

1;
