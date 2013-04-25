package Everything::DB::Node::Test::nodegroup;

use strict;
use warnings;
use Test::MockObject;
use Test::More;
use Scalar::Util qw/blessed/;
use Data::Dumper;

use base 'Everything::DB::Node::Test::node';

sub setup_mock_node {

    my $self = shift;

    $self->SUPER::setup_mock_node;

    my $node = $self->{node};

	$node->set_always( -super => 4 )
	  ->set_always( -isGroup => 'grouptable' )
	  ->set_always( -selectGroupArray => [ 1, 2 ] )
	  ->set_true (qw/groupUncache/);

    $node->{group} = [1,2];


}


sub test_update_node :Test(8) {

    my $self = shift;

    local *Everything::logErrors;
    *Everything::logErrors = sub {};

    my $db_node = $self->{db_node};
    my $storage = $db_node->storage;

    $storage->set_true(qw/sqlSelect sqlUpdate sqlDelete sqlInsert/);

    my $node = $self->{node};

    # We need to override the superclass method To do this we get the
    ## code ref to the around modifier

    my $meta = $self->db_node_class->meta;

    my $update_node = $meta->get_method ('update_node');
    my ( $around_modifier ) = $update_node->around_modifiers;

    $node->{node_id} = 99;
    $node->mock( -restrict_type => sub { return $_[1] });

    my $rv = $around_modifier->( sub { $node->{node_id} }, $db_node, $node);

	is( $rv, 99,
		'update_node() should return results of call to superclass.' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'groupUncache', '... there is no change so last call in group.' );


    $node->{group} = [1,2,3];

    $rv = $around_modifier->( sub { $node->{node_id} }, $db_node, $node);

	is( $rv, 99,
		'If has one id to group still returns call to superclass.' );

    ($method, $args) = $storage->next_call;

    is( $method, 'sqlSelect', '...next is SELECT call to determine max rank.');

    is ( "@{$args}[1..3]", 'max(rank) grouptable grouptable_id=?', '.. with right args to sql call.' );

    # We are inserting a node_id into the group table, so the next
    # call is a sqlInsert call.

    # The $rank field gets set to one.

    ($method, $args) = $storage->next_call;

    is ( $method, 'sqlInsert', '...insert member into group table.');

    is ( $$args[1], 'grouptable', '...passes correct group table name.');

    is_deeply( $$args[2], { grouptable_id => $node->{node_id}, rank => 2, node_id => 3, orderby => 0 }, '...with expected arguments.') || diag Dumper $$args[2];

};

1;
