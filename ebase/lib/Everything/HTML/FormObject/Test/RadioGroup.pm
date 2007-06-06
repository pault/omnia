package Everything::HTML::FormObject::Test::RadioGroup;

use base 'Everything::HTML::FormObject::Test::FormMenu';
use Test::MockObject::Extends;
use Test::MockObject;
use Test::More;
use Scalar::Util qw/blessed/;
use base 'Test::Class';
use strict;
use SUPER;
use warnings;

sub test_gen_object : Test(10) {
    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $cgi      = Test::MockObject->new;

    $cgi->set_list( 'radio_group', 'a', 'b' );

    $instance->set_true( 'getValuesArray', 'getLabelsHash' );
    $instance->set_always( 'genPopupMenu', 'a' );
    my @params;
    $instance->mock(getParamArray => sub {
	shift;
        push @params, "@_";
        shift;
        @_;
    });

    my ( $method_name, $arguments );
    $instance->fake_module( 'Everything::HTML::FormObject::FormMenu',
        genObject =>
          sub { $method_name = 'genObject'; $arguments = [@_]; return 'html' }
    );

    $instance->genObject( $cgi, 'bN', 'f', 'n', 'd', 'v' );
    is(
        $params[0],
        "query, bindNode, field, name, default, vertical $cgi " . 'bN f n d v',
        'genObject() should call getParamArray() with @_'
    );
    is( $method_name, 'genObject', '... should call SUPER::genObject()' );

    my ( $method, $args ) = $instance->next_call(2);
    is( $method, 'getValuesArray', '... should call getValuesArray()' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'getLabelsHash', '... should call getLabelsHash()' );

    ( $method, $args ) = $cgi->next_call;
    is( $method, 'radio_group', '... should call $query->radio_group()' );
    $cgi->clear;
    $instance->genObject( $cgi, { f => 'field' }, 'f', 'n', 'AUTO' );

    my @args = $cgi->call_args(-1);
    is( $args[4], 'field',
        '... default value should bind to node field if "AUTO"' );

    $instance->genObject( $cgi, '', 'field', 'n', 'AUTO' );
    @args = $cgi->call_args(-1);
    is( $args[4], '',
        '... default value should be blank if "AUTO" and lacking bound node' );

    is( $instance->genObject( $cgi, 'bN', 'f', 'n', 'd', 0 ),
        "html\na\nb", '... join buttons using "\n" if vertical is false' );
    ok(
        is(
            $instance->genObject( $cgi, 'bN', 'f', 'n', 'd', 1 ),
            "html\na<br>\nb",
            '... and join using "<br>\n" if vertical is true'
        ),
        '... returns concatenation of SUPER() and radio_group() calls'
    );

}

1;
