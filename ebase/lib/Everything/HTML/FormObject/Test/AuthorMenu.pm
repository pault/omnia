package Everything::HTML::FormObject::Test::AuthorMenu;

use base 'Everything::HTML::Test::FormObject';
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use SUPER;
use warnings;
use strict;

sub setup_mocks {
    my $self = shift;
    $self->SUPER;
    $self->{mock}->fake_module('Everything::HTML');

}

sub test_cgi_verify : Test(17) {
    my $self     = shift;
    my $mock     = $self->{mock};
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    my $qmock    = Test::MockObject->new();

    $instance->set_series( 'getBindNode', 0, 0, 0, $mock, $mock );
    $qmock->set_series( 'param', 0, 'author', 'author' );
    my $result = $instance->cgiVerify( $qmock, 'boundname' );

    my ( $method, $args ) = $instance->next_call();
    is( $method, 'getBindNode', 'cgiVerify() should get bound node' );
    is(
        join( ' ', @$args ),
        "$instance $qmock boundname",
        '... with query object and query parameter name'
    );

    ( $method, $args ) = $qmock->next_call();
    is( $method, 'param', '... fetching parameter' );
    is( $args->[1], 'boundname', '... by name' );

    isa_ok( $result, 'HASH', '... and should return a data structure which' );

    $mock->set_series( 'getNode', 0, { node_id => 'node_id' } );
    $result = $instance->cgiVerify( $qmock, 'boundname' );
    ( $method, $args ) = $mock->next_call();
    is( $method, 'getNode', '... fetching the node, if an author is found' );
    is(
        join( ' ', @$args ),
        "$mock author user",
        '... with the author, for the user type'
    );
    is(
        $result->{failed},
        "User 'author' does not exist!",
        '... setting a failure message on failure'
    );

    $qmock->clear();
    $result = $instance->cgiVerify( $qmock, 'boundname' );
    ( $method, $args ) = $qmock->next_call(2);
    is( $method, 'param', '... setting parameters, on success' );
    is(
        join( ' ', @$args ),
        "$qmock boundname node_id",
        '... with the name and node id'
    );
    is( $result->{failed}, undef, '... and no failure message' );

    $mock->set_always( 'getId', 'id' );
    $mock->set_series( 'hasAccess', 0, 1 );
    $result = $instance->cgiVerify( $qmock, 'boundname', 'user' );
    $mock->called_pos_ok( -2, 'getId',
        '... should get bound node id, if it exists' );
    is( $result->{node}, 'id', '... setting it in the resulting node field' );
    $mock->called_pos_ok( -1, 'hasAccess', '... checking node access ' );
    is( $mock->call_args_string( -1, ' ' ),
        "$mock user w", '... for user with write permission' );

    is(
        $result->{failed},
        'You do not have permission',
        '... setting a failure message if user lacks write permission'
    );

    $result = $instance->cgiVerify( $qmock, 'boundname', 'user' );
    is( $result->{failed}, undef, '... and none if the user has it' );

}

sub test_gen_object : Test(18) {
    my $self     = shift;
    my $mock     = $self->{mock};
    my $instance = Test::MockObject::Extends->new( $self->{instance} );

    my ( %gpa, @gpa );
    can_ok( $self->{class}, 'genObject' ) || return "genObject not implemented";

    my @go;
    no strict 'refs';
    no warnings 'redefine';
    local *{ $self->{class} . '::getParamArray' } =
      sub { shift; push @gpa, \@_; return @gpa{qw( q bn f n d )} };
    local *{'Everything::HTML::FormObject::genObject'} =
      sub { push @go, \@_; return 'some html' };

    use warnings 'redefine';
    use strict 'refs';

    #$Everything::HTML::FormObject::AuthorMenu::DB = $mock;
    $mock->set_always( 'textfield', 'more html' );
    $mock->set_series( 'getNode', 0, $mock, $mock );
    $gpa{q} = $mock;
    $gpa{f} = 'field';

    my $result = $instance->genObject( 1, 2, 3 );
    is( @gpa, 1, 'genObject() should call getParamArray' );
    is(
        $gpa[0][0],
        'query, bindNode, field, name, default',
        '... requesting the appropriate arguments'
    );
    like( join( ' ', @{ $gpa[0] } ),
        qr/1 2 3$/, '... with the method arguments' );
    unlike( join( ' ', @{ $gpa[0] } ),
        qr/$mock/, '... but not the object itself' );
    ok( !$mock->called('getNode'),
        '... should not fetch bound node without one' );

    my ( $method, $args ) = $mock->next_call();
    shift @$args;
    my %args = @$args;

    is( $method, 'textfield', '... and should create a text field' );
    is(
        join( ' ', sort keys %args ),
        join( ' ', sort qw( -name -default -size -maxlength -override ) ),
        '... passing the essential arguments'
    );
    is( $args{-name}, 'field',
        '... and widget name should default to field name' );
    is(
        $result,
        "some html\nmore html\n",
        '... returning the parent object plus the new textfield html'
    );

    $mock->{field} = 'bound node';
    $gpa{bn} = $mock;
    $instance->genObject();

    ( $method, $args ) = $mock->next_call();
    is( $method, 'getNode', '... should get bound node, if provided' );
    is( $args->[1], 'bound node', '... identified by its name' );
    ( $method, $args ) = $mock->next_call();
    isnt( $method, 'isOfType',
        '... not checking bound node type if it is not found' );
    shift @$args;
    %args = @$args;
    is( $args{-default}, undef, '... and not modifying default selection' );

    $mock->{title} = 'bound title';
    $mock->set_series( 'isOfType', 0, 1 );

    $instance->genObject();
    ( $method, $args ) = $mock->next_call(2);
    is( $method, 'isOfType', '... if bound node is found, should check type' );
    is( $args->[1], 'user', '... (the user type)' );

    ( $method, $args ) = $mock->next_call();
    shift @$args;
    %args = @$args;
    is( $args{-default}, '',
        '... setting default to blank string if it is not a user' );

    $instance->genObject();
    ( $method, $args ) = $mock->next_call(3);
    shift @$args;
    %args = @$args;
    is( $args{-default}, 'bound title', '... but using node title if it is' );

}

1;
