package Everything::Node::Test::node;

use strict;
use warnings;

use base 'Test::Class';

use DBI;
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;

use File::Copy;
use File::Temp;
use File::Spec::Functions;
use Scalar::Util qw( reftype blessed );

use Everything::NodeBase;
use Everything::DB::sqlite;

BEGIN {

    sub node_class {
        my $self = shift;
        my $name = blessed($self) || $self;
        $name =~ s/Test:://;
        return $name;
    }

    my $module = __PACKAGE__->node_class;
    my ($file) = $module =~ s/::/\//g;
    require "$module.pm";

}


sub startup : Test( startup => 3 ) {
    my $self = shift;
    $self->{errors} = [];

    $self->make_base_test_db();

    my $mock = Test::MockObject->new();
    $mock->fake_module(
        'Everything',
        logErrors => sub {
            push @{ $self->{errors} }, [@_];
        }
    );

    *Everything::Node::node::DB = \$mock;

    my $module = $self->node_class();
    my %import;

    my $mockimport = sub {
	return unless (caller)[0] eq $module; # don't report imports
                                              # from other packages
        $import{ +shift } = { map { $_ => 1 } @_[ 1 .. $#_ ] };
    };

    for my $mod ( $self->setup_imports ) {
        $mock->fake_module( $mod, import => $mockimport );
    }

    $self->{imports} = \%import;

    use_ok( $module );

    # now test that C<new()> works
    can_ok( $module, 'new' );
    isa_ok( $module->new(), $module );
}


sub setup_imports {

    my $self = shift;
    ();
}

sub make_base_test_db
{
	my $self      = shift;

	my $blank_db  = catfile(qw( t ebase.db ));
	require 't/lib/build_test_db.pm' unless -e $blank_db; ## no critic

	my $tempdir   = File::Temp::tempdir( DIR => 't', CLEANUP => 1);
	my $module    = $self->node_class();
	my $module_db = catfile( $tempdir, $module . '_base.db' );

	copy( $blank_db, $module_db )
		or die "No test database for $module $!";

	$self->{base_test_db} = $module_db;
	$self->{tempdir}      = $tempdir;
	$self->populate_base_database( $module_db );
}

# override if necessary
sub populate_base_database {}

sub test_extends :Test( 1 )
{
	my $self   = shift;
	my $module = $self->node_class();

	ok( $module->isa( 'Everything::Node' ),
		"$module should extend Everything::Node" );
}

sub test_dbtables :Test( 2 )
{
	my $self   = shift;
	my $module = $self->node_class();
	can_ok( $module, 'dbtables' );
	my @tables = $module->dbtables();
	is_deeply( \@tables, [ 'node' ], 'dbtables() should return node tables' );
}

sub make_fixture :Test(setup)
{
	my $self      = shift;
	$self->make_test_db();

	my $nb        = Everything::NodeBase->new( $self->{test_db}, 1, 'sqlite' );
	my $db        = Test::MockObject::Extends->new( $nb );
	$self->reset_mock_node();

	*Everything::Node::node::DB = \$db;
	$self->{mock_db}            = $db;
	$self->{node}{DB}           = $db;
	$self->{node}->set_nodebase( $db );
	$self->{errors}             = [];
}

sub make_test_db
{
	my $self         = shift;
	my $method_name  = $self->current_method();
	my $base_db      = $self->{base_test_db};
	my $tempdir      = $self->{tempdir};
	my $test_db      = catfile( $tempdir, $method_name . '.db' );

	copy( $base_db, $test_db )
		or die "Cannot create test db for $method_name: $!\n";

	$self->{test_db}  = $test_db;
	$self->{test_dbh} = DBI->connect( "dbi:SQLite:dbname=$test_db", '', '' );
}

sub reset_mock_node
{
	my $self      = shift;
	my $node      = $self->node_class()->new();
	$self->{node} = Test::MockObject::Extends->new( $node );
}

sub test_destruct :Test( 1 )
{
	my $self = shift;
	ok( $self->{node}->destruct(), 'destruct() should return true' );
}

sub test_insert_access :Test( 3 )
{
	my $self = shift;
	my $mock = $self->{mock};
	my $node = $self->{node};

	$node->set_false( 'hasAccess' );
	is( $node->insert( $mock ), 0,
		'insert() should return 0 if user lacks access' );

	my ($method, $args) = $node->next_call();
	is( $args->[1], $mock, 'checking for correct user' );
	is( $args->[2], 'c',   '... and create access' );
}

sub test_insert_restrictions :Test( 2 )
{
	my $self = shift;
	my $mock = $self->{mock};
	my $node = $self->{node};

	$node->set_true( 'hasAccess' )
		 ->set_series( restrictTitle => 0, 1 );
	is( $node->insert( $mock ), 0,
		'insert() should return 0 if node title is restricted' );

	$node->{node_id} = 5;
	is( $node->insert( $mock ), 5,
		'insert() should return node_id if it is positive already' );
}

sub test_insert_restrict_dupes :Test( 4 )
{
	my $self               = shift;
	my $node               = $self->{node};
	my $db                 = $self->{mock_db};

	$node->{node_id}       = 0;
	$node->{type}          = $node;
	$node->{restrictdupes} = 1;
	$node->{type_nodetype} = 2;
	$node->set_always( get_nodebase => $db );
	$node->set_always( type => $node );
	$node->set_true(qw( -hasAccess -restrictTitle -getId -cache));

	$db->set_series( sqlSelect => 1, 0 )
	   ->set_always( -getFields => 'none' )
	   ->set_always( -now => '' )
	   ->set_series( -getNode => undef, { DB => $db } )
	   ->set_true( 'sqlInsert' )
	   ->set_always( -lastValue => 100 )
	   ->set_always( -nodetype => $node )
	   ->set_always( -get_storage => $db )
           ->set_always( retrieve_nodetype_tables => [] )
           ->set_list ( fetch_all_nodetype_names => 'node', 'nodetype' )
	   ->set_always( -nodetype_hierarchy_by_id => [ {restrictdupes => -1 }, {restrictdupes => 1 } ] );
	## mock blessed because our node is T::MO::E

	is( $node->insert( '' ), 0,
		'insert() should return 0 if dupes are restricted and exist' );

	my ($method, $args) = $db->next_call;

	is ($method, 'sqlSelect', '...checks to see whether there are dupes.');

	is_deeply(
		  $args,
		  [
		   $db,    'count(*)',
		   'node', 'title = ? AND type_nodetype = ?',
		   '', [ $node->{title}, 2 ]
		  ],
		  '...with the right title and id arguments.'
		 );

	$node->{restrictdupes} = 0;
	$node->{nodebase} = $db;

	is( $node->insert( '' ), 100,
		'... or should return the inserted node_id otherwise' );
}

sub test_insert :Test( 3 )
{
	my $self               = shift;
	my $node               = $self->{node};
	my $db                 = $self->{mock_db};
	my $type               = $db->getType( 'nodetype' );

	local *Everything::NodeBase::blessed;
	*Everything::NodeBase::blessed = sub { $self->node_class };

	$node->{node_id}       = 0;
	$node->set_always ( type => $node );
	$node->set_always ( getTableArray => [] );
	$node->{type_nodetype} = 1;

	$node->set_true(qw( -hasAccess -restrictTitle -getId ));
	$node->{foo}  = 11;

	delete $node->{restrictdupes};

	my $time = time();
	$db->set_always( -now => $time );
	$db->set_true( 'rebuildNodetypeModules' );

	$node->set_true( 'cache' );
	$node->{node_id} = 0;

	my $result = $node->insert( 'user' );

	ok( defined $result, 'insert() should return a node_id if no dupes exist' );
	is( $result, 4, '... with the proper sequence' );

	my $dbh = $db->{storage}->getDatabaseHandle();
	my $sth = $dbh->prepare(
		'SELECT createtime, author_user, hits FROM node WHERE node_id=?'
	);
	$sth->execute( $result );
	my $node_ref = $sth->fetchrow_hashref();
	is_deeply( $node_ref,
		{
			createtime  => $time,
			author_user => 'user',
			hits        => 0,
		},
		'... with the proper fields'
	);
	$sth->finish();
}

sub test_update_access :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->set_false( 'hasAccess' );
	is( $node->update( 'user' ), 0,
		'update() should return 0 if user lacks write access' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'hasAccess',                '... so should check access' );
	is( join( '-', @$args ), "$node-user-w", '... write access for user'  );
}

sub test_update :Test( 10 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{type} = $node;
	$node->{boom} = 88;
	$node->{foom} = 99;
	$db->{cache}  = $db;
	$db->{storage} = $db;

	$node->set_true( -hasAccess )
		 ->set_always( -type => $node )
		 ->set_true( 'cache' );

	$db->set_true(qw( incrementGlobalVersion sqlUpdate now sqlSelect update_or_insert))
	   ->set_series( getFields => 'boom', 'foom' )
           ->set_always( -retrieve_nodetype_tables  => [ 'table', 'table2' ] );

	$node->update( 'user' );
	is( $db->next_call(), 'incrementGlobalVersion',
		'... incrementing global version in cache' );
	is( $node->next_call(), 'cache', '... caching node' );

	my $method = $db->next_call();
	is( $db->next_call(), 'sqlSelect',
		'... updating modified field without flag' );
	is( $method, 'now', '... with current time' );

	( $method, my $args ) = $db->next_call();
	is( $method, 'getFields', '... fetching the fields' );
	is( $args->[1], 'table',  '... of each table' );

	( $method, $args ) = $db->next_call();
	is( "$method $$args[1]{table}", 'update_or_insert table', '... updating each table' );

	is( keys %{ $args->[1]->{data} }, 1,
		'... with only allowed fields' );
	is( $args->[1]->{where},           'table_id = ?',    '... for table' );
	is_deeply( $args->[1]->{bound}, [ $node->{node_id} ], '... with node id' );
}

sub test_is_group :Test( 1 )
{
	ok( ! shift->{node}->isGroup(), 'isGroup() should return false' );
}

sub test_get_field_datatype :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->{a_field} = 111;
	is( $node->getFieldDatatype( 'a_field' ), 'noderef',
		'getFieldDatatype() should mark node references as "noderef"' );

	$node->{b_field} = 'foo';
	$node->{cfield}  = 112;
	is( $node->getFieldDatatype( 'b_field' ), 'literal_value',
		'... but references without ids are literal' );
	is( $node->getFieldDatatype( 'bfield' ), 'literal_value',
		'... and so are fields without underscores' );
}

sub test_has_vars :Test( 1 )
{
	ok( !shift->{node}->hasVars(), 'hasVars() should return false' );
}

sub test_clone :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};
	is( $self->node_class->clone(), undef,
		'clone() should return without a node to clone' );
	is( $node->clone( 'foo' ), undef, '... or a node hash' );

	# now set a field not to overwrite
	$node->{node_id} = 1;

	my $from_hash =
	{
		test          => 'test',
		node_id       => 2,
		type          => "don't copy",
		title         => "don't copy",
		createtime    => "don't copy",
		type_nodetype => "don't copy",
	};

	ok( $node->clone( $from_hash ),	
		'clone() should return true with proper args' );

	is_deeply( $node, { %$node, test => 'test', node_id => 1 },
		'clone() should copy only necessary fields' );
}

sub test_restrict_title :Test( 6 )
{
	my $self = shift;
	my $node = $self->{node};
	delete $node->{title};

	ok( ! $node->restrictTitle(),
		'restrictTitle() called with no title field should return false' );

	$node->{title} = '[foo]';
	ok( ! $node->restrictTitle(),
		'... or if title contains a square bracket'
	);

	$node->{title} = 'f>o<o';
	ok( ! $node->restrictTitle(), '... or an angle bracket' );

	$node->{title} = 'o|o';
	ok( ! $node->restrictTitle(), '... or a pipe' );
	like( $self->{errors}[0][0], qr/name.+invalid characters/,
		'... and should log error' );

	$node->{title} = 'a good name zz9';
	ok( $node->restrictTitle(), '... but should return true otherwise' );
}

sub test_get_node_keep_keys :Test( 10 )
{
	my $self = shift;
	my $node = $self->{node};

	my $result = $node->getNodeKeepKeys();
	is( reftype( $result ), 'HASH',
		'getNodeKeepKeys() should return a hash reference' );

	for my $class (qw( author group other guest ))
	{
		ok( exists $result->{"${class}access"},
			"... and should contain $class access" );
		ok( exists $result->{"dynamic${class}_permission"},
			"... and $class permission keys" );
	}
	ok( exists $result->{loc_location}, '... and location key' );
}

sub test_get_node_keys :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};

	my %keys = map { $_ => 1 }
		qw( createtime modified hits reputation
		lockedby_user locktime lastupdate foo_id bar );

	$node->set_always( getNodeDatabaseHash => \%keys );

	my $result = $node->getNodeKeys();

	is( $node->next_call(), 'getNodeDatabaseHash',
		'getNodeKeys() should fetch node database keys' );
	is( keys %$result, 9,
		'... and should return them unchanged, if not exporting' );

	$result = $node->getNodeKeys( 1 );
	ok( ! exists $result->{foo_id}, '... returning no uid keys if exporting' );
	is( join( ' ', keys %$result ), 'bar',
		'... and removing non-export keys as well' );
}

sub test_get_identifying_fields :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};
	is( $node->getIdentifyingFields(), undef,
		'getIdentifyingFields() should return undef' );
}

sub test_update_from_import :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->set_true( 'update' )
		 ->set_series( -getNodeKeys => { foo => 1, bar => 2, baz => 3 } )
		 ->set_series( -getNodeKeepKeys => { bar => 1 } );

	$node->updateFromImport( { foo => 1, bar => 2, baz => 3 }, 'user' );

	is( $node->{foo} + $node->{baz}, 4,
		'updateFromImport() should merge node keys' );
	ok( ! exists $node->{bar}, '... but not those it should keep' );

	my ( $method, $args ) = $node->next_call();
	is( "$method @$args", "update $node user nomodify",
		'... and should update node' );
	is( $node->{modified}, 0, '... setting "modified" to 0' );
}

sub test_conflicts_with :Test( 4 )
{
	my $self          = shift;
	my $node          = $self->{node};
	$node->{modified} = '';

	ok( ! $node->conflictsWith(),
		'conflictsWith() should return false with no digit in "modified"' );

	$node->{modified} = 1;

	my $keep     = { foo => 1 };
	my $conflict = { foo => 1, bar => 2 };

	$node->set_series( getNodeKeys => $node, $node )
		->set_series( getNodeKeepKeys => $keep, {} );

	$node->{foo} = 1;
	$node->{bar} = 3;

	my $result = $node->conflictsWith( $conflict );
	my ( $method, $args ) = $node->next_call();

	ok( $result, '... but should return true if any node field conflicts' );

	$node->{bar} = 2;
	ok( ! $node->conflictsWith( $conflict ), '... false otherwise' );

	$node->{foo} = 2;
	ok( ! $node->conflictsWith( $conflict ),
		'... and should ignore keepable keys' );
}

sub test_verify_field_update :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};
	my @fields;

	for my $field (qw(
		createtime node_id type_nodetype hits loc_location reputation
		lockedby_user locktime authoraccess groupaccess otheraccess guestaccess
		dynamicauthor_permission dynamicgroup_permission
		dynamicother_permission dynamicguest_permission
	))
	{
		push @fields, $field unless $node->verifyFieldUpdate( $field );
	}

	is( @fields, 16,
		'verifyFieldUpdate() should return false for unmodifiable fields' );
	ok( ! $node->verifyFieldUpdate( 'foo_id' ), '... and for _id fields' );
	ok( $node->verifyFieldUpdate( 'agoodkey' ),
		'... but true for everything else' );
}

sub test_get_revision :Test( 9 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{node_id}          = 11;
	$db->{workspace}{node_id} =  7;
	$db->set_series( sqlSelect => 0, 'xml' )
		->set_series( sqlSelectHashref => 0, { xml => 'myxml' } );

	is( $node->getRevision( '' ), 0,
		'getRevision() should return 0 if revision is not numeric' );

	$node->set_always( xml2node => [] );
	my $result = $node->getRevision( 0 );

	my ( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelectHashref', '... should fetch revision from database' );

	is( $args->[5][2], 7, '... using workspace id, if it exists' );
	is( $result, 0, '... should return 0 if fetch fails' );

	delete $db->{workspace};
	my @fields = qw( node_id createtime reputation );
	@$node{@fields} = (8) x 3;

	{
		local *Everything::Node::node::xml2node;
		*Everything::Node::node::xml2node = sub { $node->xml2node( @_ ) };
		$node->set_always( xml2node => [ { x2n => 1 } ] );
		$result = $node->getRevision( 1 );
	}

	( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelectHashref', '... should select the node revision' );
	is( join( '-', @$args[ 1 .. 3 ], @{ $args->[5] } ),
		'*-revision-node_id = ? and revision_id = ? and inside_workspace = ?-8-1-0',
		'... using 0 with no workspace' );

	( $method, $args ) = $node->next_call();
	is( join( ' ', @$args ), "$node myxml noupdate",
		'... should xml-ify revision' );

	is( $result->{x2n}, 1, '... returning the revised node' );
	is( "@$node{@fields}", "@$result{@fields}",
		'... and should copy node_id, createtime, and reputation fields' );
}

sub test_undo_access :Test()
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_false( 'hasAccess' );

	is( $node->undo( 'uS' ), 0,
		'undo() should return 0 if user lacks write access' );
}

sub test_undo :Test( 27 )
{
	local *Everything::Node::node::ISA;
	*Everything::Node::node::ISA = [];

	my $self         = shift;
	my $node         = $self->{node};
	my $db           = $self->{mock_db};
	$node->{node_id} = 13;
	$db->{workspace} = $node;
	$db->{cache}     = $node;

	$node->set_true(qw( -hasAccess update toXML ));
	$db->set_series( sqlSelectMany => ($db) x 6 )
	   ->set_series( -fetchrow     => ( 1, 5, 0 ) x 6 )
	   ->set_true( 'sqlUpdate' );

	is( $node->undo( $node, '' ), 0,
		'undo() should return 0 unless workspace contains this node' );

	$node->set_true( 'setVars' );

	$node->fake_module('Everything::XML::Node', new => sub { $node });
	$node->set_true('toXML');

	my $position = \$db->{workspace}{nodes}{13};
	$$position   = 4;
	my $result   = $node->undo( 'user', 1, 1 );

	my ( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelectMany', '... selecting many rows' );
	is(
		join( '-', @$args[ 1 .. 3 ] ),
		'revision_id-revision-node_id = ? and inside_workspace = ?',
		'... should fetch revision_ids for node in workspace'
	);
	is_deeply( $args->[5], [ 13, 13 ], '... for node and revision id' );

	is( $result, 1,
		'... returning true if testing/redoing and revision exists for pos' );
	is( $node->undo( 'user', 0, 1 ), 1,
		'... or if undoing and position is one or more' );

	$$position = 0;
	is( $node->undo( 'user', 0, 0 ), 0, '... otherwise false' );

	$$position = 1;
	is( $node->undo( 'user', 1, 0 ), 0,
		'... returning false if redoing and revision does not exist for pos' );

	$$position = 0;
	is( $node->undo( 'user', 0, 0 ), 0,
		'... or if undoing and position is not one or more' );

	$$position = 1;

	$result = $node->undo( 'user', 0, 0 );
	is( $db->{workspace}{nodes}{13}, 0,
		'... should update position in workspace for node' );

	( $method, $args ) = $node->next_call();

	is( $method, 'setVars', '... should set variables' );
	is( $args->[1], $db->{workspace}{nodes}, '... in workspace' );
	( $method, $args ) = $node->next_call();
	is( $method, 'update',  '... updating workspace' );
	is( $args->[1], 'user', '... for user' );
	ok( $result,            '... and returning true' );

	delete $db->{workspace};

	my $rev = {};
	$db->set_series( sqlSelectHashref => 0, ($rev) x 5 )
	   ->clear();

	$result = $node->undo( 'user', 0, 0 );
	( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelectHashref', '... fetching data' );
	like( join( ' ', @$args ), qr/\* revision .+_id=13.+BY rev.+DESC/,
		'... if not in workspace, should fetch revision for node' );
	ok( !$result, '... should return false unless found' );

	$rev->{revision_id} = 1;
	ok( ! $node->undo( 'user', 1 ),
		'... or false if redoing and revision_id is positive' );

	$rev->{revision_id} = 0;
	ok( ! $node->undo( 'user', 1 ), '... or zero' );

	$rev->{revision_id} = -1;
	ok( ! $node->undo( 'user', 0 ),
		'... or false if undoing and revision_id is negative' );

	$rev->{revision_id} = 77;
	ok( $node->undo( 'user', 0, 1 ), '... or true if testing' );

	$node->clear();
	$db->clear();
	{
		local *Everything::Node::node::xml2node;
		*Everything::Node::node::xml2node = sub { [] };
		$result = $node->undo( 'user' );
	}
	is( $node->next_call(), 'toXML', '... should XMLify node' );
	is( $rev->{revision_id}, -77, '... should invert revision' );

	( $method, $args ) = $db->next_call( 2 );
	is( $method, 'sqlUpdate', '... should update database' );
	is( join( '-', @$args[ 1, 3 ] ),
		'revision-node_id = ? and inside_workspace = ? and revision_id = ?',
		'... with new revision' );
	is_deeply( $args->[4], [ 13, 0, 77 ], '... for node, workspace, and revision' );
}

sub test_can_workspace :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};
	my $ws   = $node->{type} = { canworkspace => 1 };

	ok( $node->canWorkspace(),
		'canWorkspace() should return true if nodetype can workspace' );

	$ws->{canworkspace} = 0;
	ok( ! $node->canWorkspace(), '... and false if it cannot' );

	$ws->{canworkspace}         = -1;
	$ws->{derived_canworkspace} = 0;
	ok( ! $node->canWorkspace(),
		'... or false if inheriting and parent cannot' );
	$ws->{derived_canworkspace} = 1;
	ok( $node->canWorkspace(),
		'... and true if inheriting and parent can workspace' );
}

sub test_get_workspaced :Test( 6 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_series( -canWorkspace => 0, 1, 1, 1 )
		 ->set_series( getRevision   => 'rev', 0 );

	ok( ! $node->getWorkspaced(),
		'getWorkspaced() should return unless node can be workspaced' );
	$node->{node_id}   = 77;
	$db->{workspace} =
	{
		nodes =>
		{
			77 => 44,
			88 => 11,
		},
		cached_nodes => { '77_44' => 88, },
	};
	is( $node->getWorkspaced(), 88,
		'... should return cached node version if it exists' );
	$node->{node_id} = 88;

	my $result = $node->getWorkspaced();
	my ( $method, $args ) = $node->next_call();
	is( "$method $args->[1]", 'getRevision 11', '... should fetch revision' );

	is( $result, 'rev', '... returning it if it exists' );
	is( $db->{workspace}{cached_nodes}{'88_11'},
		'rev', '... and should cache it' );

	$node->{node_id} = 4;
	ok( !$node->getWorkspaced(), '... or false otherwise' );
}

sub test_nuke_access :Test( 4 )
{
	my $self    = shift;
	my $node    = $self->{node};
	my $db      = $self->{mock_db};
	$node->set_false( 'hasAccess' );
	$db->set_true( 'getRef' );

	my $result = $node->nuke( 'user' );

	my ( $method, $args ) = $db->next_call();
	is( "$method $args->[1]",
		'getRef user', 'nuke() should fetch user node unless it is -1'   );
	ok( !$result,      '... returning false if user lacks delete access' );

	( $method, $args ) = $node->next_call();
	is( $method, 'hasAccess', '... and should check for access' );
	is( join( '-', @$args ), "$node-user-d", '... delete access for user' );
}

sub test_nuke :Test( 26 )
{
	my $self         = shift;
	my $node         = $self->{node};
	my $db           = $self->{mock_db};
	$node->{type}    = $node;
	$db->{cache}     = $db;
	$node->{node_id} = 89;

	$node->set_true( 'hasAccess' )
		->set_series( -isa => 0, 'table1', 'table2' )
		->set_series( -get_grouptable => 'table1', 'table2')
	    ->set_always( getTableArray => [ 'deltable' ] )
		->set_always( -getId => 'id' )
		->set_always( -type => $node );
	$db->set_true(qw( getRef finish removeNode incrementGlobalVersion ))
	   ->set_always( getNode => $db )
	   ->set_series( sqlSelectMany => 0, $db )
	   ->set_series( fetchrow => 'group' )
	   ->set_series( sqlDelete => (1) x 4 );

	my $result;
	{
		my $gat;
		$db->mock( getAllTypes => sub { $gat++; return ($node) x 3 } );
		$result = $node->nuke( -1 );
		ok( $gat, '... should get all nodetypes' );
		$db->set_false( 'getAllTypes' );
	}

	isnt( $node->next_call(), 'getRef',
		'... and should not get user node if it is -1' );
	my ( $method, $args ) = $db->next_call();
	is( $method, 'sqlDelete', '... should delete links' );
	is( join( '-', @$args[ 1, 2 ] ), 'links-to_node=? OR from_node=?',
		'... should delete from or to links from links table' );
	is_deeply( $args->[3], [ 'id', 'id' ], '... with bound node id' );

	( $method, $args ) = $db->next_call();
	is( $method, 'sqlDelete', '... and deleting node revisions' );
	is( join( '-', @$args[ 1, 2 ] ), 'revision-node_id = ?',
		'... by id from revision' );
	is_deeply( $args->[3], [89], '... with node_id' );

#	is( $node->next_call(), 'isGroupType',
#		'... should check each type is a group node' );

	( $method, $args ) = $db->next_call(2);
	is( $method, 'sqlSelectMany', '... should check for node' );
	is( join( '-', @$args[ 1 .. 3 ] ), 'table1_id-table1-node_id = ?',
		'... in group table' );
	is_deeply( $args->[5], [89], '... by node_id' );

	is( $db->next_call(3), 'fetchrow',
		'... if it exists, should fetch all containing groups' );
	( $method, $args ) = $db->next_call( 2 );
	is( $method, 'sqlDelete', '... and should delete' );
	is( join( '-', @$args[ 1 .. 2 ] ), 'table2-node_id = ?',
		'... from table on node_id' );
	is_deeply( $args->[3], [89], '... for node' );

	( $method, $args ) = $db->next_call();
	is( $method, 'getNode', '... fetching node' );
	is( join( '-', @$args ), "$db-group", '... for containing group' );

	is( $db->next_call(), 'incrementGlobalVersion', '... forcing a reload' );

	( $method, $args ) = $node->next_call( );
	is( "$method @$args", "getTableArray $node 1",
		'... should fetch all tables for node' );

	( $method, $args ) = $db->next_call();
	is( $method, 'sqlDelete', '... deleting node' );
	is( join( '-', @$args[ 1, 2 ] ), 'deltable-deltable_id = ?',
		'... from tables' );
	is_deeply( $args->[3], ['id'], '... by node_id' );
	is( $db->next_call(), 'incrementGlobalVersion',
		'... should mark node as updated in cache' );

	( $method, $args ) = $db->next_call();
	is( "$method @$args", "removeNode $db $node", '... uncaching it' );
	is( $node->{node_id}, 0, '... should reset node_id' );
	ok( $result, '... and return true' );
}

1;
