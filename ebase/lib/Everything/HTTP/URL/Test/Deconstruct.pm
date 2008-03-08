package Everything::HTTP::URL::Test::Deconstruct;



use strict;
use Test::Exception;
use Test::More;
use base 'Everything::HTTP::Test::URL';



## needs to be rewritten
sub test_z_process : Test(4) {

    my $self = shift;
    can_ok($self->{class}, 'process') || return;
    my $mock = $self->{mock};
    $mock->{node_id} = 222;

    my $instance = $self->{instance};

    $mock->set_true('param');

    $instance->mock('make_requested_node_ref' => sub {$_[0]->set_requested_node_ref($mock) });

    $mock->set_always('getType', $mock);
    $instance->set_schema('/node/:node_id');

    my $fake_request = Test::MockObject->new;
    $fake_request->set_always( get_nodebase => $mock );

    ok ($instance->process( $fake_request ) );
 
    $instance->set_schema('/node/:type');
    $instance->get_nodebase->set_always('getType', {node_id => 111});
    $instance->set_always('get_matches', [['type_nodetype'], 222]);
    ok ($instance->process( $fake_request ) );
    my ($method, $args) = $instance->next_call();
    is ($method, 'make_requested_node_ref', '...should call node making method.');


}


sub test_make_url : Test(5) {

    my $self = shift;
    can_ok($self->{class}, 'make_url') || return;
    my $mock = $self->{mock};
    $mock->{node_id} = 222;
    my $instance = $self->{instance};
    $instance->set_rule('/node/:node_id');
    $instance->tokenize();
    $instance->make_urlifier();
    is ($instance->make_url($mock), '/node/222');
    is ($instance->make_url($mock), '/node/222');
    is ($instance->make_url($mock), '/node/222');

    $mock->{node_id} = 0;
    is ($instance->make_url($mock), '/node/0', '...if node id is 0, creates correct url.');



}

sub test_make_urlifier : Test(2) {
    my $self = shift;
    can_ok($self->{class}, 'make_urlifier') || return;
    is (ref $self->{instance}->make_urlifier, 'CODE', '...should return a code ref.');
}


sub test_make_url_gen : Test(4) {
    my $self    = shift;
    my $class = $self->{class};
    my $instance = $self->{instance};
    can_ok( $class, 'make_url_gen' );
    my $code_ref = $instance->make_url_gen;
    is(ref $code_ref, 'CODE', '...creates a code ref');
    my $result = $code_ref->( { foo => [ 'bar', 'baz' ] }, );
    is( $result, '"/node/?foo=bar&foo=baz"',
        'urlGen() should generate relative URL from params' );
    is( $code_ref->( { foo => 'bar' }, 1),
        '/node/?foo=bar', '... without quotes, if noflags is true' );

}

sub test_make_link_node :Test(8) {
    my $self    = shift;
    my $class = $self->{class};
    my $instance = $self->{instance};
    can_ok( $class, 'make_link_node' ) || return;
    $instance->set_schema('/node/:node_id');
    $instance->make_url_gen;
    my $mock = Test::MockObject->new;

    *Everything::HTML::DB = \$mock;

    $mock->{node_id} = 111;
    $mock->{title}   = "Random node";
    $instance->set_nodebase($mock);

    $mock->set_always('getNode', $mock);

    my $linkNode = $instance->make_link_node;

    is(ref $linkNode, 'CODE', '...creates a code ref');
    is( $linkNode->($mock), '<a href="/node/111">Random node</a>', "linkNode" );
    $mock->{node_id} = 222;
    $mock->{title}   = "Another Random Node";
    is( $linkNode->($mock), '<a href="/node/222">Another Random Node</a>',
        "linkNode" );
    is( $linkNode->( $mock, "Different Title" ),
        '<a href="/node/222">Different Title</a>', "linkNode" );
    is( $linkNode->( $mock, "Different Title", { op => 'hello' } ),
        '<a href="/node/222?op=hello">Different Title</a>', "linkNode" );

    is(
        $linkNode->(
            $mock,
            "Different Title",
            { op    => 'hello' },
            { style => "Foo: bar" }
        ),
        '<a href="/node/222?op=hello" style="Foo: bar">Different Title</a>',
        "linkNode"
    );

    $mock->{node_id}=0;
    is( $linkNode->($mock), '<a href="/node/0">Another Random Node</a>',
        "...treats node with id = 0 properly." );

}


sub test_make_link_node_compulsory_value :Test(5) {
    my $self    = shift;
    my $class = $self->{class};
    my $instance = $self->{instance};
    can_ok( $class, 'make_link_node' ) || return;
    $instance->set_schema('/node/:title?foobar');
    $instance->make_url_gen;
    my $mock = Test::MockObject->new;


    $mock->{node_id} = 111;
    $mock->{title}   = "Random node";
    $instance->set_nodebase($mock);

    $mock->set_always('getNode', $mock);

    my $linkNode = $instance->make_link_node;

    is(ref $linkNode, 'CODE', '...creates a code ref');
    is( $linkNode->($mock), '<a href="/node/Random%20node">Random node</a>', "...testing node url creation." );

    ## testing title

    $mock->{node_id} = 222;
    $mock->{title}   = "Another Random Node";
    is( $linkNode->($mock), '<a href="/node/Another%20Random%20Node">Another Random Node</a>',
        "... url creation with compulsory values" );
 
    ## testing type
    $instance->set_schema('/node/:type?location');
    $instance->make_url_gen;
    $linkNode = $instance->make_link_node;
    $mock->{type_nodetype} = 3;
    $mock->{DB} = $mock;
    $mock->set_always('getType', { title => 'Nodetype title'});
    is( $linkNode->($mock), '<a href="/node/Nodetype%20title">Another Random Node</a>',
        "linkNode" );
}


sub setup : Test(setup) {
    my $self = shift;
    my $mock = Test::MockObject->new;
    $mock->set_always('location', '');
}

sub test_tokenize : Test(5) {
    my $self = shift;
    can_ok($self->{class}, 'tokenize');
    my $instance = $self->{instance};
    $instance->set_rule('/node/:node_id/');
    ok($instance->tokenize, '...tokenize returns true');
    is_deeply($instance->get_tokens, [qw/TEXT node ATTRIBUTE/, ["node_id"], 'TEXT', '' ], '...sets the token attribute correctly');

   $instance->set_rule('/node/:node_id?999/');
    ok($instance->tokenize, '...tokenize returns true');
    is_deeply($instance->get_tokens, [qw/TEXT node ATTRIBUTE/, ["node_id", "999"], 'TEXT', ''], '...sets the token attribute correctly with variable.');

}


sub test_make_regex : Test(5) {
    my $self = shift;
    can_ok($self->{class}, 'tokenize');
    my $instance = $self->{instance};
    $instance->set_rule('/node/:node_id');
    ok($instance->tokenize, '...tokenize returns true');
    ok($instance->make_regex, '...make_regex returns true');
    is($instance->get_re, qr{^/node/(\w+)}, '...sets the token attribute correctly');
    is_deeply($instance->get_path_vars, [['node_id']], '...sets the path_vars correctly');

}

sub test_match : Test(3) {
    my $self = shift;
    can_ok($self->{class}, 'match');
    my $instance = $self->{instance};
    $instance->set_schema('/:type/node/:node_id/foo');
    is_deeply ( $instance->match('/baaa/node/77/foo'), [ ['type'], 'baaa', ['node_id'], '77'], '...returns a list of pairs.');

    # test zero match
    is_deeply ( $instance->match('/baaa/node/0/foo'), [ ['type'], 'baaa', ['node_id'], '0'], '...returns a list of pairs withj zero.');
}
1;
