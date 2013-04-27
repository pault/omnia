package Everything::DB::Node::Test::node;

use strict;
use warnings;
use Test::MockObject;
use Test::More;
use Scalar::Util qw/blessed/;
use Data::Dumper;

use base 'Test::Class';

sub startup : Test(startup => 2) {
    my $self = shift;
    my $class = $self->db_node_class;
    use_ok( $class );
    can_ok( $class, 'new' );

}

sub db_node_class {
    my $self = shift;
    my $name = blessed($self) || $self;
    $name =~ s/Test:://;
    return $name;
}

sub setup :Test(setup) {
    my $self = shift;

    my $storage = Test::MockObject->new;
    $self->{db_node} = $self->db_node_class->new( storage => $storage );

    $self->setup_mock_node;
}

sub setup_mock_node {

    my $self = shift;
    my $node = Test::MockObject->new;

    $node->{node_id} = 11;
    $node->set_always( get_type_nodetype => 1 )
      ->set_always( getId => 10 );

    $self->{node} = $node;
}

sub test_update_node :Test( 7 )
{

	my $self = shift;

	my $db_node = $self->{db_node};
	my $storage = $db_node->storage;
	my $node = $self->{node};

	$storage->set_true(qw( incrementGlobalVersion sqlUpdate sqlSelect update_or_insert))
	   ->set_list( getFieldsHash => 'boom', 'foom' )
           ->set_always( -retrieve_nodetype_tables  => [ 'table', 'table2' ] );

	$node->{foom} = 1;
	$db_node->update_node( $node );

	# The purpose of the tests below is to ensure that the right
	# arguments are passed to the DB.pm methods.

	my ( $method, $args ) = $storage->next_call();
	is( $method, 'getFieldsHash', '... fetching the fields' );

	is( $args->[1], 'table',  '... of each table' );

	( $method, $args ) = $storage->next_call();
	is( "$method", 'update_or_insert', '... updating each table' );

	is( $$args[1]{table}, 'table', '...with right table.'); 

	is( keys %{ $args->[1]->{data} }, 1,
		'... with only allowed fields' );
	is( $args->[1]->{where},           'table_id = ?',    '... for table' );
	is_deeply( $args->[1]->{bound}, [ $node->{node_id} ], '... with node id' );

}

sub test_insert_node :Test(10) {
    my $self = shift;

    my $db_node = $self->{db_node};
    my $storage = $db_node->storage;
    my $node = $self->{node};

    ## Main thing is that this method sends the right data to the
    ## storage instance

    $storage->mock( -retrieve_nodetype_tables => sub { [ qw/table1 table2/ ] } );

    $storage->set_list( -getFieldsHash =>  qw/firstfield secondfield/ );

    $node->{firstfield} = 'firstvalue';
    $node->{secondfield} = 'secondvalue';

    $storage->mock( -lastValue => sub { 999 } );

    $storage->set_true('sqlInsert');

    $storage->set_always( -now => '0000-00-00' );

    is( $db_node->insert_node( $node), 999, 'insert_node returns node_id.');

    my ($method, $args ) = $storage->next_call;

    is ($method, 'sqlInsert', '...and calls DB.pm sqlInsert.');

    is ( $$args[1], 'node', '...with node table as first argument.' );

    delete $$args[2]->{-createtime}; # not testing for this hack

    is_deeply ( $$args[2], { firstfield => 'firstvalue', secondfield => 'secondvalue' }, '...and hash of keys, values and second argument.' );

    ($method, $args ) = $storage->next_call;

    is ($method, 'sqlInsert', '...and calls DB.pm sqlInsert.');

    is ( $$args[1], 'table1', '...with table1 as first argument.' );

    is_deeply ( $$args[2], { table1_id => 999, firstfield => 'firstvalue', secondfield => 'secondvalue' }, '...and hash of keys, values and second argument.' );

    ($method, $args ) = $storage->next_call;

    is ($method, 'sqlInsert', '...and calls DB.pm sqlInsert.');

    is ( $$args[1], 'table2', '...with table2 as first argument.' );

    is_deeply ( $$args[2], { table2_id => 999, firstfield => 'firstvalue', secondfield => 'secondvalue'}, '...and hash of keys, values and second argument.' );


}




1;
