package Everything::HTML::FormObject::Test::PermissionMenu;

use base 'Everything::HTML::FormObject::Test::FormMenu';
use Test::MockObject::Extends;
use Test::MockObject;
use Test::More;
use Scalar::Util qw/blessed/;
use base 'Test::Class';
use strict;
use SUPER;
use warnings;

sub setup_globals {
    my $self = shift;
    my $mock = $self->{mock};
    $self->{errors} = [];
    $mock->fake_module( 'Everything',
        'logErrors' => sub { shift @{ $self->{errors} }, @_ } );

    $self->SUPER;
}

sub test_gen_object : Test(14) {
    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );

    $instance->set_true('addHash');
    $instance->set_always( 'genPopupMenu', 'a' );
    my @params;
    *Everything::HTML::FormObject::PermissionMenu::getParamArray = sub {
        push @params, "@_";
        shift;
        @_;
    };

    my ( $method_name, $arguments );
    $instance->fake_module( 'Everything::HTML::FormObject::FormMenu',
        genObject =>
          sub { $method_name = 'genObject'; $arguments = [@_]; return 'html' }
    );

    my $result = $instance->genObject( 'q', 'bN', 'f', 'n', 'r', 'd' );
    is(
        $params[0],
        'query, bindNode, field, name, perm, default q bN f n r d',
        'genObject() should call getParamArray() with @_'
    );

    is( $method_name, 'genObject', '... should call SUPER::genObject()' );

    my ( $method, $args ) = $instance->next_call;
    is( $method, 'addHash', '... should call addHash()' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'addHash', '... and addHash()' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'addHash', '... and addHash() once again' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'genPopupMenu', '... and genPopupMenu()' );
    is( $args->[2], 'n', '... should use provided $name' );
    is( $args->[3], undef,
        '... $default becomes undef if true and not "AUTO"' );

    is( $result, "html\na",
        '... returning concatenation of SUPER() and genPopupMenu() calls' );

    $instance->clear;
    my $bound = bless { f => '12345' }, 'Everything::Node';
    $instance->genObject( 'q', $bound, 'f', '', 'x' );
    $args = [ $instance->call_args(-1) ];

    is( $args->[2], 'f', '... $name should default to $field' );
    is( $args->[3], '3',
        '... if false, set $default to substr($perms, $$bindNode{$field}, 1)' );

    $instance->clear;
    $instance->genObject( 'q', '', 'field', '', 'r', 'AUTO' );
    $args = [ $instance->call_args(-1) ];
    is( $args->[3], undef,
        '... default value should be undef if "AUTO" and lacking bound node' );

    my $warning;
    local *Everything::logErrors;
    *Everything::logErrors = sub {
        $warning = shift;
    };

    $result = $instance->genObject( '', '', '', '', 'wrong' );
    like(
        $warning,
        qr/incorrect permission/i,
        '... should log warning on invalid $perm'
    );
    is( $result, '', '... and should return ""' );
}

sub test_cgi_update : Test(8) {

    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $cgi      = Test::MockObject->new;
    my $node     = $self->{node};

    $cgi->set_series( 'param', 'p', '', '' );
    $instance->set_always( 'getBindField', 'f::x' );
    $node->set_series( 'verifyFieldUpdate', 1, 0, 0 );

    $node->{f} = 'rrrrr';

    my $result = $instance->cgiUpdate( $cgi, 'n', $node, 0 );
    my ( $method, $args ) = $cgi->next_call;
    is( $method, 'param', 'cgiUpdate() should call param()' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'getBindField', '... and getBindField()' );

    ( $method, $args ) = $node->next_call;
    is( $method, 'verifyFieldUpdate',
        '... and verifyFieldUpdate() if $overrideVerify is false' );

    is( $node->{f}, 'rrprr',
        '... should set correct char in $$NODE{$field} to $value' );

    is( $result, 1, '... should return 1 if verifyFieldUpdate() is true' );

    $result = $instance->cgiUpdate( $cgi, 'n', $node, 1 );
    is( $node->{f}, 'rrirr', '... $value should default to "i"' );
    is( $result, 1, '... should return 1 if $overrideVerify is true' );

    $result = $instance->cgiUpdate( $cgi, 'n', $node, 0 );
    is( $result, 0,
        '... should return 0 if !($overrideVerify or verifyFieldUpdate())' );
}

1;
