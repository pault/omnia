package Everything::HTML::FormObject::Test::PopupMenu;

use base 'Everything::HTML::FormObject::Test::FormMenu';
use Test::MockObject::Extends;
use Test::MockObject;
use Test::More;
use Scalar::Util qw/blessed/;
use base 'Test::Class';
use strict;
use SUPER;
use warnings;

sub test_gen_object : Test(9) {
    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );

    $instance->set_true('addHash');
    $instance->set_always( 'genPopupMenu', 'a' );
    my @params;
    *Everything::HTML::FormObject::PopupMenu::getParamArray = sub {
        push @params, "@_";
        shift;
        @_;
    };

    my ( $method_name, $arguments );
    $instance->fake_module( 'Everything::HTML::FormObject::FormMenu',
        genObject =>
          sub { $method_name = 'genObject'; $arguments = [@_]; return 'html' }
    );

    my $result = $instance->genObject( 'q', 'bN', 'f', 'n', 'd' );

    is(
        $params[0],
        'query, bindNode, field, name, default q bN f n d',
        'genObject() should call getParamArray() with @_'
    );

    is( $method_name, 'genObject', '... should call SUPER::genObject()' );

    my ( $method, $args ) = $instance->next_call;
    is( $method, 'genPopupMenu', '... should call genPopupMenu()' );

    is( $args->[3], 'd', '... should use default value, if provided' );
    is( $args->[2], 'n', '... should use provided name' );
    is( $result, "html\na",
        '... returning concatenation of SUPER() and genPopupMenu() calls' );
    $instance->clear;

    $instance->genObject( 'q', { f => 'field' }, 'f', 'n' );
    ( $method, $args ) = $instance->next_call;
    is( $args->[3], 'field',
        '... with no default value, should bind to node field (if provided)' );

    $instance->clear;
    $instance->genObject( 'q', { field => 88 }, 'field' );
    ( $method, $args ) = $instance->next_call;
    is( $args->[2], 'field', '... name should default to node field name' );

    $instance->clear;
    $instance->genObject( 'q', '', 'field' );
    ( $method, $args ) = $instance->next_call;
    is( $args->[3], '',
        '... default value should be blank if "AUTO" and lacking bound node' );
}
1;

