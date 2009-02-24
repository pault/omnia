package Everything::Test::NodeBase::Workspace;

use strict;
use warnings;

use base 'Everything::Test::NodeBase';

use SUPER;
use Test::More;

sub test_join_workspace :Test( 7 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	is( $nb->joinWorkspace(), 1,
		'joinWorkspace() should return 1 without workspace to join' );

	$nb->mock( getRef => sub { $_[1] = 0 } ); 
	is( $nb->joinWorkspace( 'foo' ), -1,
		'... or -1 unless workspace is a valid node' );

	$nb->set_true( 'getRef' );
	$storage->set_series( getVars => 'vars' );

	is( $nb->joinWorkspace( $storage ), 1,
		'... or 1 if joining workspace works' );

	is( $nb->{workspace}, $storage, '... setting workspace attribute' );
	is( $storage->{nodes}, 'vars',  '... setting workspace nodes' );
	is_deeply( $storage->{cached_nodes}, {}, '... and cache' );

	$nb->joinWorkspace( $storage );
	is_deeply( $storage->{nodes}, {},
		'... using default nodes unless present' );
}

sub test_get_node_workspace :Test( 5 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	my $node = Test::MockObject->new;
	my $type = Test::MockObject->new;
	$node->set_always( type => $type );
	$type->set_series( getId => 1, 1, 2 );
	$node->set_series ( getId => 2, 3, 4 );
	$node->set_series ( get_title => qw/foo bar baz/ );
	my $nodes   =
	{
		2 => { node_id => 2, title => 'foo', type => { node_id => 1 } },
		3 => { node_id => 3, title => 'bar', type => { node_id => 1 } },
		4 => { node_id => 4, title => 'baz', type => { node_id => 2 } },
	};

	$nb->{workspace}{nodes} = $nodes;
	my $other_type = Test::MockObject->new;
	$other_type->set_always( getId => 1 );
	$nb->mock( getType => sub { return $other_type } )
	   ->mock( getNode => sub { return $node } );

	my $result = [ sort @{ $nb->getNodeWorkspace() } ];
	is_deeply( $result, [ map { $node } 2 .. 4 ],
		'getNodeWorkspace() should return all nodes without criteria' );


	$result   = [ sort @{ $nb->getNodeWorkspace( {}, 1 ) } ];
	is_deeply( $result, [ map { $node } 2, 3 ],
		'... or only nodes of the specific type' );

	$nodes->{5} = { node_id => 5, title => 'foo', type => { node_id => 2 } };
	my @keys = sort keys %$nodes;
	$nb->mock( getNode => sub { return $$nodes{ shift @keys } } );
	$result   = [ sort @{ $nb->getNodeWorkspace( { title => 'foo' } ) } ];
	is_deeply( $result, [ map { $nodes->{$_} } 2, 5 ],
		'... or only nodes matching a single criterion' );

	@keys = sort keys %$nodes; # reset keys
	$result   = [sort @{ $nb->getNodeWorkspace({ title => [qw( bar baz )]} )} ];
	is_deeply( $result, [ map { $nodes->{$_} } 3, 4 ],
		'... or only nodes matching a multi-value criterion' );

	$nodes->{6} = bless { node_id => 6, type => { node_id => 3 } },
		'Everything::Node';
	$nb->mock( getNode => sub { { node => bless {
		node_id => $_[1], type => { node_id => 3 } }, 'Everything::Node'
	}});

	my $selector = bless { node_id => 6 }, 'Everything::Node';

	$result   = [sort @{ $nb->getNodeWorkspace( { node => $selector } ) } ];
	is_deeply( $result, [ { node => $nodes->{6} } ],
		'... or blessed nodes with matching node ids' );
}

sub test_get_node :Test( +5 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	$self->SUPER();

	$nb->set_false( 'SUPER' );
	is( $nb->getNode( 100 ), undef,
		'getNode() should return false unless SUPER() call returns a node' );

	$nb->set_always( SUPER => $storage );
	$storage->{node_id} = 100;
	$storage->set_series( getWorkspaced => 0, 'workspaced' );
	is( $nb->getNode( 102 ), $storage,
		'... and should return non-workspaced node, if not in workspace' );

	$nb->{workspace}{nodes}{100} = 0;
	is( $nb->getNode( 102 ), $storage,
		'... or if workspaced node has no value' );

	$nb->{workspace}{nodes}{100} = 1;
	is( $nb->getNode( 102 ), $storage,
		'... even when fetched from workspace' );

	is( $nb->getNode( 102 ), 'workspaced',
		'... but should return it if it does exist' );
}

sub test_get_node_with_where :Test( 4 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	$nb->{workspace}{nodes} = { map { $_ => { node_id => $_, w => $_ } } 1..3 };

	$nb->set_series( getNodeWhere => 0,
		[ map { { node_id => $_, w => $_ } } 1 .. 3 ] )
	   ->set_always( getNodeWorkspace => [] );

	my $result = $nb->getNode( { node_id => 10 } );

	is( $result, undef,
		'getNode() with where should return nothing with no node to find' );

	is( $nb->getNode( { node_id => 10 } ), undef,
		'... or nothing with no nodes in workspace' );

	$nb->set_always( getNodeWorkspace => [values %{ $nb->{workspace}{nodes} }]);
	is_deeply( $nb->getNode( { node_id => 11 } ), { node_id => 1, w => 1 },
		'... or the workspaced node, if there is a match' );

	is_deeply( $nb->getNode( { node_id => 11 }, '', 'w desc' ),
		{ node_id => 3, w => 3 },
		'... ordered by secondary field, if provided' );
}

1;
