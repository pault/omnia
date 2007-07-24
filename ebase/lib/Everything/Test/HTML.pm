package Everything::Test::HTML;

use Test::More;
use Test::MockObject;
use Everything;
use Scalar::Util qw/blessed/;
use base 'Test::Class';
use strict;
use warnings;

use Carp;

sub module_class {
    my $self = shift;
    my $name = blessed($self);
    $name =~ s/Test:://;
    return $name;
}

my @le;

sub startup : Test(startup => 1) {
    my $self  = shift;
    my $class = $self->module_class();
    my $mock  = Test::MockObject->new;

    $mock->fake_module('Everything::HTTP::Request');
    $mock->fake_new('Everything::HTTP::Request');
    $mock->set_always( 'get_cgi', $mock )->set_always( 'get_node', $mock );
    $mock->{node_id} = 123;

    $mock->fake_module('Everything::Auth');
    $mock->fake_module( 'Everything', logErrors => sub { push @le, [@_] } );

    *Everything::HTML::getNode = sub { $mock };
    $self->{mock}  = $mock;
    $self->{class} = $class;
    use_ok($class) or die;
    require Everything::HTML;

}

sub setup : Test(setup) {
    my $self = shift;
    $self->{mock}->{node_id} = 123;
    my $mock = $self->{mock};
    $Everything::HTML::DB    = $self->{mock};
    $Everything::HTML::query = CGI->new;
    $mock->set_always( url => 'http://fakeurl' );
}

sub test_list_code : Test(3) {

    my $self    = shift;
    my $package = $self->{class};
    my $mock    = $self->{mock};
    can_ok( $package, 'listCode' );
    local $ENV{SCRIPT_NAME} = '';
    $mock->set_always( getType => $mock );
    $mock->set_always( getNode => $mock );
    $mock->{node_id} = 123;
    no strict 'refs';
    local *listCode = *{ $package . '::listCode' }{CODE};
    use strict 'refs';
    is(
        listCode('[{random text}]'),
        '<pre>&#91;{<a href="?node_id=123">random text</a>}&#93;</pre>',
        '...returns text.'
    );
    is(
        listCode('[<random text>]'),
        '<pre>&#91;&lt;<a href="?node_id=123">random text</a>&gt;&#93;</pre>',
        '...returns text.'
    );

}

sub test_url_gen : Test(3) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'urlGen' );

    local $ENV{SCRIPT_NAME} = '';
    my $q = CGI->new();
    no warnings 'once';
    local *urlGen = \&{ $package . '::urlGen' };
    my $result = urlGen( { foo => [ 'bar', 'baz' ] } );
    is( $result, '"?foo=bar;foo=baz"',
        'urlGen() should generate relative URL from params' );
    is( urlGen( { foo => 'bar' }, 1 ),
        '?foo=bar', '... without quotes, if noflags is true' );

}

sub test_link_code : Test(3) {
    my $self    = shift;
    my $package = $self->{class};
    my $mock    = $self->{mock};
    can_ok( $package, 'linkCode' ) || return "linkCode not implemented";
    local *linkCode = \&{ $package . '::linkCode' };

    ### linkCode takes two arguments. The first is the node name of what
    ### we are linking to. linkCode strips out any ':' characters and just
    ### links to what is before that.  The second is the type of the node
    ### we are linking to.  It is expected that this will either be
    ### 'htmlcode' or 'htmlsnippet', but there is no checking.
    local $ENV{SCRIPT_NAME} = '';
    $mock->{node_id} = 123;
    $mock->{title}   = 'some code';
    $mock->set_series( getId => '123', '' );
    is( linkCode( 'hello', '1' ),
        '<a href="?node_id=123">hello</a>', 'linkCode' );
    is( linkCode( 'hello:one,two,three', '1' ),
        '<a href="?node_id=123">hello:one,two,three</a>', 'linkCode' );

}

sub test_new_form_object : Test(2) {
    my $self    = shift;
    my $package = $self->{class};

    can_ok( $package, 'newFormObject' );
    local *newFormObject = \&{ $package . '::newFormObject' };
    is( newFormObject(), undef, 'newFormObject() should return without name' );

}

sub test_link_node : Test(5) {
    my $self    = shift;
    my $package = $self->{class};

    local *linkNode = \&Everything::HTML::linkNode;

    #linkNode takes for args: $NODE, $title (goes between the opening and
    #closeing enter tags, $params a hashref of stuff to be added to the
    #url, and $scripts which is a misnomer since it is a hashref of stuff
    #to be added as attributes to the anchor tag.

    # returns a well-formed anchor tag
    my $m    = $self->{mock};
    my $mock = Test::MockObject->new;
    local $ENV{SCRIPT_NAME} = '';
    my $q = CGI->new();
    $mock->{node_id} = 111;
    $mock->{title}   = "Random node";

    $m->set_always( getNode => $mock );
    is( linkNode(1), '<a href="?node_id=111">Random node</a>', "linkNode" );
    $mock->{node_id} = 222;
    $mock->{title}   = "Another Random Node";
    is( linkNode($mock), '<a href="?node_id=222">Another Random Node</a>',
        "linkNode" );
    is( linkNode( $mock, "Different Title" ),
        '<a href="?node_id=222">Different Title</a>', "linkNode" );
    is( linkNode( $mock, "Different Title", { op => 'hello' } ),
        '<a href="?node_id=222;op=hello">Different Title</a>', "linkNode" );

    is(
        linkNode(
            $mock,
            "Different Title",
            { op    => 'hello' },
            { style => "Foo: bar" }
        ),
        '<a href="?node_id=222;op=hello" style="Foo: bar">Different Title</a>',
        "linkNode"
    );

}

sub test_link_node_title : Test(6) {
    my $self    = shift;
    my $package = $self->{class};
    my $mock    = $self->{mock};

    #linkNodeTitle
    can_ok( $package, 'linkNodeTitle' );
    local *linkNodeTitle = \&{ $package . '::linkNodeTitle' };

    ### linkNodeTitle takes three args.  $nodename
    ### (self-explanatory, $lastnode (either $node obj or id) and $title
    ### which should what gets placed between the a tags and therefore
    ### what we see in the browser. As an alternative the first arg could
    ### have the nodename and title separated by '|'

    no warnings 'once';
    my $q = CGI->new();
    local *Everything::HTML::query = \$q;
    local *Everything::HTML::logErrors;
    *Everything::HTML::logErrors = sub { 1 };
    local $ENV{SCRIPT_NAME} = '';
    $mock->{node_id} = 777;
    $mock->set_always( 'getId', $mock->{node_id} );

    is(
        linkNodeTitle("Thing"),
        '<a href="?node=Thing">Thing</a>',
        '...with one title argument.'
    );
    is(
        linkNodeTitle("Thing|Different Thing"),
        '<a href="?node=Thing">Different Thing</a>',
        '...with one argument in two parts seperated by a |'
    );
    is(
        linkNodeTitle( "Thing|Different Thing", '', 'New Title' ),
        '<a href="?node=Thing">New Title</a>',
        '... with argument as previously, no lastnode, but a sperate title.'
    );
    is(
        linkNodeTitle( "Thing or two", '', 'Newer Title' ),
        '<a href="?node=Thing%20or%20two">Newer Title</a>',
        '... with node title and third argument title'
    );
    is(
        linkNodeTitle( "Thing or two", $mock, 'Newer Title' ),
        '<a href="?lastnode_id=777;node=Thing%20or%20two">Newer Title</a>',
        '... same but with a lastnode argument'
    );

}

sub test_tag_approve : Test(5) {
    my $self    = shift;
    my $package = $self->{class};

    can_ok( $package, 'tagApprove' ) || return;

    local *tagApprove = \&{ $package . '::tagApprove' };
    ## tagApprove tagApprove takes four arguments: $close, $tag, $attr,
    ## $APPROVED

    ## $close is either '/' if this is a closing tag or nothing if it is
    ## the opening. $tag is the name of the tag. $attr is a string of the
    ## attribures. And $APPROVED is a hashref of the approved tags where
    ## the keys are the tags attributes is a comma-delimited string of the
    ## approved attributes.

    my $APPROVED = {
        p   => 'font,size',
        a   => 'style,href',
        div => 'style,id',
    };

    my $ARGS = [
        [ '', 'p', 'size="10pt" weight="100kg", style="font-weight: bold"' ],
        [
            '',
            'a',
'href="http://some/place,o/where?art_id=25;thing=good&foo=bar" id="someid", style="font-weight: bold"'
        ],
        [ '/', 'a',    'style="font-weight: bold"' ],
        [ '',  'form', 'size="10px" weight="1", style="font-face: m"' ],
    ];

    my $expected = [

        '<p size="10pt">',
'<a style="font-weight: bold" href="http://some/place,o/where?art_id=25;thing=good&foo=bar">',
        '</a style="font-weight: bold">',
        '',

    ];

    foreach ( 0 .. $#$ARGS ) {
        is( tagApprove( @{ $$ARGS[$_] }, $APPROVED ),
            $$expected[$_], 'Test tagApprove' );
    }

}

sub test_html_screen : Test(5) {
    my $self    = shift;
    my $package = $self->{class};

    can_ok( $package, 'htmlScreen' );
    local *htmlScreen = \&{ $package . '::htmlScreen' };
    ###htmlScreen takes a tag and the $APPROVED hash as above and returns
    ###a mangled :) tag
    my $APPROVED = {
        p   => 'font,size',
        a   => 'style,href',
        div => 'style,id',
    };

    my $ARGS = [
        {
            input =>
'<a href="http://some/location0,6444,/comment.pl?id=23&art=hello;foo=bar" id="hum">',
            output =>
'<a href="http://some/location0,6444,/comment.pl?id=23&art=hello;foo=bar">'
        },
        {
            input  => '</div mood="background-color: turquoise">',
            output => '</div>',
        },
        {
            input  => '<p>',
            output => '<p>',
        },
        {
            input  => '<form>',
            output => '',
        },

    ];

    foreach (@$ARGS) {
        is( htmlScreen( $_->{input}, $APPROVED ), $_->{output}, "htmlScreen" );
    }

}

sub test_encode_decode_html : Test(28) {
    my $self    = shift;
    my $package = $self->{class};

    can_ok( $package, 'encodeHTML' );
    can_ok( $package, 'decodeHTML' );
    local *encodeHTML = \&{ $package . '::encodeHTML' };
    local *decodeHTML = \&{ $package . '::decodeHTML' };

    #individually:
    is( encodeHTML(''),  '',       'encodeHTML() should preserve nullspace' );
    is( encodeHTML('&'), '&amp;',  'encodeHTML() should encode ampersands' );
    is( encodeHTML('"'), '&quot;', 'encodeHTML() should encode double quotes' );
    is( encodeHTML('<'), '&lt;',
        'encodeHTML() should encode left angle brackets' );
    is( encodeHTML('>'), '&gt;',
        'encodeHTML() should encode right angle brackets' );
    is( encodeHTML('['), '[',
        'encodeHTML() should not encode left brackets without the adv parameter'
    );
    is( encodeHTML(']'), ']',
'encodeHTML() should not encode right brackets without the adv parameter'
    );
    is( encodeHTML( '[', 1 ),
        '&#91;',
        'encodeHTML() should encode left brackets with the adv parameter' );
    is( encodeHTML( ']', 1 ),
        '&#93;',
        'encodeHTML() should encode right brackets with the adv parameter' );

    is( decodeHTML(''),       '',  'decodeHTML() should preserve nullspace' );
    is( decodeHTML('&amp;'),  '&', 'decodeHTML() should decode apersands' );
    is( decodeHTML('&quot;'), '"', 'decodeHTML() should decode double quotes' );
    is( decodeHTML('&lt;'), '<',
        'decodeHTML() should decode angle left brackets' );
    is( decodeHTML('&gt;'), '>',
        'decodeHTML() should decode angle right brackets' );
    is( decodeHTML('&#91;'), '&#91;',
        'decodeHTML() should not decode left brackets without the adv parameter'
    );
    is( decodeHTML('&#93;'), '&#93;',
'decodeHTML() should not decode right brackets without the adv parameter'
    );
    is( decodeHTML( '&#91;', 1 ),
        '[',
        'decodeHTML() should decode left brackets with the adv parameter' );
    is( decodeHTML( '&#93;', 1 ),
        ']',
        'decodeHTML() should decode right brackets with the adv parameter' );

    #integrated:
    my $string = "'&foo; <br>'";
    is(
        encodeHTML($string),
        "'&amp;foo; &lt;br&gt;'",
        'encodeHTML() should create valid encoded characters in a string'
    );
    is( decodeHTML( encodeHTML($string) ),
        $string, 'encodeHTML() and decodeHTML() should undo each other' );

    $string = ' [ foo &amp;]"Hello';
    is(
        encodeHTML($string),
        ' [ foo &amp;amp;]&quot;Hello',
        'encodeHTML() should properly encode a complicated string'
    );
    is(
        decodeHTML($string),
        ' [ foo &]"Hello',
        'decodeHTML() should properly decode a complicated string'
    );
    is(
        decodeHTML( encodeHTML($string) ),
        $string,
'encodeHTML() and decodeHTML() should undo each other for a complicated string'
    );

    $string = "<br>\n&lt;p&gt;";
    is(
        encodeHTML($string),
        "&lt;br&gt;\n&amp;lt;p&amp;gt;",
        'encodeHTML() should properly encode a string with a newline'
    );
    is( decodeHTML($string), "<br>\n<p>",
        'decodeHTML() should properly decode a string with a newline' );
    is(
        decodeHTML( encodeHTML($string) ),
        $string,
'encodeHTML() and decodeHTML() should undo each other for a string with a newline'
    );

}

sub test_parse_links : Test(3) {
    my $self    = shift;
    my $package = $self->{class};
    my $mock    = $self->{mock};
    can_ok( $package, 'parseLinks' );
    local $ENV{SCRIPT_NAME} = '';
    local *parseLinks = \&{ $package . '::parseLinks' };

    delete $mock->{node_id};
    is( parseLinks( 'random text', $mock ), 'random text', 'test random text' );
    is(
        parseLinks( 'random text[node name]', $mock ),
        'random text<a href="?node=node%20name">node name</a>',
        'text with node'
    );

}

sub test_format_gods_backside_errors : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'formatGodsBacksideErrors' );

}

sub test_print_backside_tologfile : Test(1) {
    my $self    = shift;
    my $package = $self->{class};

    can_ok( $package, 'printBacksideToLogFile' );

}

sub test_htmlsnippet : Test(3) {
    my $self    = shift;
    my $package = $self->{class};

    my $mock = $self->{mock};
    can_ok( $package, 'htmlsnippet' );
    local *htmlsnippet          = \&{ $package . '::htmlsnippet' };
    local *Everything::HTML::DB = \$mock;

    $mock->set_always( 'getNode',  $mock );
    $mock->set_always( 'get_cgi',  $mock );
    $mock->set_always( 'get_node', $mock );
    $mock->set_always( 'get_user_vars', { key => 'value' } );
    $mock->set_series( 'hasAccess', 0, 1 );
    $mock->{code} = "some code";

    is( htmlsnippet('snippet'), '', 'htmlsnippet with access denied' );

    $mock->set_always( 'run', 'some code' );
    is( htmlsnippet('snippet'), 'some code',
        'htmlsnippet with access allowed' );

}

sub test_evalx : Test(3) {
    my $self    = shift;
    my $package = $self->{class};
    my $mock    = $self->{mock};

    can_ok( $package, 'evalX' );
    local *evalX = \&{ $package . '::evalX' };

    #evalX should just parse things sanely;
    my $code = '"string"';
    is( evalX($code), 'string', 'evalX string' );
    $code = 'my $x = 1 + 2; return $x';

    is( evalX( $code, $mock ), 3, 'maths' );

}

sub test_parse_code : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'parseCode' );
}

sub test_insert_nodelet : Test(2) {
    my $self    = shift;
    my $package = $self->{class};
    my $mock    = $self->{mock};
    can_ok( $package, 'insertNodelet' );
    local *insertNodelet = \&{ $package . '::insertNodelet' };

    $mock->{DB}             = $mock;
    $mock->{nlcode}         = 'some code';
    $mock->{NODE}           = $mock;
    $mock->{USER}           = $mock;
    $mock->{title}          = 'a nodelet';
    $mock->{node_id}        = 222;
    $mock->{updateinterval} = 2;
    $mock->{lastupdate}     = 2;

    $mock->set_always( 'run', 'some code' );
    $mock->set_always( getNode => $mock );
    $mock->set_true( 'hasAccess', 'update' );

    no strict 'refs';
    local *{ $self->{class} . '::genContainer' };
    *{ $self->{class} . '::genContainer' } = sub { 'CONTAINED_STUFF' };

    is( insertNodelet($mock), "some code", '...we can insertNodelet' );

}

sub test_update_nodelet : Test(2) {
    my $self    = shift;
    my $package = $self->{class};
    my $mock    = $self->{mock};

    can_ok( $package, 'updateNodelet' );

    local *updateNodelet = \&{ $package . '::updateNodelet' };

    $mock->set_always( 'getNode', $mock );
    $mock->set_true('updateNodelet');
    $mock->set_true('update');
    $mock->{nltext} = "other code";
    $mock->set_always( 'run' => 'parsed and compiled html' );
    $mock->{updateinterval} = 2;
    $mock->{lastupdate}     = 2;
    is( updateNodelet($mock), "" );

}

1;
