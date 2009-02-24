package Everything::Test::XML;

use strict;
use Test::More;
use Test::MockObject;
use File::Temp qw/tempfile/;
use SUPER;

use base 'Everything::Test::Abstract';

BEGIN { Test::MockObject->fake_module( 'XML::DOM' ); }

sub startup : Test(startup => +1) {
    my $self = shift;
    my $mock = Test::MockObject->new;

    $self->{le} = [];
    $mock->fake_module( 'Everything',
        logErrors => sub { push @{ $self->{le} }, [@_] } );

    # test imports
    my %import;

    my $mockimport = sub {
        $import{ +shift } = { map { $_ => 1 } @_[ 1 .. $#_ ] };
    };

    for my $mod ('Everything') {
        $mock->fake_module( $mod, import => $mockimport );
    }
    $self->SUPER;

    $self->{mock} = $mock;

    is_deeply(
        $import{Everything},
        { 'getNode' => 1, getType => 1, selectNodeWhere => 1, getRef => 1 },
        '...imports getNode from Everything'
    );
}

## currently not used by Everything at all. Oh, well...
sub test_readtag : Test(5) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'readTag' ) || return;

    local *readTag;
    *readTag = \&{ $self->{class} . '::readTag' };

    no strict 'refs';
    local *{ $package . '::makeXmlSafe' };
    *{ $package . '::makeXmlSafe' } = sub {
        return $_[0];
    };
    use strict 'refs';

    is( readTag( 'goodtag', '<field name="goodtag">blah blah</field>' ),
        'blah blah', '...grabs content if name attributes match' );
    is(
        readTag(
            'goodtag', '<field other="thingo" name="goodtag">blah blah</field>'
        ),
        '',
        '...but not if the name attribute is not the first tag.'
    );
    is(
        readTag(
            'goodtag', '<field name="goodtag">blah blah</field>',
            'amazingfield'
        ),
        '',
        '...nor if the field we want is not there..'
    );
    is(
        readTag(
            'goodtag', '<amazingfield name="goodtag">blah blah</amazingfield>',
            'amazingfield'
        ),
        'blah blah',
        '...unless we have specified it.'
    );
}

sub test_initXMLParser : Test(2) {
    my $self    = shift;
    my $package = $self->{class};

    can_ok( $package, 'initXMLParser' );
    my $unfixed = Everything::XML::_unfixed();
    $unfixed->{foo} = 'bar';
    Everything::XML::initXMLParser();
    is( keys( %{ Everything::XML::_unfixed() } ),
        0, 'initXMLParser() should clear unfixed keys' );
}

sub test_fix_nodes : Test(7) {
    my $self    = shift;
    my $package = $self->{class};
    my $mock    = $self->{mock};
    $self->{le} = [];
    $mock->clear;

    can_ok( $package, 'fixNodes' );

    my ( @gn, @gnret );

    no strict 'refs';
    local *fixNodes;
    *fixNodes = \&{ $self->{class} . '::fixNodes' };
    local *unfixed;
    *_unfixed = \&{ $self->{class} . '::_unfixed' };

    my @applyXMLFix_returns =  ( 1, 0, 1 );
    my @applyXMLFix_args = ();
    my @calls = ();
    local *{ $self->{class} . '::applyXMLFix'};
    *{ $self->{class} . '::applyXMLFix' } = sub { push @calls, 'applyXMLFix'; push @applyXMLFix_args, [@_]; shift @applyXMLFix_returns };

    local *{ $self->{class} . '::commitXMLFixes'};
    *{ $self->{class} . '::commitXMLFixes' } = sub { push @calls, 'commitXMLFixes'; 1 };

    use strict 'refs';

    local *Everything::XML::getNode;
    *Everything::XML::getNode = sub {
        push @gn, [@_];
        return shift @gnret;
    };

    my $unfixed = _unfixed();
    $unfixed->{foo} = 'bar';

    fixNodes(0);
    is( @{ $self->{le} },
        0, 'fixNodes() should log nothing unless error flag is set' );

    fixNodes(1);
    is( @{ $self->{le} }, 1, '... but should log with error flag' );

    @gnret = ($mock) x 4;

    $mock->clear();
    $unfixed->{foo} = [ 1, 2 ];

    fixNodes('printflag');
    is( $calls[0], 'applyXMLFix', '... calling applyXMLFix() for all unfixed' );
    is( join( '-', @{ $applyXMLFix_args[0] }),
        "$mock-1-printflag", '... with fix and print error' );
    is_deeply( $unfixed, { foo => [1] }, '... saving only unfixed nodes' );

    $mock->clear();

    $unfixed = { bar => [] };
    fixNodes('printflag');
    is( $calls[-1], 'commitXMLFixes', '... committing fixes' );

}

## Here we assume that getNode returns something sane and xmlTag some
## how manage to work out fixes and xmlFinal actually inserts a node
## into the db.  The plan is:
##
## Extract 'NODES' from xml doc
## extract child nodes
##
## getNode creates a new node object.
##
## then we get child 'nodes', i.e. node attributes. If they're not of
## type text, we assume that they're node refs and sdnd them to xmlTag
## to get 'fixed'.  If they can't be fixed, push them onto %UNFIXED

sub test_xml2node : Test(3) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'xml2node' ) || return "Can't xml2node";

    Everything::XML::initXMLParser();
    local *xml2node;
    *xml2node = \&{ $self->{class} . '::xml2node' };
    use strict 'refs';

    my $mock = $self->{mock};

    $mock->clear;
    $mock->fake_module('XML::DOM::Parser');
    $mock->fake_new('XML::DOM::Parser');
    $mock->set_always( '-parse', $mock );
    $mock->set_series(
        '-getAttribute',
        'node 1 title',
        'node 1 type',
        1,
        'node 2 title',
        'node 2 type',
        1,
        'node 3 title',
        'node 3 type',
        1
    );
    $mock->set_list( -getElementsByTagName => $mock, $mock, $mock );
    $mock->set_series( -getChildNodes => $mock, $mock );
    $mock->set_series( -getNodeType => 0, 1 );

    my (@gn);
    no strict 'refs';
    local *{ $package . '::xmlTag' };
    *{ $package . '::xmlTag' } = sub {
        return [qw/onefix twofix threefix /];
    };

    local *{ $package . '::getNode' };
    *{ $package . '::getNode' } = sub {
        push @gn, [@_];
        return $mock;
    };

    my @xmlfinal_return = ( 1, 2, 3, 4 );
    local *{ $package . '::xmlFinal' };
    *{ $package . '::xmlFinal' } = sub {
        return shift @xmlfinal_return;
    };
    use strict 'refs';

    local *XML::DOM::TEXT_NODE = sub { 0 };
    my $result = xml2node('some xml');
    my ( $method, $args ) = $mock->next_call;

    is_deeply( $result, [ 1, 2, 3 ], '...returns an array ref of node ids' );

    is_deeply(
        Everything::XML::_unfixed(),
        { 2 => [qw/onefix twofix threefix /] },
        '... sets the unfixed hash for nodes that need fixes only.'
    );
}

sub test_xmlfile2node : Test(2) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'xmlfile2node' ) || return "Can't xmlfile2node";

    my ( $fh, $filename ) = tempfile( UNLINK => 1 );

    print $fh 'some nonsense';
    no strict 'refs';
    local *{ $package . '::xml2node' };
    *{ $package . '::xml2node' } = sub { $_[0] };
    use strict 'refs';
    $fh->close;

    local *xmlfile2node;
    *xmlfile2node = \&{ $self->{class} . '::xmlfile2node' };

    is(
        xmlfile2node($filename),
        'some nonsense',
        '..picks up file input and passes it to xml2node.'
    );
}

### parseBasicTag plan:
#
# arguments: $TAG, which is a XML::DOM::Element object here $mock
#            $fixBy a string which is a nodetype name
#
# if $TAG attribute 'type' is 'literal_value' returns a hashfef of
# {$name => $contents}
#
# if $TAG attribute 'type' is 'noderef' then creates a select hash and
# attempts to set the hash as { attr_name => node_ID}. If a node can't
# be retrieved then sets {attr_name => -1}
#
# if $TAG attribute 'type' is neither of the above, then calls logError.

sub test_parse_basic_tag : Test(6) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'parseBasicTag' ) || return;

    local *parseBasicTag = \&{ $self->{class} . '::parseBasicTag' };

    no strict 'refs';
    local *{ $package . '::unMakeXmlSafe' };
    *{ $package . '::unMakeXmlSafe' } = sub {
        return $_[0];
    };
    use strict 'refs';
    my $mock = $self->{mock};
    $mock->clear;
    $mock->set_always( getFirstChild => $mock )
      ->set_always( toString         => 'some random content' )
      ->set_always( getAttributes    => $mock )
      ->set_series( getValue => 'literal_value', 'an attribute title' );
    $mock->{type} = $mock;
    $mock->{name} = $mock;

    my $result = parseBasicTag( $mock, 'fixby ref' );
    is_deeply(
        $result,
        {
            name                 => 'an attribute title',
            'an attribute title' => 'some random content'
        },
        '...returns a hash in form { name => title, title => content'
    );

    ## set up node refs tests
    $mock->clear;
    my @selectNodeResults = ( [111], undef );
    no strict 'refs';
    local *{ $package . '::getType' };
    *{ $package . '::getType' } = sub {
        $mock;
    };
    local *{ $package . '::selectNodeWhere' };
    *{ $package . '::selectNodeWhere' } = sub {
        shift @selectNodeResults;
    };
    local *{ $package . '::patchXMLwhere' };
    *{ $package . '::patchXMLwhere' } = sub {
        $mock;
    };
    use strict 'refs';

    $mock->set_always( 'getLength' => 2 )->set_series(
        getValue => 'noderef',
        'an attribute title', 'firstatt', 'secondatt'
      )->set_always( item => $mock )
      ->set_series( getName => 'firstname', 'secondname' );
    $result = parseBasicTag( $mock, 'fixby ref' );
    is_deeply(
        $result,
        { 'an attribute title' => 111, 'name' => 'an attribute title' },
        '...and sets result to node id'
    );

    ### now test a fix
    $mock->set_series(
        getValue => 'noderef',
        'an attribute title', 'firstatt', 'secondatt'
    )->set_series( getName => 'firstname', 'secondname' );
    $result = parseBasicTag( $mock, 'fixby ref' );
    is_deeply(
        $result,
        {
            fixBy                => 'fixby ref',
            'field'              => 'an attribute title',
            'an attribute title' => -1,
            name                 => 'an attribute title',
            where                => {
                firstname  => 'firstatt',
                secondname => 'secondatt',
                title      => 'some random content'
            }
        },
        '...and sets result to node id'
    );

    ### now test if type is not literal_value nor noderef
    $mock->set_series( getValue => 'blahblah', 'an attribute title' );
    $result = parseBasicTag( $mock, 'fixby ref' );
    is_deeply(
        $result,
        { name => 'an attribute title' },
        '...if type is not noderef or literal_value.'
    );
    is_deeply(
        ${ $self->{le} }[-1],
        [ '', "XML::parseBasicTag does not understand field type 'blahblah'" ],
        '...and logs an error message.'
    );
}

## patchXMLwhere
#
# takes a hash ref as argument.  If keys have an underscore in them,
# then it tries to find a node. It expects the values to be of the
# form "nodename,nodetype". But what if they're not??

sub test_patch_xml_where : Test(5) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'patchXMLwhere' ) || return;
    my $mock = $self->{mock};

    $mock->{node_id} = 123;
    *patchXMLwhere = \&{ $package . '::patchXMLwhere' };
    my @gn = ();
    no strict 'refs';
    local *{ $package . '::getNode' };
    *{ $package . '::getNode' } = sub {
        push @gn, [@_];
        return $mock;
    };
    use strict 'refs';

    my %hash = ( one => 'thing', '_another' => 'nodename,nodetype' );

    my $result = patchXMLwhere( \%hash );
    is_deeply( $gn[0], [qw/nodename nodetype/],
        '...calls get node with nodename and nodetype arguments.' );
    is_deeply(
        $result,
        { one => 'thing', _another => 123 },
        '...and returns a munged hash objects.'
    );

    @gn     = ();
    %hash   = ( _akey => 'avalue' );
    $result = patchXMLwhere( \%hash );
    is_deeply( $gn[0], undef,
        '...if the node value is not in the right form, getNode is not called.'
    );
    is_deeply( $result, { _akey => 'avalue' }, '...the hash is not amended.' );
}

sub test_unmake_xml_safe : Test(2) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'unMakeXmlSafe' ) || return;
    *unMakeXmlSafe = \&{ $self->{class} . '::unMakeXmlSafe' };
    is( unMakeXmlSafe('&quot; &amp; &gt; &lt;'),
        '" & > <', '...decodes a few XML character entities.' );
}

sub test_get_field_type : Test(5) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'getFieldType' ) || return "Can't getFieldType";

    *getFieldType = \&{ $self->{class} . '::getFieldType' };

    is( getFieldType('hello'), 'literal_value',
        '...usually returns literal value' );

    is( getFieldType('hello_people'),
        'noderef', '...except when it has an underscore.' );
    is( getFieldType('people_id'),
        'literal_value', '...unless the underscore is followed by "id".' );
    is( getFieldType('hello_people_id'),
        'noderef', '...except if there is more than one underscore.' );
}


sub test_xml_final :Test( 6 )
{
	my $self = shift;
	my $node = $self->{mock};

	local *xmlFinal = \&{ $self->{class} . '::xmlFinal' };
	$node->set_series( existingNodeMatches => $node, 0 )
		 ->set_true('updateFromImport')
		 ->set_true('insert');

	my $result = xmlFinal($node);

	is( $node->next_call(), 'existingNodeMatches',
		'xmlFinal() should check for a matching node' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'updateFromImport', '... updating node if so' );
	is( join( '+', @$args ), "$node+$node+-1", '... for node by superuser' );
	is( $result, $node->{node_id}, '... returning the node_id' );

	$result = xmlFinal($node);

	( $method, $args ) = $node->next_call(2);
	is( "$method $args->[1]", 'insert -1', '... or should insert the node' );
	is( $result, $node->{node_id}, '... returning the new node_id' );
}

sub test_xml_tag :Test( 6 ) {
    my $self = shift;
    my $class = $self->{class};
    my $node = $self->{mock};
    local *xmlTag = \&{ $self->{class} . '::xmlTag' };

    $node->set_always( getTagName => 'badtag' );

    $node->set_always( type => $node );
    $node->{title} = 'thistype';
    my $result = xmlTag($node,  $node );
    is( $node->next_call(), 'getTagName', 'xmlTag() should fetch tag name' );
    ok( !$result, '... and should return false unless it contains "field"' );
    like( $self->{le}[-1][1], qr/tag 'badtag'.+'thistype'/,
	    '... logging an error'    );
    no strict 'refs';
    local *{ $class . '::tag_process'};
    *{ $class . '::tag_process'} = {field => sub {"called process field tag"},
				    group => sub {"called process group tag"},
				    vars => sub {"called process setting tag"},
				   };
    use strict 'refs';

    $node->set_always( getTagName => 'field' );
     $result = xmlTag($node,  $node );
    is ($result, 'called process field tag', '...calls process_field_tag() if tagname is "field".');

    $node->set_always( getTagName => 'group' );
     $result = xmlTag($node,  $node );
    is ($result, 'called process group tag', '...calls process_group_tag() if tagname is "group".');


    $node->set_always( getTagName => 'vars' );
     $result = xmlTag($node,  $node );
    is ($result, 'called process setting tag', '...calls process_setting_tag() if tagname is "vars".');
}

sub test_process_field_tag :Test( 6 ) {

	my $self = shift;
	my $node = $self->{mock};

	local *process_field_tag = \&{ $self->{class} . '::process_field_tag' };
	my @pbt;
	my $parse = { name => 'parsed', parsed => 11 };

	local *Everything::XML::parseBasicTag;
	*Everything::XML::parseBasicTag = sub {
		push @pbt, [@_];
		return $parse;
	};

	$node->set_always( getTagName => 'field' );
	my $result = process_field_tag( $node, $node );
	is( join( ' ', @{ $pbt[0] } ), "$node node", '... should parse tag' );
	is( $result, undef, '... should return false with no fixes' );
	is( $node->{parsed}, 11, '... and should set node field to tag value' );

	$parse->{where} = 1;
	$node->set_always( getTagName => 'morefield' );
	$result = process_field_tag( $node, $node );
	isa_ok( $result, 'ARRAY', '... should return array ref if fixes exist' );
	is( $result->[0], $parse, '... with the fix in the array ref' );
	is( $node->{parsed}, -1, '... setting node field to -1' );

}

sub test_process_group_tag :Test( 8 )
{
    my $self = shift;
    my $node = $self->{mock};
    local *process_group_tag = \&{ $self->{class} . '::process_group_tag' };
    my $gcn;
    {

        local *XML::DOM::TEXT_NODE;
        *XML::DOM::TEXT_NODE = sub { 3 };

        $node->mock(
            getChildNodes => sub {
                return if $gcn++;
                return ($node) x 3;
            }
        );
        local *Everything::XML::parseBasicTag;

        my @parses = (
            { where => 'where', },
            {
                name => 'me',
                me   => 'node',
            }
        );
        *Everything::XML::parseBasicTag = sub { return shift @parses };

        $node->set_series( getNodeType => 1, 2, 3 )->set_true('insertIntoGroup')
          ->clear();

        my $result = process_group_tag( $node, $node );

        is( $gcn, 1, '... should get the group child nodes' );
        isa_ok( $result, 'ARRAY',
            '... and should return existing fixup nodes in something that' );
        my ( $method, $args );
        my @inserts;
        while ( ( $method, $args ) = $node->next_call() ) {
            push @inserts, $args if $method eq 'insertIntoGroup';
        }

        is( @inserts, 2, '... and should skip text nodes' );
        is( $result->[0]{fixBy}, 'nodegroup', '... parsing nodegroup nodes' );
        is( join( ' ', map { $_->[3] } @inserts ),
            '0 1', '... inserting each into the nodegroup in order' );
        is( join( '|', @{ $inserts[0] } ),
            "$node|-1|-1|0", '... as a dummy node, given a where clause' );
        is(
            join( '|', @{ $inserts[1] } ),
            "$node|-1|node|1",
            '... or by name, given a name'
        );

        ok(
            !process_group_tag( $node, $node ),
            '... returning nothing with no fixups'
        );
    }
}

sub test_process_vars_tag :Test( 5 ) {
    my $self = shift;
    my $node = $self->{mock};


    local *process_vars_tag = \&{ $self->{class} . '::process_vars_tag' };
	local *XML::DOM::TEXT_NODE;
	*XML::DOM::TEXT_NODE = sub () { 1 };

	$node->set_always( -getTagName    => 'vars' )
		 ->set_series( -getVars       => ($node) x 3 )
		 ->set_series( -getChildNodes => ($node) x 3 )
		 ->set_series( -getNodeType   => 0, 0 )
		 ->set_true( 'setVars' );

	my @types = ( { where => 'foo', name => 'foo' }, { name => 'bar' } );

    no warnings 'redefine';
	local *Everything::XML;
	*Everything::XML::parseBasicTag = sub {
		return shift @types;
	};
    use warnings 'redefine';
	$node->{vars} = { foo => -1, bar => 1 };

	my $fixes = process_vars_tag( $node, $node );
	ok( exists $node->{vars},
		'... should vivify "vars" field in node when requesting "vars"' );
	is( @$fixes, 1, '... and return array ref of fixable nodes' );
	is( $node->{vars}{ $fixes->[0]{where} },
		-1, '... and should mark fixable nodes by name in "vars"' );
	is( $node->{vars}{bar}, 1, '... and keep tag value for fixed tags' );
	my ($method, $args) = $node->next_call( 2 );
	is( join( ' ', $method, $args->[1] ), "setVars $node",
		'... and should call setVars() to keep them' );

}



sub test_commit_xml_fixes :Test( 1 )
{
	my $self = shift;
	my $node = $self->{mock};
	$node->clear;

	local *commitXMLFixes = \&{ $self->{class} . '::commitXMLFixes' };

	$node->set_true( 'update' );
	commitXMLFixes($node);

	my ( $method, $args ) = $node->next_call();
	is( "$method @$args", "update $node -1 nomodify",
		'commitXMLFixes() should call update() on node' );
}


sub test_apply_xml_fix_no_fixby_node :Test( 3 )
{
	my $self = shift;
	my $node = $self->{mock};

	local *applyXMLFix = \&{ $self->{class} . '::applyXMLFix' };

	my $where = { title => 'title', type_nodetype => 'type', field => 'b' };
	my $fix   = { where => $where,  field         => 'fixme', title => '' };

	is( applyXMLFix($node, $fix ), $fix,
		'applyXMLFix() should return fix if it has no "fixBy" field' );

	$fix->{fixBy} = 'fixme';
	is( applyXMLFix( $node, $fix, 1 ), $fix,
		'... or if the field is not set to "node"' );

	like( $self->{le}[-1][1],
		qr/handle fix by 'fixme'/, '... and should log error if flag is set' );
}


sub test_apply_xml_fix :Test( 8 )
{
	my $self = shift;
	my $node = $self->{mock};
	my $db   = $self->{mock};
	local *applyXMLFix = \&{ $self->{class} . '::applyXMLFix' };
	$node->{DB} = $db;

	my $where = { title => 'title', type_nodetype => 'type',  field => 'b' };
	my $fix   = { where => $where,  field         => 'fixme', fixBy => 'node' };

	my @pxw;
        no strict 'refs';
	local *{ $self->{class} . '::patchXMLwhere'};
	*{ $self->{class} . '::patchXMLwhere'}= sub {
			push @pxw, [@_];
			return $_[0];
		};

	$db->set_series( getNode => 0, 0, { node_id => 42 } );
	@{ $self->{le} } = ();
	my $result = applyXMLFix( $node, $fix );
	is( $pxw[0][0], $where, '... should try to resolve node' );

	my ( $method, $args ) = $db->next_call();
	is( $method, 'getNode', '... should fetch resolved node' );
	is( join( '-', @$args[ 1, 2 ] ), "$where-type",
		'... by fix criteria for type' );

	is( $result, $fix,           '... returning the fix if that did not work' );
	is( @{ $self->{le}[0] }, 0, '... returning no error without flag' );

	$node->{title}       = 'n_title';
	$node->{type}{title} = 't_title';
	$result = applyXMLFix( $node, $fix, 1 );
	like( $self->{le}[1][1],
		qr/Unable.+find 'title' of type 'type'.+'fixme'.+'n_title'.+'t_title'/s,
		'... and logging an error if flag is set' );

	$result = applyXMLFix( $node, $fix );
	is( $node->{fixme}, 42, '... should set field to found node_id' );
	ok( !$result, '... should return nothing on success' );
}


sub test_apply_xml_fix_nodegroup :Test( 7 )
{
	my $self       = shift;
	my $node       = $self->{mock};
	my $db         = $self->{mock};
	local *applyXMLFix = \&{ $self->{class} . '::applyXMLFix' };
	$node->{group} = [];

	$node->set_always( SUPER => 14 );

	{
		local *Everything::XML::patchXMLwhere;

		my $pxw;
		*Everything::XML::patchXMLwhere = sub {
			$pxw++;
			return
			{
				title         => 'title',
				field         => 'field',
				type_nodetype => 'type',
			};
		};

		$db->set_series( getNode => { node_id => 111 }, 0, 0 );

		my $fix =
		{
			fixBy   => 'nodegroup',
			orderby => 1,
		};

		my $result = applyXMLFix( $node, $fix );
		ok( $pxw, '... calling patchXMLwhere() to get the right node data' );
		my ( $method, $args ) = $db->next_call();
		is( $method, 'getNode', '... attemping to get the node' );
		is( $args->[1]{type_nodetype}, 'type', '... with the where hashref' );
		is( $node->{group}[1], 111,
			'... replacing dummy node with fixed node on success' );

		$node->{title} = 'title';
		$node->{type}  = { title => 'typetitle' };

		$self->{le} = [];
		$result = applyXMLFix($node, $fix, 1 );
		like( $self->{le}[0][1], qr/Unable to find 'title' of type/,
			'... warning about missing node if error flag is set' );

		$self->{le} = [];
		$result = applyXMLFix( $node, $fix );
		is( @{ $self->{le} }, 0, '... but not warning without flag' );

		isa_ok( $result, 'HASH', '... returning fixup data if it failed' );
	}
}


sub test_apply_xml_fix_setting :Test( 6 )
{
	my $self = shift;

	my $node = $self->{mock};
	my $db   = $self->{mock};
	local *applyXMLFix = \&{ $self->{class} . '::applyXMLFix' };

	my $patch;
	local *Everything::XML::patchXMLwhere;
	*Everything::XML::patchXMLwhere = sub
	{
		$patch = shift;
		return { type_nodetype => 'nodetype' };
	};

	my $fix = { map { $_ => $_ } qw( field where ) };
	$node->set_series( getVars => ( $node ) x 3 );
	$db->set_series( getNode => 0, 0, { node_id => 888 } );

	@$fix{ 'fixBy', 'where' } = ( 'setting', 'w' );
	isa_ok( applyXMLFix( $node, $fix ), 'HASH',
		'... should return setting $FIX if it cannot be found' );

	is( $patch, 'w',
		'... should call patchXMLwhere() with "where" field of FIX' );

	$node->{title}           = 'node title';
	$node->{nodetype}{title} = 'nodetype title';

	$self->{le} = [];
	applyXMLFix( $node,
		{
			field         => 'field',
			fixBy         => 'setting',
			title         => 'title',
			type_nodetype => 'type',
			where         => 1,
		},
		1
	);

	like( $self->{le}[0][1],
		qr/Unable to find 'title'.+'type'.+field/s,
		'... should print error if node is not found and printError is true' );

	$node->{node_id} = 0;
	$fix->{field}    = 'foo';

	$node->set_true( 'setVars' )
		 ->clear();

	is( applyXMLFix( $node, $fix ), undef,
		'applyXMLFix() should return undef if successfully called for setting'
	);
	is( $node->{foo}, 888, '... and set variable for field to node_id' );

	my ($method, $args) = $node->next_call( 3 );

	is( join( ' ', $method, $args->[1] ), "setVars $node",
		'... and should call setVars() to save vars'
	);

}

1;
