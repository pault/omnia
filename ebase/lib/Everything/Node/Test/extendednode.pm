package Everything::Node::Test::extendednode;

use strict;
use warnings;
use Test::More;

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

sub make_fixture :Test(setup => 6)
{
	my $self      = shift;
	$self->make_test_db();

	my $nb        = Everything::NodeBase->new( $self->{test_db}, 1, 'sqlite' );
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

	$newtype->insert(-1);

	## reset nb and force it to do another 'new'

	$db        = Everything::NodeBase->new( $self->{test_db}, 1, 'sqlite' );

	ok (my $nodeinstance =  $db->getNode('dbnode', 'extendednode', 'create force'));
	isa_ok($nodeinstance, 'Everything::Node::node');
	isa_ok($nodeinstance, 'Everything::Node::extendednode');

	my $newnewtype = $db->getNode('moreextendednode', 'nodetype', 'create force');
	$newtype = $db->getType('extendednode');
	$newnewtype->{extends_nodetype} = $newtype->{node_id};
	$newnewtype->insert(-1);

	## teardown $db again.

	$db        = Everything::NodeBase->new( $self->{test_db}, 1, 'sqlite' );
	### can we create a moreextendednode instance?
	my $newnewnode  = $db->getNode('blahblahblah', 'moreextendednode', 'create force');
	isa_ok($newnewnode, 'Everything::Node::node');
	isa_ok($newnewnode, 'Everything::Node::extendednode');
	isa_ok($newnewnode, 'Everything::Node::moreextendednode');

	$newnewnode = Test::MockObject::Extends::NoCheck->new($newnewnode);
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

	$node->set_true(qw( -hasAccess -restrictTitle -getId ));
	$node->{foo}  = 11;

	delete $node->{type}{restrictdupes};

	my $time = time();

	$db->{storage} = Test::MockObject::Extends->new( $db->{storage} );
	$db->{storage}->set_always( -now => $time );

	$node->set_true( 'cache' );
	$node->{node_id} = 0;

	my $result = $node->insert( 999 );

	ok( defined $result, 'insert() should return a node_id if no dupes exist' );
	is( $result, 6, '... with the proper sequence' );

	my $dbh = $db->{storage}->getDatabaseHandle();
	my $sth = $dbh->prepare(
		'SELECT createtime, author_user, hits FROM node WHERE node_id=?'
	);
	$sth->execute( $result );
	my $node_ref = $sth->fetchrow_hashref();
	is_deeply( $node_ref,
		{
			createtime  => $time,
			author_user => 999,
			hits        => 0,
		},
		'... with the proper fields'
	);
	$sth->finish();
}


package Test::MockObject::Extends::NoCheck;

use base 'Test::MockObject::Extends';

sub check_class_loaded {1};

1;
