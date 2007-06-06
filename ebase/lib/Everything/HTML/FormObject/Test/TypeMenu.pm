package Everything::HTML::FormObject::Test::TypeMenu;

use base 'Everything::HTML::FormObject::Test::FormMenu';
use Test::MockObject::Extends;
use Test::More;
use Scalar::Util qw/blessed/;
use base 'Test::Class';
use strict;
use warnings;

sub test_add_types : Test(12) {
    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $node     = $self->{node};
    $instance->set_true( 'addHash', 'addType' );
    my $result = $instance->addTypes( 't', 'U', 'p', 'n', 'i', 'it' );

    my ( $method, $args ) = $instance->next_call;
    is( $method, 'addHash',
        'addTypes() should call addHash() if defined $none' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'addHash',
        '... should call addHash() again if defined $inherit' );
    is( ${ $args->[1] }{'inherit (it)'},
        'i',
        '... $label should be set to "inherit ($inherittxt)" if $inherittxt' );

    ( $method, $args ) = $instance->next_call;
    is( $method,    'addType', '... should call addType()' );
    is( $args->[2], 'U',       '... should use provided $USER' );
    is( $args->[3], 'p',       '... and $perm' );
    is( $result,    1,         '... should return 1' );

    $instance->clear;
    $instance->addTypes( 't', '', '', 'n' );
    ( $method, $args ) = $instance->next_call;
    is( ${ $args->[1] }{None},
        'n', '... skip an addHash() if $inherit undefined' );

    ( $method, $args ) = $instance->next_call;

    is( $args->[2], -1,  '... $USER defaults to -1' );
    is( $args->[3], 'r', '... and $perm to "r"' );

    $instance->clear;
    $instance->addTypes( 't', 'U', 'p', undef, 'i' );
    ( $method, $args ) = $instance->next_call;
    is_deeply(
        $args->[1],
        { inherit => 'i' },
        '... $label should be set to "inherit" if no $inherittxt'
    );
    ( $method, $args ) = $instance->next_call;
    is( $method, 'addType', '... skip and addHash() if $none undefined' );

}

sub test_gen_object : Test(16) {
    my $self     = shift;
    my $node     = $self->{node};
    my $instance = Test::MockObject::Extends->new( $self->{instance} );

    $instance->set_true('addTypes');
    $instance->set_always( 'genPopupMenu', "a" );
    my @params;
    $instance->mock( getParamArray => sub {
        shift;
        push @params, "@_";
        shift;
        @_;
    });

    my ( $genObject_name, $genObject_args );
    $node->fake_module(
        'Everything::HTML::FormObject',
        genObject => sub {
            my $node = shift;
            $genObject_name = 'genObject';
            $genObject_args = [@_];
            return 'html';
        }
    );

    my $result =
      $instance->genObject( 'q', 'bN', 'f', 'n', 't', 'd', 'U', 'p', 'n', 'i',
        'it' );

    is(
        $params[0],
        'query, bindNode, field, name, type, default, USER, perm, '
          . 'none, inherit, inherittxt q bN f n t d U p n i it',
        'genObject() should call getParamArray() with @_'
    );
    is( $genObject_name, 'genObject', '... should call SUPER::genObject()' );

    my ( $method, $args ) = $instance->next_call(2);
    is( $method,    'addTypes', '... should call addTypes()' );
    is( $args->[1], 't',        '... should use provided $type' );
    is( $args->[2], 'U',        '... should use provided $USER' );
    is( $args->[3], 'p',        '... should use provided $perm' );

    ( $method, $args ) = $instance->next_call;
    is( $method,    'genPopupMenu', '... should call genPopupMenu()' );
    is( $args->[2], 'n',            '... should use provided $name' );
    is( $args->[3], undef,          '... $default becomes undef if true' );
    is( $result, "html\na",
        '... returning concatenation of SUPER() and genPopupMenu() calls' );

    $instance->clear;
    $instance->genObject( 'q', { f => 'field' }, 'f' );
    ( $method, $args ) = $instance->next_call(2);
    is( $args->[1], 'nodetype', '... $type should default to "nodetype"' );
    is( $args->[2], '-1',       '... $USER should default to -1' );
    is( $args->[3], 'r',        '... $perm should default to "r"' );

    ( $method, $args ) = $instance->next_call;
    is( $args->[2], 'f', '... $name should default to $field' );
    is( $args->[3], 'field',
        '... with no default value, should bind to provided node field' );
    $instance->clear;
    $instance->genObject( 'q', '', 'field', '', '', 'AUTO' );
    $args = [ $instance->call_args(-1) ];
    is( $args->[3], undef,
        '... default value should be undef if "AUTO" and lacking bound node' );
}

1;
