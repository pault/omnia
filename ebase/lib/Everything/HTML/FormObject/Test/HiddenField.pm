package Everything::HTML::FormObject::Test::HiddenField;

use base 'Everything::HTML::Test::FormObject';
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use CGI;
use SUPER;
use warnings;
use strict;

sub test_gen_object : Test(9) {

    my $self     = shift;
    my $mock     = $self->{mock};
    my $node     = $self->{node};
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $cgi      = Test::MockObject->new;
    $cgi->set_always( 'hidden', 'some html' );

    local (
        *Everything::HTML::FormObject::HiddenField::getParamArray,

    );

    my @params;
    *Everything::HTML::FormObject::HiddenField::getParamArray = sub {
        push @params, "@_";
        shift;
        @_;
    };

    my ( $genObject_called, $genObject_arguments );
    $mock->fake_module(
        'Everything::HTML::FormObject',
        genObject => sub {
            my $this = shift;
            $genObject_called    = 'genObject';
            $genObject_arguments = [@_];
            return 'html';
        }
    );

    my $result = $instance->genObject( $cgi, 'bN', 'f', 'n', 'd' );

    is(
        $params[0],
        "query, bindNode, field, name, default $cgi bN f n d",
        'genObject() should call getParamArray() with @_'
    );
    is( $genObject_called, 'genObject', '... should call SUPER::genObject()' );

    my ( $method, $args ) = $cgi->next_call;
    is( $method, 'hidden', '... should call hidden()' );
    is( $args->[4], 'd', '... should use default value, if provided' );

    is( $args->[2], 'n', '... should use provided name' );
    is(
        $result,
        "html\nsome html",
        '... returning concatenation of SUPER() and hidden() calls'
    );

    $instance->genObject( $cgi, { f => 'field' }, 'f', 'n', '' );
    ( $method, $args ) = $cgi->next_call;
    is( $args->[4], 'field',
        '... with no default value, should bind to node field (if provided)' );

    $instance->genObject( $cgi, { field => 88 }, 'field', '', 'd' );
    ( $method, $args ) = $cgi->next_call;
    is( $args->[2], 'field', '... name should default to node field name' );

    $instance->genObject( $cgi, '', 'f', 'n', '' );
    ( $method, $args ) = $cgi->next_call;
    is( $args->[4], '',
        '... default value should be blank if "AUTO" and lacking bound node' );
}

1;
