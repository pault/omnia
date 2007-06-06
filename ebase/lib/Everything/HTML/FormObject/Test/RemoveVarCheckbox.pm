package Everything::HTML::FormObject::Test::RemoveVarCheckbox;

use base 'Everything::HTML::FormObject::Test::Checkbox';
use Test::MockObject::Extends;
use Test::MockObject;
use Test::More;
use Scalar::Util qw/blessed/;
use base 'Test::Class';
use strict;
use SUPER;
use warnings;

sub test_gen_object : Test(8) {
    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $cgi      = Test::MockObject->new;

    my @params;
    $instance->mock( getParamArray => sub {
	shift;
        push @params, "@_";
        shift;
        @_;
    });

    my ( $method_name, $arguments );
    $instance->fake_module( 'Everything::HTML::FormObject::Checkbox',
        genObject =>
          sub { $method_name = 'genObject'; $arguments = [@_]; return 'html' }
    );

    $instance->genObject( $cgi, 'bN', 'f', 'v' );
    is(
        $params[0],
        "query, bindNode, field, var $cgi bN f v",
        'genObject() should call getParamArray() with @_'
    );

    is( $instance->{updateExecuteOrder},
        55, '... should set node execution order to 55' );

    is( $method_name, 'genObject', '... should call SUPER::genObject()' );

    is( $arguments->[2], 'bN',         '... passing bound node' );
    is( $arguments->[3], 'f:v',        '... field and variable name' );
    is( $arguments->[4], 'remove_f_v', '... name' );
    is(
        join( ' ', @{$arguments}[ 5, 6 ] ),
        'remove UNCHECKED',
        '... and "remove" and "UNCHECKED" args'
    );

    is( $instance->genObject( 1 .. 4 ),
        "html\n", '... should return result of SUPER call' );

}

sub test_cgi_update : Test(11) {

    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $cgi      = Test::MockObject->new;
    my $node     = $self->{node};

    $cgi->set_series( param => 0, 1, 1, 1 );
    $instance->set_always( 'getBindField' => 'field::var' );
    $node->set_always( 'getHash'          => $node );
    $node->set_series( verifyFieldUpdate => 0, 1 );
    $node->set_always( 'setHash', {} );

    my $result = $instance->cgiUpdate( $cgi, 'name' );

    my ( $method, $args ) = $cgi->next_call;
    is( join( ' ', $method, @{$args}[1] ),
        'param name', 'cgiUpdate() should call fetch named param' );
    ok( !$result, '... and should return false if none exists' );

    $node->{_calls} = [];
    $node->{var}    = 'foo';

    $result = $instance->cgiUpdate( $cgi, $node, $node, 1 );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'getBindField',
        '... should call getBindField() to find field' );

    ( $method, $args ) = $node->next_call;
    isnt( $method, 'verifyFieldUpdate',
        '... should bypass field verification check if $overrideVerify is true'
    );

    is(
        join( ' ', $method, @{$args}[1] ),
        'getHash field',
        '... should call getHash() on field'
    );
    ok( !exists $node->{var}, '... and should delete variable in bound node' );

    ( $method, $args ) = $node->next_call;
    is(
        join( ' ', $method, @{$args}[ 1, 2 ] ),
        "setHash $node field",
        '... should call setHash() to update node'
    );
    ok( $result, '... and should return true' );

    $node->clear;
    $result = $instance->cgiUpdate( $cgi, $node, $node, 0 );
    ok( !$result,
        '... should return false if field update cannot be verified' );

    ( $method, $args ) = $node->next_call;
    is(
        join( ' ', $method, @{$args}[1] ),
        'verifyFieldUpdate field',
        '... (so should call verifyFieldUpdate() on node field)'
    );
    ok(
        $instance->cgiUpdate( $cgi, $node, $node, 1 ),
        '... should continue if update verifies'
    );

}
1;
