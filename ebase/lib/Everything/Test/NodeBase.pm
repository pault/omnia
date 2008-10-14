package Everything::Test::NodeBase;

use strict;
use warnings;

use base 'Test::Class';

use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::Warn;

use Scalar::Util 'blessed';

sub module_class
{
	my $self =  shift;
	my $name =  blessed( $self );
	$name    =~ s/Test:://;
	return $name;
}

sub startup :Test( startup => 3 )
{
	my $self   = shift;
	my $module = $self->module_class();
	use_ok( $module ) or exit;

	can_ok( $module, 'new' );

	$self->reset_mock_nb();

	isa_ok( $self->{nb}, $module );
}

sub make_fixture :Test( setup )
{
	my $self    = shift;
	my $storage = Test::MockObject->new();
	$self->reset_mock_nb();

	$storage->set_always('selectNodeWhere', [1..3]);

	$self->{storage}     = $storage;
	$self->{nb}{storage} = $storage;
	$self->{errors}      = [];
}

sub reset_mock_nb
{
	my $self   = shift;
	my $module = $self->module_class();

	my $mock_db = Test::MockObject->new();
	$mock_db->set_false(qw( getNodeByIdNew getNodeByName
	                        -fetch_all_nodetype_names ))
			->set_true(qw( databaseConnect buildNodetypeModules ))
			->fake_module( 'Everything::DB::fake_db', 'new', sub { $mock_db });

	my $nb      = $module->new( '', 0, 'fake_db' );
	$self->{nb} = Test::MockObject::Extends->new( $nb );
}

BEGIN
{
	for my $method (qw(
		getDatabaseHandle sqlDelete sqlSelect
		sqlSelectJoined sqlSelectMany sqlSelectHashref sqlUpdate sqlInsert
		_quoteData sqlExecute getNodeByIdNew getNodeByName constructNode
		selectNodeWhere getNodeCursor countNodeMatches getAllTypes
		dropNodeTable quote genWhereString  now createGroupTable fetchrow timediff getNodetypeTables createNodeTable
	))
	{
		eval <<"		END_SUB";
		sub test_$method :Test( 3 )
		{
			my \$self    = shift;
			my \$nb      = \$self->{nb};
			my \$storage = \$self->{storage};

			\$storage->set_always( $method => 'proxied_$method' );
			can_ok( \$nb, '$method' );

			my \$result = \$nb->$method();

			is( \$storage->next_call(), '$method',
				'$method should proxy to storage method' );
			is( \$result, 'proxied_$method', '... returning result' );
		}
		END_SUB
	}
}

sub test_new
{
	# check $db param
	# check presence of NodeCache
	# check dbname
	# check staticNodetypes field
	# check storage
	# check nodetypeModules
	# check if setting type exists
	#	- check cache settings
	#	- check cache size
}

sub test_join_workspace :Test( 6 )
{
	my $self         = shift;
	my $nb           = $self->{nb};
	$nb->{workspace} = 'old_ws';

	is( $nb->joinWorkspace(), 1,
		'joinWorkspace() should return true without a workspace' );
	is( $nb->joinWorkspace( undef ), 1, '... or a defined workspace' );
	is( $nb->joinWorkspace( 0 ), 1,     '... or an actual workspace' );
	ok( ! exists $nb->{workspace},      '... deleting existing workspace' );

	local *Everything::NodeBase::Workspace::joinWorkspace;
	*Everything::NodeBase::Workspace::joinWorkspace = sub { return $_[1] };

	is( $nb->joinWorkspace( 100 ), 100,
		'... returning result of joinWorkspace() call in new package' );
	ok( $nb->isa( 'Everything::NodeBase::Workspace' ),
		'... reblessing into workspace package' );
}

sub test_build_nodetype_modules :Test( 3 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	$nb->set_series( loadNodetypeModule => 1, 1, 0, 1 );
	$nb->set_false( 'getNode');
	$storage->mock(
		fetch_all_nodetype_names => sub { qw( node nodetype cow dbtable ) }
	);
	$storage->set_always( getFieldsHash => '' );

	my $result;

	warning_like { $result = $nb->buildNodetypeModules() } qr/no such nodetype/i;
	is( keys %$result, 3, 'buildNodetypeModules() should return a hash ref' );
	is_deeply(
		$result,
		{ map { 'Everything::Node::' . $_ => 1 } qw( node nodetype dbtable ) },
		'... for all loadable nodes fetched from storage engine'
	);
}


sub test_build_nodetypedb_modules :Test( 9 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	$nb->set_false( 'loadNodetypeModule');
	$storage->mock(
		fetch_all_nodetype_names => sub { qw( supernode extendednode superextendednode ) }
	);
	$nb->set_series('getNode', {extends_nodetype => 1},  {extends_nodetype => 2},  {extends_nodetype => 3} );
	$nb->set_series('getType', {title => 'node'},  {title => 'supernode'},  {title => 'extendednode'} );


	my $result  = $nb->buildNodetypeModules();
	is( keys %$result, 3, 'buildNodetypeModules() should return a hash ref' );
	no strict 'refs';
	is_deeply(
		$result,
		{ map { 'Everything::Node::' . $_ => 1 } qw( supernode extendednode superextendednode ) },
		'... for all loadable nodes fetched from storage engine'
	);

	# ensure that each of these are in the symbol table
	foreach my $type (qw/ supernode extendednode superextendednode /) {
	    ok (defined %{ "Everything::Node::" . $type . "::"}, "... \%Everything::Node::${type}:: should be in the symbol table.")
	}

	## check that the nodes are properly blessed.
	my $node = bless {}, 'Everything::Node::superextendednode';
	isa_ok ($node, 'Everything::Node::node');
	isa_ok ($node, 'Everything::Node::supernode');
	isa_ok ($node, 'Everything::Node::extendednode');
	isa_ok ($node, 'Everything::Node::superextendednode');
}

sub test_load_nodemethods : Test(5) {
    my $self = shift;
    my $nb = $self->{nb};
    can_ok($self->module_class, "load_nodemethods") or return;
    my %modules = ( "Everything::Node::foo" => 1, "Everything::Node::bar" => 1);
    $nb->set_always('getNodeWhere', [ {code => 'return "hhhh"', title => 'vulcan'}, {code => 'my $x = 10', title => "hephaistos"} ]);
    $nb->set_always('getType', { node_id => 1111} );
    $nb->load_nodemethods(\%modules);

    ok ( defined *{Everything::Node::foo::vulcan}{CODE}, '...should create relevant symbol table entry.');
    ok ( defined *{Everything::Node::foo::hephaistos}{CODE}, '...should create relevant symbol table entry.');
    ok ( defined *{Everything::Node::bar::vulcan}{CODE}, '...should create relevant symbol table entry.');
    ok ( defined *{Everything::Node::bar::hephaistos}{CODE}, '...should create relevant symbol table entry.');


}


sub test_rebuild_nodetype_modules :Test( 1 )
{
	my $self = shift;
	my $nb   = $self->{nb};

	$nb->set_always( 'buildNodetypeModules', 'bntm' );
	$nb->{nodetypeModules} = '';

	$nb->rebuildNodetypeModules();
	is( $nb->{nodetypeModules}, 'bntm',
		'buildNodetypeModules() should cache results of rebuild' );
}

sub test_load_nodetype_module :Test( 3 )
{
	my $self = shift;
	my $nb   = $self->{nb};

	ok( $nb->loadNodetypeModule( 'Everything::NodeBase' ),
		'loadNodetypeModule() should return true if module is loaded' );

	ok( $nb->loadNodetypeModule( 'Everything::Node::user' ),
		'... or if module can be loaded' );

	ok( ! $nb->loadNodetypeModule( 'Everything::Node::blah' ),
		'... but false if it cannot' );
}

sub test_reset_node_cache :Test( 1 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	$storage->set_true( 'resetCache' );
	$nb->{cache} = $storage;

	$nb->resetNodeCache();
	is( $storage->next_call(), 'resetCache',
		'resetNodeCache() should call resetCache() on cache' );
}

sub test_get_cache :Test( 1 )
{
	my $self     = shift;
	my $nb       = $self->{nb};
	$nb->{cache} = 'cache';

	is( $nb->getCache(), 'cache', 'getCache() should return cache' );
}

sub test_get_node_by_id :Test( 2 )
{
	my $self     = shift;
	my $nb       = $self->{nb};

	$nb->set_always( getNode => 'gn' );
	is( $nb->getNodeById( 'id', 'selectop' ), 'gn',
		'getNodeById() should return getNode() result' );

	my ($method, $args) = $nb->next_call();
	is( join('-', @$args), "$nb-id-selectop",
		'... passing node id and select op' );
}

sub test_new_node :Test( 6 )
{
	my $self = shift;
	my $nb   = $self->{nb};

	$nb->set_always( 'getType', 'gt' )
	   ->set_always( 'getNode', 'gn' );

	my $result = $nb->newNode( 'type', 'title' );

	my ( $method, $args ) = $nb->next_call();
	is( $method, 'getType', 'newNode() should fetch nodetype node' );
	is( $args->[1], 'type', '... for the requested nodetype' );

	( $method, $args ) = $nb->next_call();
	is( $method, 'getNode', '... calling getNode()' );
	is( join( '-', @$args[ 1, 2 ] ), 'title-gt',
		'... with title and nodetype node' );

	is( $args->[3], 'create force', '... forcing node creation' );

	$nb->newNode( '' );

	( $method, $args ) = $nb->next_call(2);
	like( $args->[1], qr/^dummy\d+/,
		'... using a dummy title without one provided' );
}

sub test_get_node :Test( 3 )
{
	my $self = shift;
	my $nb   = $self->{nb};

	ok( ! $nb->getNode(),
		'getNode() should return false without node to fetch' );
	ok( ! $nb->getNode( '' ), '... or empty string for fetcher' );

	my $node = bless {}, 'Everything::Node';
	is( $nb->getNode( $node ), $node,
		'... and should return node if it is a node already' );

	# XXX: improve coverage here
}

sub test_get_node_zero :Test( 7 )
{
	my $self = shift;
	my $nb   = $self->{nb};

	$nb->{nodezero} = 'nz';
	is( $nb->getNodeZero(), 'nz',
		'getNodeZero() should return existing cached node zero' );

	$nb->set_series( getNode => { nz => 1 }, 'rootuser' );

	delete $nb->{nodezero};

	my $result = $nb->getNodeZero();

	is( $result->{nz},      1, '... or should fetch location node' );
	is( $result->{node_id}, 0, '... with node_id 0' );

	for my $access (qw( guest other group ))
	{
		is( $result->{$access . 'access'}, '-----',
			"... and no access for $access" );
	}
	is( $nb->{nodezero}, $result, '... caching it' );
}

sub test_get_node_where :Test( 5 )
{
	my $self = shift;
	my $nb   = $self->{nb};

	$nb->set_series( 'selectNodeWhere', undef, 'foo', [ 1 .. 5 ] )
	   ->set_series( 'getNode', 0, 2, 0, 4, 5 );

	my @expected = qw( where type orderby limit offset reftotalrows );
	my $result   = $nb->getNodeWhere( @expected );

	my ( $method, $args ) = $nb->next_call();
	is( $method, 'selectNodeWhere',
		'getNodeWhere() should delegate to selectNodeWhere()' );
	is( join( '-', @$args ), join( '-', $nb, @expected ),
		'... passing most args' );

	is( $result, undef, '... returning if it fails' );
	is( $nb->getNodeWhere(), undef, '... or if it does not return a listref' );

	$result = $nb->getNodeWhere( @expected );
	is_deeply( $result, [ 2, 4, 5 ],
		'... fetching and returning a list ref of nodes' );
}

sub test_get_type :Test( 9 )
{
	my $self = shift;
	my $nb   = $self->{nb};

	is( $nb->getType(), undef,
		'getType() should return unless passed a node thing' );

	is( $nb->getType( '' ), undef, '... or if it is empty' );

	my $mock_node = Test::MockObject::Extends->new( 'Everything::Node' );

	is( $nb->getType( $mock_node ), $mock_node,
		'... returning node if it is a node' );

	$nb->set_series( getNode => 'name', 'id' );

	is( $nb->getType( 'name' ), 'name',
		'... returning fetched node, if named' );

	my ( $method, $args ) = $nb->next_call();
	is( join( '-', @$args ), "$nb-name-1", '... by name for nodetype' );

	is( $nb->getType( 12345 ), 'id',
		'... returning node for positive node_id' );

	( $method, $args ) = $nb->next_call();
	is( join( '-', @$args ), "$nb-12345", '... by id alone' );

	is( $nb->getType(  0 ), undef, '... returning nothing for zero id' );
	is( $nb->getType( -1 ), undef, '... or for negative node_id' );
}

sub test_get_fields :Test( 2 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	$nb->set_always( getFieldsHash => 'gfh' );

	is( $nb->getFields( 'table' ), 'gfh',
		'getFields() should return getFieldsHash() result' );

	my ( $method, $args ) = $nb->next_call();
	is( join( '-', @$args ), "$nb-table-0", '... passing table name' );
}

=cut

sub test_get_nodetype_tables :Test( 7 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	ok( ! $nb->getNodetypeTables(),
		'getNodetypeTables() should return false without type' );

	is_deeply( $nb->getNodetypeTables( 1 ), [ 'nodetype' ],
		'... and should return nodetype given nodetype id' );

	is_deeply( $nb->getNodetypeTables( { node_id => 1  } ), [ 'nodetype' ],
		'... or nodetype node' );

	is_deeply( $nb->getNodetypeTables( { title => 'nodemethod', node_id => 0 }),
		[ 'nodemethod' ],
		'... or should return nodemethod if given nodemethod node' );

	$nb->mock( getRef => sub { $_[1] = $storage } );
	$storage->set_series( getTableArray => [qw( foo bar )] );

	is_deeply( $nb->getNodetypeTables( 'bar' ), [qw( foo bar )],
		'... or calling getTableArray() on promoted node' );

	is_deeply( $nb->getNodetypeTables( 'baz' ), [],
		'... returning nothing if there are no nodetype tables' );

	is_deeply( $nb->getNodetypeTables( 'flaz', 1 ), [ 'node' ],
		'... but adding node if addNode flag is true' );
}

=cut

sub test_get_ref :Test( 5 )
{
	my $self = shift;
	my $nb   = $self->{nb};

	$nb->set_series( getNode => 'first', 'second', 'not third' );

	my ( $first, $second, $third, $u ) = ( 1, 2, bless {}, 'Everything::Node' );
	my $result = $nb->getRef( $first, $second, $third, $u );

	is( $first,  'first',              'getRef() should modify refs in place' );
	is( $second, 'second',                 '... for all passed in node_ids'   );
	ok( $third->isa( 'Everything::Node' ), '... not mangling existing nodes'  );
	is( $u, undef,                         '... skipping undefined values'    );
	is( $result, 'first',                  '... returning first element node' );
}

sub test_get_id :Test( 5 )
{
	my $self = shift;
	my $nb   = $self->{nb};
	my $node = bless { node_id => 11 }, 'Everything::Node';

	is( $nb->getId(), undef,       'getId() should return without node id' );
	is( $nb->getId( $node ), 11,    '... returning node_id of provided node' );
	is( $nb->getId( 12 ),    12,    '... or node_id, if a number' );
	is( $nb->getId( -13 ),   -13,   '... or an integer' );
	is( $nb->getId( 'foo' ), undef, '... but undef if not an integer' );
}

sub test_has_permission :Test( 5 )
{
	my $self = shift;
	my $nb   = $self->{nb};

	$nb->set_series( getNode => 0, { code => 'return 1' } );

	local *Everything::Security::checkPermissions;

	my @cp;
	*Everything::Security::checkPermissions = sub {
		push @cp, [@_];
		return 'cp';
	};

	my $result = $nb->hasPermission( 'u', 'p', 'm' );

	is( $result, 0,
		'checkPermission() return false unless it can fetch permission node' );

	my ( $method, $args ) = $nb->next_call();
	is( join( '-', @$args ), "$nb-p-permission", '... by identifier and type' );

	$result = $nb->hasPermission( 'u', 'p', 'm' );
	is( @cp, 1, '... should check permissions with a perm node' );

	is( join( '-', @{ $cp[0] } ), '1-m',
		'... with permissions results and mode' );
	is( $result, 'cp', '... and returning results' );
}

sub test_search_node_name : Test(10) {
    my $self = shift;

    my $nb = $self->{nb};

    my $mock = Test::MockObject->new;

    my $id = [];

    my $fake_nodes = { foo => 1, bar => 2 };
    $nb->mock(
        'getId',
        sub {
            push @$id, $fake_nodes->{ $_[1] };
            return $fake_nodes->{ $_[1] };
        }
      )->set_always( 'getNode', $mock );

    $mock->set_series( 'fetchrow_hashref', 1, 2, 3 );

    $nb->{storage}->set_always( sqlSelectMany => undef );

    is( $nb->search_node_name(['']),
        undef,
        'searchNodeName() should return without workable words to find' );

    $nb->{storage}->set_always( sqlSelectMany => $mock );
    $mock->set_always( fetchfow_hashref => undef );
    $nb->{storage}->clear;
    $mock->clear;
    $nb->search_node_name( [''], [ 'foo', 'bar' ] );
    is( $id->[0], 1, '... should call getId() for first type' );
    is( $id->[1], 2,
        '... should call getId() for subsequent types (if passed)' );

    my ( $method, $args ) = $nb->{storage}->next_call;
    is ($method, 'sqlSelectMany', '...calls execute against the db cursor.');
    is ($$args[3], 'title like ? AND (type_nodetype = 1 OR type_nodetype = 2)', '... creates sql for types.');
    $nb->{storage}->clear;
    $mock->clear;

    $nb->search_node_name(['quote']);
    ( $method, $args ) = $nb->{storage}->next_call;
    is_deeply( $$args[5], [q{%quote%}],
        '... should process searchable words' );

    # reset series
    $mock->set_series( 'fetchrow_hashref', 1, 2, 3 );

    $nb->{storage}->clear;
    $mock->clear;

    my $found =
      $nb->search_node_name( ['ab', 'aBc!',  'abcd', 'a', 'ee'], [ 'foo', 'bar' ] );
    ( $method, $args ) = $nb->{storage}->next_call;
    is_deeply( $$args[5], ['%ab%aBc!%abcd%a%ee%'], '... processes all search word arguments.' );

    is( ref $found, 'ARRAY', '... should return an arrayref on success' );

    is( @$found, 3, '... should find all proper results' );
    is( join( '', @$found ), '123', '... and should return results' );
}

sub test_retrieve_links : Test(4) {
    my $self = shift;

    my $inst = $self->{ nb };
    my $mock = Test::MockObject->new;

    $inst->set_always( sqlSelectMany => $mock );
    $mock->set_series( fetchrow_hashref => { qw/key1 value1 key2 value2/ }, undef );

    my %arg_hash =  (to_node => 1, from_node => 2, linktype => 3 );
    my %hash_arg = reverse %arg_hash;

    ok( my $rv = $inst->retrieve_links( \%arg_hash ), '...retrieve_links works ok');

    my ( $method, $args ) = $inst->next_call;
    is( $method, 'sqlSelectMany', '...calls DB function.' );
    my @values = @{ $$args[5] };
    my $where = join ' AND ', map "$_ = ?", @hash_arg{ @values };
    is( $$args[3], $where, '... constructs where clause.');
    is_deeply( $rv, [ { key1 => 'value1', key2 => 'value2' } ], '...returns an array ref of hash refs.');
}

sub test_retrieve_nodes_linked : Test( 9 ) {

    my $self = shift;
    my $inst = $self->{ nb };
    $inst->set_always( retrieve_links => [ {from_node => 'from', to_node => 'to' } ] );

    my $mock = Test::MockObject->new;
    $mock->set_always( get_node_id => 999 );
    $inst->set_always( getNode => $mock );
    my $rv = $inst->retrieve_nodes_linked( 'to', $mock );
    is_deeply( $rv, [ $mock ], '...returns an array of nodes.');
    my( $method, $args ) = $inst->next_call;
    is( $method, 'retrieve_links', '...calls retrieve links.');
    is_deeply( $$args[1], { to_node => 999 }, '...with to_node arg_hash.');
    ( $method, $args ) = $inst->next_call;
    is( $method, 'getNode', '...retrieves nodes.');
    is( $$args[1], 'from', '...using the from_node value.');

    $inst->retrieve_nodes_linked( 'from', $mock );
    ( $method, $args ) = $inst->next_call;
    is( $method, 'retrieve_links', '...calls retrieve links.');
    is_deeply( $$args[1], { from_node => 999 }, '...with from_node arg_hash.');
    ( $method, $args ) = $inst->next_call;
    is( $method, 'getNode', '...retrieves nodes.');
    is( $$args[1], 'to', '...using the to_node value.');

}

sub test_total_links : Test(2) {
    my $self = shift;

    my $inst = $self->{ nb };
    my $mock = Test::MockObject->new;

    $inst->set_always( sqlSelect => 2 );

    my %arg_hash =  (to_node => 1, from_node => 2, linktype => 3 );
    my %hash_arg = reverse %arg_hash;

    $inst->total_links( \%arg_hash );

    my ( $method, $args ) = $inst->next_call;
    is( $method, 'sqlSelect', '...calls DB function.' );
    my @values = @{ $$args[5] };
    my $where = join ' AND ', map "$_ = ?", @hash_arg{ @values };
    is( $$args[3], $where, '... constructs where clause.');

}

sub test_delete_links : Test( 2 ) {
    my $self = shift;

    my $inst = $self->{ nb };
    my $mock = Test::MockObject->new;

    $inst->set_always( sqlDelete => 2 );

    $mock->set_series( get_node_id => 1, 2 );

    ## setting mocks here and manipulating arg_hash to know that we
    ## can pass nodes rather than just node_ids

    my %arg_hash =  (to_node => $mock, from_node => $mock, linktype => 3 );
    $inst->delete_links( \%arg_hash );
    $arg_hash{to_node} = 2;
    $arg_hash{from_node} = 1;

    my %hash_arg = reverse %arg_hash;

    my ( $method, $args ) = $inst->next_call;
    is( $method, 'sqlDelete', '...calls DB function.' );
    my @values = @{ $$args[3] };
    my $where = join ' AND ', map "$_ = ?", @hash_arg{ @values };
    is( $$args[2], $where, '... constructs where clause.');

}

1;
