package Everything::HTML::FormObject::Test::NodetypeMenu;

use base 'Everything::HTML::FormObject::Test::TypeMenu';
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
    my $mock     = Test::MockObject->new;

    my ( %gpa, @gpa );
    $instance->mock(
        getParamArray =>
          sub { shift; push @gpa, \@_; return @gpa{qw( q bn f n ou U no i it )} } );

    my @go;
    $mock->fake_module(
        'Everything::HTML::FormObject::TypeMenu',
        genObject => sub { push @go, \@_; return 'html' }
    );

    @gpa{qw( q bn f n ou U no i )} = (
        'query',    'bindNode', 'field', 'name',
        'omitutil', 'USER',     'none',  'inherit'
    );

    my $result = $instance->genObject( 1, 2, 3 );
    is( @gpa, 1, 'genObject() should call getParamArray' );
    is(
        $gpa[0][0],
        'query, bindNode, field, name, omitutil, '
          . 'USER, none, inherit, inherittxt',
        '... requesting the appropriate arguments'
    );
    is_deeply(
        [ @{ $gpa[0] }[ 1 .. 3 ] ],
        [ 1, 2, 3 ],
        '... with the method arguments'
    );
    unlike( join( ' ', @{ $gpa[0] } ),
        qr/$mock/, '... but not the object itself' );
    is( @go, 1, '... should call SUPER::genObject()' );
    is_deeply(
        [ @{ $go[0] } ],
        [
            $instance, 'query',    'bindNode', 'field',
            'name',    'nodetype', 'AUTO',     'USER',
            'c',       'none',     'inherit'
        ],
        '... passing ten correct args'
    );
    is( $instance->{omitutil}, 'omitutil',
        '... should set $$this{omitutil} to $omitutil' );

    @gpa{qw(ou U)} = ( undef, undef );

    $instance->genObject();
    is( $instance->{omitutil}, 0, '... should default $omitutil to 0' );
    is( ${ $go[1] }[7], -1, '... should default $USER to -1' );

    is( $result, 'html', '... should return result of SUPER::genObject()' );
}

sub test_add_types : Test(22) {
    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $mock     = $self->{mock};

    my ( %types, @hTA );
    for ( 'a', 'b', 'c' ) {
        $types{$_} = Test::MockObject->new;
        $types{$_}->mock( 'hasTypeAccess', sub { push @hTA, $_[0]; 1 } );
        $types{$_}->set_true('derivesFrom');
        $types{$_}->{title} = $_;
    }

    $mock->set_list( 'getAllTypes', $types{c}, $types{a}, $types{b} );

    $instance->set_always( 'createTree',
        [ { label => 'l1', value => 'v1' }, { label => 'l2', value => 'v2' } ]
    );
    $instance->set_true('addHash');
    $instance->set_true('addArray');
    $instance->set_true('addLabels');

    my $result = $instance->addTypes( 't', 'U', 'p', 'n', 'i' );

    my ( $method, $args ) = $instance->next_call;
    is( $method, 'addHash',
        'addTypes() should call addHash() if $none defined' );
    is_deeply(
        [ @$args[ 1, 2 ] ],
        [ { 'None' => 'n' }, 1 ],
        '... passing {"None" => $none}, 1'
    );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'addHash', '... should call addHash() if $inherit defined' );
    is_deeply(
        [ @$args[ 1, 2 ] ],
        [ { 'Inherit' => 'i' }, 1 ],
        '... passing {"Inherit" => $inherit}, 1'
    );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'getAllTypes', '... should call getAllTypes' );

    is_deeply(
        [@hTA],
        [ @types{qw(a b c)} ],
        '... should sort returned types by title'
    );

    my $type = Test::MockObject->new;
    $type->set_series( 'hasTypeAccess', 1, 1, 1, 0 );
    $type->set_series( 'derivesFrom',   0, 1, 1, 0 );
    $type->{title} = 'title';
    $mock->set_always( 'getAllTypes', $type );

    $instance->{omitutil} = 1;
    $instance->clear;

    $instance->addTypes( 't', 'U', 'p', undef, undef );

    ( $method, $args ) = $type->next_call;
    is( $method, 'hasTypeAccess', '... should check hasTypeAccess() for type' );
    is_deeply( [ @$args[ 1 .. 2 ] ], [ 'U', 'c' ],
        '... passing $USER and "c"' );

    ( $method, $args ) = $type->next_call;
    is( $method, 'derivesFrom',
        '... should check derivesFrom() if $this->{omitutil}' );
    is( $args->[1], 'utility', '... passing "utility"' );

    ( $method, $args ) = $instance->next_call;
    isnt( $method, 'addHash',
        '... should not call addHash() when no $none or $inherit' );
    is( $method, 'createTree', '... should call createTree()' );
    is_deeply( $$args[1], [$type],
        '... passing it $TYPE if hasTypeAccess() and not derivesFrom()' );

    $instance->clear;

    $instance->addTypes( 't', 'U', 'p', undef, undef );
    ( $method, $args ) = $instance->next_call;
    is_deeply( [ @{ $$args[1] } ],
        [], '... not passing it $TYPE if derivesFrom() and $omitutil' );

    $instance->{omitutil} = 0;
    $instance->clear;

    $instance->addTypes( 't', 'U', 'p', undef, undef );

    ( $method, $args ) = $instance->next_call;
    is_deeply( $$args[1], [$type],
        '... passing it $TYPE if hasTypeAccess() and not $omitutil' );

    $instance->clear;

    $instance->addTypes( 't', 'U', 'p', undef, undef );

    ( $method, $args ) = $instance->next_call;
    is_deeply( [ @{ $$args[1] } ],
        [], '... not passing it $TYPE if not hasTypeAccess()' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'addArray', '... should call addArray()' );
    is_deeply(
        $$args[1],
        [ 'v1', 'v2' ],
        '... passing it ref to array of menu values'
    );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'addLabels', '... should call addLabels()' );
    is_deeply(
        $$args[1],
        { l2 => 'v2', l1 => 'v1' },
        '... passing it ref to hash of all menu label/value pairs'
    );
    is( $$args[2], 1, '... and passing it 1' );

    is( $result, 1, '... should return 1' );
}

sub test_create_tree : Test(6) {

    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );

    no strict 'refs';
    my $create_tree_code = *{ $self->{class} . '::createTree' }{CODE};
    use strict 'refs';
    my $mock = Test::MockObject->new;
    $instance->mock(
        'createTree',
        sub {
            $create_tree_code->(@_);
            return [ { label => 'v1' }, { label => 'v2' } ];
        }
    );

    my $types = [
        { extends_nodetype => 0, title => 'zero', node_id => 1 },
        { extends_nodetype => 1, title => 'one1', node_id => 2 },
        { extends_nodetype => 1, title => 'one2', node_id => 3 },
    ];

    $instance->createTree( $types, 1 );

    my ( $method, $args ) = $instance->next_call;
    ( $method, $args ) = $instance->next_call;
    is( $method, 'createTree', 'createTree() should call createTree()' );
    is_deeply(
        $args,
        [ $instance, $types, 2 ],
        '... passing it $types, node_id'
    );

    ( $method, $args ) = $instance->next_call;
    is_deeply(
        [ $method, @$args ],
        [ 'createTree', $instance, $types, 3 ],
        '... for each $type with extends_nodetype matching $current'
    );

    ( $method, $args ) = $mock->next_call;
    ok( !$method, '... but no more' );

    my $called = 0;
    $instance->clear;

    $instance->set_always( 'createTree',
        [ { label => 'v1' }, { label => 'v2' } ] );

    my $result = $create_tree_code->( $instance, $types, undef );

    ( $method, $args ) = $instance->next_call;
    is( $$args[2], 1, '... $current defaults to 0' );

    is_deeply(
        $result,
        [
            { label => ' + zero', value => 1 },
            { label => ' - -v1' },
            { label => ' - -v2' }
        ],
        '... should return correct nodetype tree'
    );
}

1;
