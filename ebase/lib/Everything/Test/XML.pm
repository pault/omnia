package Everything::Test::XML;

use strict;
use Test::More;
use Test::MockObject;
use File::Temp qw/tempfile/;
use SUPER;

use base 'Everything::Test::Abstract';

sub startup : Test(startup => +1) {
    my $self = shift;
    my $mock = Test::MockObject->new;

    $self->{le} = [];
    $mock->fake_module( 'Everything',
        logErrors => sub { push @{ $self->{le} }, [@_] } );
    $mock->fake_module('XML::DOM');

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

    can_ok( $package, 'fixNodes' );

    my ( @gn, @gnret );

    no strict 'refs';
    local *fixNodes;
    *fixNodes = \&{ $self->{class} . '::fixNodes' };
    local *unfixed;
    *_unfixed = \&{ $self->{class} . '::_unfixed' };
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

    $mock->set_series( applyXMLFix => 1, 0, 1 )->set_true('commitXMLFixes')
      ->clear();
    $unfixed->{foo} = [ 1, 2 ];

    fixNodes('printflag');
    my ( $method, $args ) = $mock->next_call();
    is( $method, 'applyXMLFix', '... calling applyXMLFix() for all unfixed' );
    is( join( '-', @$args ),
        "$mock-1-printflag", '... with fix and print error' );
    is_deeply( $unfixed, { foo => [1] }, '... saving only unfixed nodes' );

    $mock->clear();

    $unfixed = { bar => [] };
    fixNodes('printflag');
    is( $mock->next_call(2), 'commitXMLFixes', '... committing fixes' );

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

sub test_xml2node : Test(4) {
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
    $mock->set_always( -xmlTag => [qw/onefix twofix threefix /] );
    $mock->set_series( xmlFinal => 1, 2, 3, 4 );

    my (@gn);
    no strict 'refs';
    local *{ $package . '::getNode' };
    *{ $package . '::getNode' } = sub {
        push @gn, [@_];
        return $mock;
    };
    use strict 'refs';

    local *XML::DOM::TEXT_NODE = sub { 0 };
    my $result = xml2node('some xml');
    my ( $method, $args ) = $mock->next_call;

    is( $method, 'xmlFinal', '...parses XML document.' );
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

### genBasicTag
# is passed $doc, $tagname, $fieldname, $content
#
# $doc is a XML::DOM::Document object and here is a mock
# $tagname is a string of what whe want to call the XML tag
#
# fieldname is the field of the node that we are encoding
# content is the actual content that we are encoding
#
# if fieldname is preceded by an underscore it is assumed content is a
# noderef pointing to a type

sub test_gen_basic_tag : Test(15) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'genBasicTag' ) || return "Can't genBasicTag";

    my $mock = $self->{mock};
    $mock->clear;

    $mock->fake_module('XML::DOM::Element');
    $mock->fake_new('XML::DOM::Element');
    $mock->fake_module('XML::DOM::Text');
    $mock->fake_new('XML::DOM::Text');

    $mock->set_true( 'setAttribute', 'appendChild', '-isOfType' );
    $mock->set_always( 'getIdentifyingFields', ['identifyingfield'] );
    $mock->{type}->{title} = "a_type_title";
    my (@gn);
    no strict 'refs';

    local *genBasicTag = \&{ $self->{class} . '::genBasicTag' };
    local *{ $package . '::getNode' };
    *{ $package . '::getNode' } = sub {
        push @gn, [@_];
        return $mock;
    };
    local *{ $package . '::makeXmlSafe' };
    *{ $package . '::makeXmlSafe' } = sub {
        push @gn, [@_];
        return $_[0];
    };

    local *{ $package . '::getRef' };
    *{ $package . '::getRef' } = sub {
        $mock->{node_id} = $_[0];
        $_[0] = $mock;
    };
    use strict 'refs';

    my $result = genBasicTag(
        $mock,
        "amazing tag name",
        "node field name",
        "stupendous content"
    );

    my ( $method, $args ) = $mock->next_call;
    is( $method, 'setAttribute', '...sets tag attributes.' );
    is_deeply(
        $args,
        [ $mock, 'name', 'node field name' ],
        '...and set it properly.'
    );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'setAttribute', '...sets next tag attributes.' );
    is_deeply(
        $args,
        [ $mock, 'type', 'literal_value' ],
        '...and sets it to literal value.'
    );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'appendChild', '...adds it to the tag.' );
    is_deeply( $args, [ $mock, $mock ], '...with the correct content.' );
    is( $result, $mock, '...should return a tag' );

    $mock->{identifyingfield} = 111;
    $result = genBasicTag( $mock, "amazing tag name", "_nodefieldname", "112" );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'getIdentifyingFields',
        '...checks identifying fields if node has some.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'setAttribute', '...sets tag attributes.' );
    is_deeply(
        $args,
        [ $mock, 'identifyingfield', 111 ],
        '...with identifying fields'
    );

    $mock->clear;
    @gn                        = ();
    $mock->{_identifyingfield} = 222;
    $mock->{title}             = 'a random title';
    $mock->{type}->{title}     = 'a type name';
    $mock->set_always( 'getIdentifyingFields', ['_identifyingfield'] );
    $result = genBasicTag( $mock, "amazing tag name", "_nodefieldname", "112" );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'getIdentifyingFields',
        '...checks identifying fields if noderef.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'setAttribute', '...sets tag attributes with node ref.' );
    is_deeply(
        $args,
        [ $mock, '_identifyingfield', 'a random title,a type name' ],
        '...with fields by type and name.'
    );

    is_deeply( $gn[2], [222],
        '...and calls get node with the identifying field' );
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

sub test_make_xml_safe : Test(2) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'makeXmlSafe' ) || return;
    *makeXmlSafe = \&{ $self->{class} . '::makeXmlSafe' };
    is(
        makeXmlSafe('& > <'),
        '&amp; &gt; &lt;',
        '...encodes a few XML character entities.'
    );
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

1;
