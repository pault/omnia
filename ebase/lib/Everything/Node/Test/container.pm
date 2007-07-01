package Everything::Node::Test::container;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;
use Test::Exception;

sub test_dbtables :Test( 2 )
{
	my $self  = shift;
	my $class = $self->node_class();

	can_ok( $class, 'dbtables' );

	my @tables = $class->dbtables();
	is_deeply( \@tables, [qw( container node )],
		'dbtables() should return node tables' );
}


sub test_generate_container_show_containers : Test(4) {
    my $self     = shift;
    my $class    = $self->node_class;
    my $instance = $self->{node};
    my $mock     = Test::MockObject->new;


    $instance->set_always( run => 'some text in a container' );

    $mock->set_always( 'param', 'show' );
    $mock->set_series( 'isGod', 0,  1, 1, 1 );

    $instance->set_always( get_nodebase => $mock );
    $instance->set_always( get_parent_container => 0 );
    $instance->set_always( get_node_id => 123 );
    $mock->set_always( "getNode", $mock );
    $mock->set_always( "get_cgi", $mock );
    $mock->set_always( "get_user", $mock );

    $mock->set_always( process_contained_data => 'show containers stuff');
    $mock->set_always( get_node_id => 456);

    is( $instance->generate_container( 0, $mock ), 'some text in a container', '...if user is not authorised don\'t show container.' );
    is( $instance->generate_container( 0, $mock ), 'show containers stuff', '...but sends us to show containers if  authorised.');

    $mock->set_always( get_node_id => 123 );
    is( $instance->generate_container( 0, $mock ), 'some text in a container', '...we don\'t show containers if we are the show container node.' );

    $mock->set_always( get_node_id => 789 );
    $mock->set_always( getNode => undef );
    is( $instance->generate_container( 0, $mock ), 'some text in a container', '... but we don\'t show containers if there is no show containers node.' );
}

sub test_process_contained_data : Test(2) {
    my $self     = shift;
    my $class    = $self->node_class();
    my $instance = $self->{node};
    $instance->set_always(generate_container =>  'HELP CONTAINED_STUFF' );
    can_ok( $class, 'process_contained_data' );
    my $first_text = 'htmlpage generated';
    my $mock = Test::MockObject->new;
    is(
        $instance->process_contained_data( $mock, $first_text ),
        'HELP htmlpage generated',
        "Text substitution"
    );

}

sub test_generate_container : Test(4) {
    my $self     = shift;
    my $class    = $self->node_class();
    my $instance = $self->{node};

    my $expected = 'parsed, evaled and returned html';
    $instance->set_always( run => $expected );

    my $mock = Test::MockObject->new;
    $mock->{node_id} = 111;
    $mock->{title}   = 'A node title';
    can_ok( $class, 'generate_container' );

    # cgi stuff
    $mock->set_always( get_cgi => $mock )->set_always( param => 'a cgi param' )
      ;    # change this to series

    # user stuff
    $mock->set_always( get_user => $mock )->set_false('isGod')
      ;    # must change this to test both true and false
    $mock->set_always( get_cgi => $mock );

    my $result;
    my $node_id = 123;
    $instance->mock( get_node_id => sub { $node_id } );

    is( $result = $instance->generate_container( undef, $mock ),
        $expected,
        '...with no complications should return the output from parse.' );

    ## test for parent container;

    $instance->set_parent_container($node_id);
    $mock->set_always( getNode => $instance );

    dies_ok { $result = $instance->generate_container( 1, $mock ) }
      '...should avoid infinite recursion by dying.';

    my $id = 23;
    $node_id = 999;

    my $rv = $expected;
    $mock->set_always( getNode          => $instance );
    $instance->set_always( get_nodebase => $mock );
    $instance->set_always( run => "$expected CONTAINED_STUFF" );

    $instance->mock(
        get_parent_container => sub { return $node_id-- if $node_id > 986; return } );

    is(
        $result = $instance->generate_container( undef, $mock ),
        $expected . " $expected" x 7 . ' CONTAINED_STUFF',
        '...and should handle substituion properly.'
    );
}

1;
