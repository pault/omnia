package Everything::Node::Test::extendednode;

use strict;
use warnings;
use Test::More;
use Scalar::Util qw/blessed/;

use base 'Everything::Node::Test::node';


sub startup :Test( startup )
{
	my $self         = shift;

	$self->{errors}  = [];

	$self->make_base_test_db();

	my $mock         = Test::MockObject->new();
	$mock->fake_module( 'Everything', logErrors => sub
		{
			push @{ $self->{errors} }, [@_]
		}
	);
	$self->{mock} = $mock;
	*Everything::Node::node::DB = \$mock;

 	my %import;

 	my $mockimport = sub { $import{ +shift }++ };

 	for my $mod (qw( DBI Everything Everything::XML))
 	{
 		$mock->fake_module( $mod, import => $mockimport );
 	}

}


sub test_imports :Test(startup => 0) {
    return "Doesn't import symbols";
}

sub make_fixture :Test(setup => 7)
{
	my $self      = shift;
	$self->make_test_db();

	my $nb        = Everything::NodeBase::Cached->new( $self->{test_db}, 1, 'sqlite' );
	my $db        = Test::MockObject::Extends->new( $nb );


	*Everything::Node::node::DB = \$db;
	$self->{mock_db}            = $db;
	$self->{node}{DB}           = $db;
	$self->{errors}             = [];
	$self->reset_mock_node();
	
	
	$db = 	$self->{mock_db};
	*Everything::Node::node::DB = \$db;

	$self->{node}{DB}           = $db;
	$self->{errors} = [];

}

sub reset_mock_node
{
	my $self      = shift;
	my $db = $self->{mock_db};

	my $type = $db->getType('node');
	my $newtype = $db->getNode( 'extendednode', 'nodetype', 'create force');

	## dbtable
	$db->createNodeTable( 'extendednodetable' );
	$db->addFieldToTable( 'extendednodetable', 'afield', 'char(32)' );
	$newtype->set_sqltable('extendednodetable');
	$newtype->insert(-1);

	## reset nb and force it to do another 'new'

	$db        = Everything::NodeBase::Cached->new( $self->{test_db}, 1, 'sqlite' );

	ok (my $nodeinstance =  $db->getNode('dbnode', 'extendednode', 'create force'));
	isa_ok($nodeinstance, 'Everything::Node::node');
	isa_ok($nodeinstance, 'Everything::Node::extendednode');

	my $newnewtype = $db->getNode('moreextendednode', 'nodetype', 'create force');
	$newtype = $db->getType( 'extendednode' );

	$newnewtype->{extends_nodetype} = $newtype->{node_id};
	$newnewtype->insert(-1);

	## teardown $db again.

	$db        = Everything::NodeBase::Cached->new( $self->{test_db}, 1, 'sqlite' );

	### can we create a moreextendednode instance?
	my $newnewnode  = $db->getNode('blahblahblah', 'moreextendednode', 'create force');
	isa_ok($newnewnode, 'Everything::Node::node');
	isa_ok($newnewnode, 'Everything::Node::extendednode');
	isa_ok($newnewnode, 'Everything::Node::moreextendednode');

	can_ok( 'Everything::Node::moreextendednode', 'get_afield', 'set_afield' );

	$newnewnode = Test::MockObject::Extends::NoCheck->new($newnewnode);
	$newnewnode->set_nodebase ( $self->{mock_db} );
	$self->{node} = $newnewnode;

}

### we need to override this test because the sequence is different
sub test_insert :Test( 3 )
{
	my $self               = shift;
	my $node               = $self->{node};
	my $db                 = $self->{mock_db};
	my $type               = $db->getType( 'nodetype' );

	$node->{node_id}       = 0;
	$node->{type}          = $type;
	$node->{type_nodetype} = 1;
	$node->{title} = 'mock title';

	$node->set_true(qw( -hasAccess -restrictTitle -getId ));
	$node->{foo}  = 11;

	delete $node->{type}{restrictdupes};

	my $time = time();

	$db->set_always( -now => $time );

	$node->set_true( 'cache' );
	$node->{node_id} = 0;

	my $result = $node->insert( 'user' );

	ok( defined $result, 'insert() should return a node_id if no dupes exist' );
	is( $result, 6, '... with the proper sequence' );

	my $dbh = $db->{storage}->getDatabaseHandle();
	my $sth = $dbh->prepare(
		'SELECT createtime, author_user FROM node WHERE node_id=?'
	);
	$sth->execute( $result );
	my $node_ref = $sth->fetchrow_hashref();
	is_deeply( $node_ref,
		{
			createtime  => $time,
			author_user => 'user',
		},
		'... with the proper fields'
	);
	$sth->finish();
}

sub test_check_accessors : Test(8) {

    my $self = shift;
    my $node = $self->{node};


    ## XXX: we need to mock the cache whihch is called from
    ## NodeBase.pm- caching should be only turned on when we ask for
    ## it explicitly, so this mocking in temporary
    $self->{mock_db}->{cache} = Test::MockObject->new;
    $self->{mock_db}->{cache}->set_true( 'incrementGlobalVersion', 'cacheNode' );
    $self->{mock_db}->{cache}->set_false( 'getCachedNodeByName', 'getCachedNodeById' );

    my $meta = $node->meta;
    my @methods = $meta->get_all_methods;
    ## accessors set in setup

    can_ok( blessed( $node ), 'get_extendednodetable_id', 'get_afield' ) || do { diag $_->name foreach @methods };

    $node->set_afield('some random text');
    $node->update( -1 );

    my $dbh = $self->{mock_db}->getDatabaseHandle;
    my $sth = $dbh->prepare( "select afield from extendednodetable where extendednodetable_id = $$node{node_id}");
    $sth->execute;
    my ( $value ) = $sth->fetchrow_array;

    is( $value, 'some random text', '...can update virtual attributes.');
    is( $node->get_afield, 'some random text', '...can be accessed using accessor.');

    ### create an instance of moreextendednode

    my $new;

    isa_ok ($new = $self->{mock_db}->getNode( 'test node', 'moreextendednode', 'create force' ), 'Everything::Node::moreextendednode' );

    my $id =  $new->insert( -1 );
    ok($id > 0, '... inserts new node.' );

    $new->set_afield( '777' );

    ok ($new->update( -1 ), '...updates it.');

    $new = $self->{mock_db}->getNode( 'test node', 'moreextendednode', 'force' );
    $sth = $dbh->prepare( "select afield from extendednodetable where extendednodetable_id = $$new{node_id}");
    $sth->execute;
    ( $value ) = $sth->fetchrow_array;

    is ( $value, 777, '...the updated field is in the table.'); 
    is ( $new->get_afield, 777 );
}

sub test_nodetype_metadata :Test(25) {

    my $self = shift;
    my $db = $self->{mock_db};

    my @type_names = $db->{storage}->fetch_all_nodetype_names;

    foreach my $name ( @type_names ) {
	my $typenode = $db->getType( $name );
	is ( $name, $typenode->get_title, "...name of class $name corresponds to typenode.");
	foreach my $access (qw/derived_defaultauthoraccess derived_defaultgroupaccess derived_defaultotheraccess derived_defaultguestaccess/) {
	    my $access_string = $$typenode{ $access };
	    unlike ( $access_string, qr/i/, "... $access, $access_string for  $name is properly constructed." );
	}
    }


}

package Test::MockObject::Extends::NoCheck;

use base 'Test::MockObject::Extends';

sub check_class_loaded {1};

1;
