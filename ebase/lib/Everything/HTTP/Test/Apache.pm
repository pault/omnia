package Everything::HTTP::Test::Apache;

use base 'Test::Class';
use Test::More;
use Test::MockObject;
use Scalar::Util 'blessed';

use strict;
use warnings;

sub test_startup : Test(startup => 1) {
    my $self = shift;
    my $mock = Test::MockObject->new;
    $mock->fake_module('Everything::Auth');
    my $fake_apache_request     = Test::MockObject->new;
    my $fake_everything_request = Test::MockObject->new;
    $fake_everything_request->fake_module('Everything::HTTP::Request');
    $fake_everything_request->fake_new('Everything::HTTP::Request');

    $mock->set_true('execute_opcodes');

    $mock->fake_module('Everything::HTTP::ResponseFactory');
    $mock->fake_new('Everything::HTTP::ResponseFactory');
    $mock->set_true(qw/create_http_body/)
      ->set_always( get_mime_type => 'a mime type' )
      ->set_always( 'get_http_body', 'the html body' );

    $self->{class} = $self->module_class;

    use_ok( $self->{class} );

    $self->{mock}                    = $mock;
    $self->{fake_apache_request}     = $fake_apache_request;
    $self->{fake_everything_request} = $fake_everything_request;

}

sub module_class {
    my $self = shift;
    my $name = blessed($self);
    $name =~ s/Test:://;
    return $name;
}

sub test_handler : Test(25) {
    my $self                    = shift;
    my $mock                    = $self->{mock};
    my $fake_everything_request = $self->{fake_everything_request};
    my $fake_apache_request     = $self->{fake_apache_request};
    can_ok( $self->{class}, 'handler' ) || return "Handler not implemented";

    my $fake_parser = Test::MockObject->new;
    my $count       = 0;
    $fake_parser->mock( process =>
          sub { $fake_everything_request->{node_id} = 777 if ++$count == 1 } );

    no strict 'refs';
    local *{ $self->{class} . '::create_url_parsers' };
    *{ $self->{class} . '::create_url_parsers' } =
      sub { [ $fake_parser, $fake_parser, $fake_parser ] };
    use strict 'refs';

    my $handler = \&{ $self->{class} . '::handler' };

    $mock->set_true(qw/set_e process setVars update/);

    my $dir_config = Test::MockObject->new;
    $fake_apache_request->set_always( 'dir_config', $dir_config );
    $fake_apache_request->set_true( 'assbackwards', 'print', 'content_type' );
    $fake_apache_request->set_always( 'headers_out', $mock );
    $fake_apache_request->set_always( -uri => '/' );
    $mock->set_true('set', '-resetNodeCache');
    $dir_config->set_series( 'get', qw/db user password host/ );

    $fake_everything_request->set_true(
        qw/setup_standard_system_vars set_cgi_standard authorise_user set_e process get_user set_node_from_cgi set_node setup_everything_html execute_opcodes/
    );
    $fake_everything_request->set_always( '-get_node', $mock );
    $fake_everything_request->set_always( 'get_options', { a => 'b' } );
    $fake_everything_request->set_always( '-get_cgi',      $mock );
    $fake_everything_request->set_always( '-get_nodebase', $mock );
    $fake_everything_request->set_always( '-get_user',     $mock );
    $fake_everything_request->set_always( 'http_header',   'header' );
    $fake_everything_request->set_always( 'get_system_vars',
        { default_node => 999 } );
    $fake_everything_request->set_always( 'get_user_vars',
        { userkey => 'uservalue' } );

    $mock->{cookie} = 'a cookie';

    my $result = $handler->($fake_apache_request);
    my ( $method, $args ) = $fake_everything_request->next_call;
    is( $method, 'setup_standard_system_vars', '...sets up system from db.' );
    ( $method, $args ) = $fake_everything_request->next_call;
    is( $method, 'set_cgi_standard', '...setup cgi object.' );
    ( $method, $args ) = $fake_everything_request->next_call;
    is( $method, 'get_options', '...retrieves options for this request.' );
    ( $method, $args ) = $fake_everything_request->next_call();
    is( $method, 'authorise_user', '...sets user for this request.' );
    is_deeply(
        $$args[1],
        { a => 'b', nodebase => $mock, query => $mock },
        '...with the correct arguments.'
    );

    ( $method, $args ) = $fake_everything_request->next_call();
    is( $method, 'setup_everything_html', '...sets up code environment.' );

    ( $method, $args ) = $fake_everything_request->next_call();
    is( $method, 'execute_opcodes', '...excute opcodes.' );

    ( $method, $args ) = $fake_everything_request->next_call();
    is( $method, 'set_node_from_cgi', '...sets requested node from cgi.' );

    ( $method, $args ) = $fake_everything_request->next_call();
    is( $method, 'setup_everything_html',
        '...sets up code environment again.' );

    ## calls to apache request object

    ## these are to dir_config
    ## XXXX - must be tested
    $fake_apache_request->next_call;
    $fake_apache_request->next_call;
    $fake_apache_request->next_call;
    $fake_apache_request->next_call;
    $fake_apache_request->next_call;

    ( $method, $args ) = $fake_apache_request->next_call;
    is( $method, 'content_type',
        '...set header according to response object.' );
    is( $$args[1], 'a mime type', '...calls with the mime type.' );

    ( $method, $args ) = $fake_apache_request->next_call;
    is( $method, 'headers_out',
        '...currently do our own cookies until Auth.pm rewrite.' );

    ( $method, $args ) = $fake_apache_request->next_call;
    is( $method, 'print',
        '...currently do our own cookies until Auth.pm rewrite.' );
    is( $args->[1], 'the html body', '...prints http header.' );

    is( $result, 0, '...should return correct result' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'create_http_body', '...factory creates http body.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'get_http_body', '...retrieves http body.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'get_mime_type', '...returns mime type.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'set', '...calls set.' );
    is_deeply( $args, [ $mock, 'Set-Cookie', 'a cookie' ],
        '...with a cookie.' );

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

sub test_create_url_parsers : Test(1) {
    local $TODO = "test not yet written.";

}

1;
