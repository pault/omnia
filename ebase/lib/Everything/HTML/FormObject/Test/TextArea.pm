package Everything::HTML::FormObject::Test::TextArea;

use base 'Everything::HTML::Test::FormObject';
use Test::MockObject::Extends;
use Test::MockObject;
use Test::More;
use Scalar::Util qw/blessed/;
use base 'Test::Class';
use strict;
use SUPER;
use warnings;

sub test_gen_object : Test(13) {
    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $cgi      = Test::MockObject->new;

    $cgi->set_always( 'param',    'some stuff' );
    $cgi->set_always( 'textarea', 'a' );
    my @params;
    $instance->mock( getParamArray => sub {
	shift;
        push @params, "@_";
        shift;
        @_;
    } );

    my ( $method_name, $arguments );
    $instance->fake_module( 'Everything::HTML::FormObject',
        genObject =>
          sub { $method_name = 'genObject'; $arguments = [@_]; return 'html' }
    );

    my $result =
      $instance->genObject( $cgi, 'bN', 'f', 'n', 'd', 'c', 'r', 'w' );

    is(
        $params[0],
        'query, bindNode, field, name, default, cols, rows  ' . $cgi
          . ' bN f n d c r w',
        'genObject() should call getParamArray() with @_'
    );
    is( $method_name, 'genObject', '... should call SUPER::genObject()' );

    my ( $method, $args ) = $cgi->next_call;
    is( $method,     'textarea', '... should call textarea()' );
    is( $args->[4],  'd',        '... should use default value, if provided' );
    is( $args->[2],  'n',        '... should use provided name' );
    is( $args->[6],  'c',        '... should use provided cols' );
    is( $args->[8],  'r',        '... should use provided rows' );
    is( $result, "html\na",
        '... returning concatenation of SUPER() and textfield() calls' );

    $instance->genObject( $cgi, { f => 'field' }, 'f' );
    ( $method, $args ) = $cgi->next_call;
    is( $args->[4], 'field',
        '... with no default value, should bind to node field (if provided)' );
    is( $args->[6],  80,        '... cols should default to 80' );
    is( $args->[8],  20,        '... rows should default to 20' );
    is( $args->[2],  'f',       '... name should default to node field name' );

    $instance->genObject( $cgi, '', 'f', 'n', '' );
    ( $method, $args ) = $cgi->next_call;
    is( $args->[4], '',
        '... default value should be blank if "AUTO" and lacking bound node' );
}

1;
