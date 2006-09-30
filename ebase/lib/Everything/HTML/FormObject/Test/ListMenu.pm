package Everything::HTML::FormObject::Test::ListMenu;

use base 'Everything::HTML::Test::FormObject';
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use CGI;
use SUPER;
use warnings;
use strict;

sub setup_globals {
    my $self = shift;
    $self->SUPER;
    no strict 'refs';
    *{'Everything::HTML::FormObject::FormMenu::DB'} = \$self->{mock};
    use strict 'refs';

}

sub test_cgi_update : Test(11) {
    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $mock     = $self->{mock};

    my $qmock = Test::MockObject->new();
    $qmock->set_true('param');

    my $nmock = Test::MockObject->new();
    $nmock->set_series( 'verifyFieldUpdate', 0, 1, 0 );

    $instance->set_always( 'getBindField', 'field' );
    my ( %gpa, @gpa );
    $mock->fake_module( $self->{class},
        getParamArray =>
          sub { push @gpa, \@_; return @gpa{qw( q bn f n d m v s l sb )} } );

    my @go;
    $mock->fake_module(
        'Everything::HTML::FormObject::FormMenu',
        genObject => sub { push @go, \@_; return 'html1' }
    );

    my @results;
    push @results, $instance->cgiUpdate( $qmock, 'name', $nmock, 0 );
    my ( $method, $args ) = $instance->next_call();
    is( $method, 'getBindField', 'cgiUpdate() should call getBindField' );
    is(
        "@$args",
        "$instance $qmock name",
        '... passing two args ($query, $name)'
    );

    ( $method, $args ) = $nmock->next_call();
    is( $method, 'verifyFieldUpdate',
        '... should check verifyFieldUpdate if not $overrideVerify' );
    is( "@$args", "$nmock field", '... passing it one arg ($field)' );
    ok( !$qmock->called('param'),
        '... should not call param() when verify off' );

    push @results, $instance->cgiUpdate( $qmock, 'name', $nmock, 0 );
    ( $method, $args ) = $qmock->next_call();
    is( $method, 'param',
        '... should call param() if $NODE->verifyFieldUpdate' );
    is( "@$args", "$qmock name", '... passing one arg ($name)' );

    push @results, $instance->cgiUpdate( $qmock, 'name', $nmock, 1 );
    ok( $qmock->called('param'), '... should call param() if $overrideVerify' );

    ok( !$results[0], '... should return false when verify is off' );
    ok( $results[1],  '... should return true if $NODE->verifyFieldUpdate' );
    ok( $results[2],  '... should return true if $overrideVerify' );
}

sub test_gen_object : Test(18) {
    my $self     = shift;
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $mock     = $self->{mock};

    my ( %gpa, @gpa );
    $mock->fake_module( $self->{class},
        getParamArray =>
          sub { push @gpa, \@_; return @gpa{qw( q bn f n d m v s l sb )} } );

    my @go;
    $mock->fake_module(
        'Everything::HTML::FormObject::FormMenu',
        genObject => sub { push @go, \@_; return 'html1' }
    );

    for ( 'clearMenu', 'addArray', 'addLabels', 'sortMenu' ) {
        $instance->set_true($_);
    }
    $instance->set_always( 'genListMenu', 'html2' );

    @gpa{qw( q bn f n d m v s l sb )} = (
        $instance, '',     'field', 'name', 'def', 'mul',
        'val',     'size', 'lab',   'sort'
    );

    my $result = $instance->genObject( 1, 2, 3 );
    is( @gpa, 1, 'genObject() should call getParamArray' );
    is(
        $gpa[0][0],
        'query, bindNode, field, name, default, '
          . 'multiple, values, size, labels, sortby',
        '... requesting the appropriate arguments'
    );
    like( join( ' ', @{ $gpa[0] } ),
        qr/1 2 3$/, '... with the method arguments' );
    unlike( join( ' ', @{ $gpa[0] } ),
        qr/$mock/, '... but not the object itself' );

    my ( $method, $args ) = $instance->next_call();
    is( 'clearMenu', $method, '... should call clearMenu' );
    is( join( ' ', @$args ), "$instance", '... passing one arg ($this)' );

    ( $method, $args ) = $instance->next_call();
    is( 'addArray', $method, '... should call addArray' );
    is(
        join( ' ', @$args ),
        "$instance val",
        '... passing two args ($this, $values)'
    );

    ( $method, $args ) = $instance->next_call();
    is( 'addLabels', $method, '... should call addLabels' );
    is(
        join( ' ', @$args ),
        "$instance lab",
        '... passing two args ($this, $labels)'
    );

    ( $method, $args ) = $instance->next_call();
    is( 'sortMenu', $method, '... should call sortMenu' );
    is(
        join( ' ', @$args ),
        "$instance sort",
        '... passing two args ($this, $sortby)'
    );

    ( $method, $args ) = $instance->next_call();
    is( 'genListMenu', $method, '... should call genListMenu' );
    is( "@$args", "@gpa{qw( q q n d s m )}", '... passing the correct args' );
    is( $$args[3], 'def',
        '... $default should remain unchanged when not AUTO' );

    $gpa{d} = 'AUTO';
    $instance->genObject();
    ( $method, $args ) = $instance->next_call(5);
    is( $$args[3], '', '... should be blank if AUTO and no $bindNode' );

    $gpa{bn} = { field => "1,2" };
    $instance->genObject();
    ( $method, $args ) = $instance->next_call(5);
    is( "@{$$args[3]}", "1 2",
        '... and should be $$bindNode{$field} if AUTO and $bindNode' );

    is( $result, "html1\nhtml2",
        '... should return parent object plus genListMenu html' );
}

1;
