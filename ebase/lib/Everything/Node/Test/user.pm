package Everything::Node::Test::user;

use strict;
use warnings;

use SUPER;
use Scalar::Util 'reftype';

use Test::More;

*Everything::Node::user::SUPER = \&UNIVERSAL::SUPER;

use base 'Everything::Node::Test::setting';

sub node_class { 'Everything::Node::user' }

sub test_extends :Test( +1 )
{
	my $self   = shift;
	my $module = $self->node_class();
	ok( $module->isa( 'Everything::Node::setting' ),
		"$module should extend setting node" );
	$self->SUPER();
}

sub test_dbtables :Test( 2 )
{
	my $self   = shift;
	my $node   = $self->{node};
	my @result = $node->dbtables();
	is( $result[0], 'user',     'dbtables() should return array of user...' );
	is( $result[1], 'document', '... and document as first tables' );
}

sub test_insert :Test( 5 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_series( -SUPER => 0, 10, 10 )
		 ->set_true( 'update' );

	$node->{title} = 'foo';

	ok( ! $node->insert( 'user' ),
		'insert() should return false if SUPER call fails' );

	is( $node->insert( 'user' ), 10,
		'... should return inserted node_id on success' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'update',  '... then calling update()' );
	is( $args->[1], 'user', '... with the user' );
	is( $node->{author_user}, 10,
		'... and seting "author_user" to inserted node_id' );
}

sub test_insert_restrict_dupes :Test( +0 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->set_true( -update );
	$self->SUPER();
}

sub test_insert_restrictions :Test( +0 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->set_true( -update );
	$self->SUPER();
}

sub test_is_god :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$db->set_series( getNode => 0, ($node) x 2 );
	$node->set_always( inGroup     => 'inGroup' )
		 ->set_always( inGroupFast => 'inGroupFast' );

	ok( ! $node->isGod(),
		'isGod() should return false unless it can find gods usergroup' );

	is( $node->isGod(), 'inGroupFast',
		'... should call inGroupFast() without recurse flag' );
	is( $node->isGod( 1 ), 'inGroup', '... and inGroup() with it' );
}

sub test_is_guest :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	my @newnodes =
	(
		bless( { guest_user => 0 }, 'FakeNode' ),
		bless( { guest_user => 1 }, 'FakeNode' )
	);

	$db->set_series( getNode => 0, ($node) x 2 );
	$node->set_series( getVars => undef, @newnodes );

	ok( $node->isGuest(),
		'isGuest() should return true unless it can get system settings node' );

	ok( $node->isGuest(),
		'... should return true unless it can get system settings node' );

	$node->{node_id} = 1;

	ok( ! $node->isGuest(), '... should return false unless node_ids match' );
	ok( $node->isGuest(),   '... and true if they do' );
}

sub test_get_node_keys :Test( +5 )
{
	my $self = shift;
	my $node = $self->{node};
	my %keys = map { $_ => 1 } qw( passwd lasttime title foo_id );

	$node->set_always( getNodeDatabaseHash => \%keys );

	my $keys = $node->getNodeKeys();
	is( reftype($keys), 'HASH', 'getNodeKeys() should return a hash' );
	is( $keys->{passwd},   1, '... not deleting password if not exporting' );
	is( $keys->{lasttime}, 1, '... nor time of most recent activity' );

	$keys = $node->getNodeKeys( 1 );
	ok( !exists $keys->{passwd},   '... but should delete "passwd"' );
	ok( !exists $keys->{lasttime}, '... and "lasttime" if exporting' );
	$self->SUPER();
}

sub test_verify_field_update :Test( 5 )
{
	my $self = shift;
	my $node = $self->{node};

	for my $field (qw( title karma lasttime ))
	{
		ok( ! $node->verifyFieldUpdate( $field ),
			"verifyFieldUpdate should return false for '$field' field" );
	}

	$node->set_series( SUPER => 1, 0 );

	ok( $node->verifyFieldUpdate( 'absent' ),
		'... should return false if SUPER() call does' );

	ok( !$node->verifyFieldUpdate( 'title' ),
		'... and false if field is restricted here, but not in parent' );
}

sub test_conflicts_with :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};
	ok( ! $node->conflictsWith(), 'conflictsWith() should return false' );
}

sub test_update_from_import :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};
	ok( ! $node->updateFromImport(), 'updateFromImport() should return false' );
}

sub test_restrict_title :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};

	ok( ! $node->restrictTitle(),
		'restrictTitle() should return false with no title' );

	$node->{title} = 'foo|';
	ok( ! $node->restrictTitle(), '... or false with bad chars in title' );

	$node->{title} = 'some user_name';
	ok( $node->restrictTitle(), '... or true if it has only good chars' );
}

sub test_get_nodelets :Test( 3 )
{
	my $self     = shift;
	my $node     = $self->{node};
	my $db       = $self->{mock_db};
	my $nodelets = { nodelets => '1,2,4' };

	$node->set_always( getVars => $nodelets );
	is_deeply( $node->getNodelets(), [ 1, 2, 4 ],
		'getNodelets() should return existing nodelets vars in array ref' );

	delete $nodelets->{nodelets};
	$db->set_always( getNode => $node );
	$node->set_series( isOfType => 1, 0 );

	$nodelets->{nodelet_group} = $node;
	$node->{group} = [ 4, 2, 1 ];
	is_deeply( $node->getNodelets(), [ 4, 2, 1 ],
		'... or from user nodelet group, if specified' );

	delete $nodelets->{nodelet_group};

	$node->{group} = [ 8, 6, 1 ];

	is_deeply( $node->getNodelets( 'default' ), [ 8, 6, 1 ],
		'... or from default group' );
}

1;
