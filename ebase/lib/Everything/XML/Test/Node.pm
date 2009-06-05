package Everything::XML::Test::Node;

use base 'Test::Class';
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Scalar::Util qw/blessed/;
use strict;
use warnings;

BEGIN {
    Test::MockObject->fake_module('XML::DOM::Text');
    Test::MockObject->fake_module('XML::DOM::Element');
    Test::MockObject->fake_module('XML::DOM::Document');
}

sub object_class {
    my $self = shift;
    my $name = blessed($self);
    $name =~ s/Test:://;
    return $name;
}

sub startup : Test(2) {
    my $self  = shift;
    my $class = $self->object_class;
    use_ok($class);
    isa_ok( $class->new(), $class );
    $self->{class}    = $class;
    $self->{instance} = $class->new;
}

sub test_field_to_XML : Test( 5 ) {
    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};

    my $node = Test::MockObject->new;
    $instance->set_node($node);
    my @gbt;

    no strict 'refs';
    local *{ $class . '::genBasicTag' };
    *{ $class . '::genBasicTag' } = sub {
        push @gbt, [@_];
        'tag';
    };
    use strict 'refs';

    $node->{afield} = 'thisfield';
    is( $instance->fieldToXML( $node, 'afield' ),
        'tag', 'fieldToXML() should return an XML tag element' );
    is( @gbt, 1, '... and should call genBasicTag()' );
    is(
        join( ' ', @{ $gbt[0] } ),
        "$instance $node field afield thisfield",
        '... with the correct arguments'
    );

    ok(
        !$instance->fieldToXML( $instance, 'notafield' ),
        '... and should return false if field does not exist'
    );
    ok( !exists $node->{notafield}, '... and should not create field' );
}

sub test_field_to_XML_vars : Test( 5 ) {
    my $self     = shift;
    my $instance = $self->{instance};
    my $mock     = Test::MockObject->new;
    $instance->set_node($mock);
    $instance->set_nodebase($mock);

    $mock->{vars} = 'a var';

    local ( *XML::DOM::Element::new, *XML::DOM::Text::new,
        *Everything::XML::Node::genBasicTag, *fieldToXML );

    my @dom;
    *XML::DOM::Element::new = *XML::DOM::Text::new = sub {
        push @dom, shift;
        return $mock;
    };

    my @tags;
    *Everything::XML::Node::genBasicTag = sub {
        push @tags, join( ' ', @_[ 2 .. 4 ] );
    };

    $mock->set_always( getVars => { a => 1, b => 1, c => 1 } )
      ->set_true('-appendChild');

    is( $instance->fieldToXML( '', 'vars' ),
        $mock, '... should return XML::DOM element for vars, if "vars" field' );
    is( @dom, 5, '... should make several DOM nodes:' );
    is( scalar grep( /Element/, @dom ), 1, '... one Element node' );
    is( scalar grep( /Text/,    @dom ), 4, '... and several Text nodes' );

    is(
        join( '!', @tags ),
        'var a 1!var b 1!var c 1',
        '... should call genBasicTag() on each var pair'
    );
}

sub test_field_to_XML_group : Test( 5 ) {
    my $self     = shift;
    my $instance = $self->{instance};
    my $mock     = Test::MockObject->new;
    $mock->set_true('appendChild');
    $instance->set_node($mock);
    $instance->set_nodebase($mock);
    $mock->set_true( 'getRef', 'setAttribute', 'isOfType' );
    $mock->set_always( 'getNode', $mock );
    $mock->set_always( 'getIdentifyingFields', ['identifyingfield'] );

    my $result = $instance->fieldToXML( 'doc', 'field', 0 );
    my ( $method, $args );

    {
        local ( *XML::DOM::Element::new, *XML::DOM::Text::new,
            *Everything::XML::Node::genBasicTag );

        my @xd;
        *XML::DOM::Text::new = sub {
            push @xd, [@_];
            return @_;
        };
        *XML::DOM::Element::new = sub {
            push @xd, [@_];
            return $mock;
        };

        my @gbt;
        *Everything::XML::Node::genBasicTag = sub {
            push @gbt, [@_];
        };

        $mock->{group} = [ 3, 4, 5 ];
        $result = $instance->fieldToXML( 'doc', 'group', "\r" );

        is(
            join( ' ', @{ $xd[0] } ),
            'XML::DOM::Element doc group',
            '... it should create a new DOM group element'
        );

        my $count;
        for ( 1 .. 6 ) {
            ( $method, $args ) = $mock->next_call();
            $count++ if $method eq 'appendChild';
        }

        is( $count, 6, '... appending each child as a Text node' );
        is( join( ' ', map { $_->[4] } @gbt ),
            '3 4 5', '... noted with their node_ids' );
        is( $method, 'appendChild', '... and appending the whole thing' );
        is( $result, $mock, '... and should return the new element' );
    }

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
    my $self     = shift;
    my $package  = $self->{class};
    my $instance = $self->{instance};
    can_ok( $package, 'genBasicTag' ) || return "Can't genBasicTag";

    my $mock = Test::MockObject->new;

    $instance->set_node($mock);
    $instance->set_nodebase($mock);

    $mock->fake_new('XML::DOM::Element');
    $mock->fake_new('XML::DOM::Text');

    $mock->set_true( 'setAttribute', 'appendChild', '-isOfType', '-getRef' );
    $mock->set_always( 'getIdentifyingFields', ['identifyingfield'] );
    $mock->set_always( -type_title => "a_type_title");
    $mock->{title} = " a node < title > &amp;";
    my (@gn);

    $mock->mock(
        -getNode => sub {
            push @gn, [@_];
            return $mock;
        }
    );
    no strict 'refs';

    local *{ $package . '::getRef' };
    *{ $package . '::getRef' } = sub {
        $mock->{node_id} = $_[0];
        $_[0] = $mock;
    };
    use strict 'refs';

    my $result = $instance->genBasicTag(
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
    $result = $instance->genBasicTag( $mock, "amazing tag name",
        "_nodefieldname", "112" );

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
    $mock->set_always( -type_title  => 'a type name' );
    $mock->set_always( 'getIdentifyingFields', ['_identifyingfield'] );
    $result = $instance->genBasicTag( $mock, "amazing tag name",
        "_nodefieldname", "112" );

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

    is_deeply(
        $gn[-1],
        [ $mock, 222 ],
        '...and calls get node with the identifying field'
    );
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

sub test_a_parse_xml : Test( 16 ) {
    my $self = shift;
    can_ok( $self->{class}, 'parse_xml' ) || return;
    my $instance = $self->{instance};
    my $mock = Test::MockObject->new;

    my $xml = '<NODE title="a test node" nodetype="supertype" export_version="1000"><field name="a field name" type="literal_value">blah</field><field name="a null field" type="literal_value" null="yes"></field><field name="an empty string field" type="literal_value"></field><vars><var name="default_theme" type="noderef" type_nodetype="theme,nodetype">default theme</var></vars><group><member name="group_node" type="noderef" type_nodetype="restricted_superdoc,nodetype">Everything settings</member></group></NODE>';

    ok( $instance->parse_xml($xml), '...parses the XML');
    my $fields = $instance->get_attributes;
    my $vars = $instance->get_vars;
    my $group_members = $instance->get_group_members;

    is ($instance->get_title, 'a test node', '...with a node title.');
    is ($instance->get_nodetype, 'supertype', '...with a node type.');
    is ($instance->get_export_version, 1000, '...with an export version.');

    my $expected_content = [ ['a field name', 'blah'],['a null field', undef ], ['an empty string field', ''] ];
    my $index = 0;
    foreach (sort { $a->get_name cmp $b->get_name } @$fields) {
	my $field_name = $_->get_name;
	my $field_content = $_->get_content;
	my $field_type = $_->get_type;
	my $field_type_nodetype = $_->get_type_nodetype;
	is($field_name, $expected_content->[$index]->[0], '...one field with field name.');
	is ($field_content, $expected_content->[$index++]->[1], '...with the correct content');
    }

    foreach (@$vars) {
	my $var_name = $_->get_name;
	my $var_content = $_->get_content;
	my $var_type = $_->get_type;
	my $var_type_nodetype = $_->get_type_nodetype;
	is($var_name, 'default_theme', '...one field with field name.');
	is ($var_content, 'default theme', '...with the correct content');
    }


    foreach (@$group_members) {
	my $member_name = $_->get_name;
	my $member_type = $_->get_type;
	my $member_type_nodetype = $_->get_type_nodetype;
	is($member_name, 'Everything settings', '...one field with field name.');
	is ($member_type_nodetype, 'restricted_superdoc,nodetype', '...with the correct content');
	is($member_type, 'noderef', '...groups nodes are always noderefs.');
    }

}

sub test_to_xml : Test(4) {
    my $self = shift;
    can_ok( $self->{class}, 'toXML' ) || return;
    my $instance = $self->{instance};
    my $mock = Test::MockObject->new;

    $instance->set_node($mock);
    $instance->set_nodebase( $mock );

    my @fieldtoxml_args = ();
    no strict 'refs';
    local *{ $self->{class} . '::fieldToXML'};
    *{ $self->{class} . '::fieldToXML'} =
      sub {
	  push @fieldtoxml_args, [@_];
	  return 'a tag';
      };
    use strict 'refs';

    $mock->set_always ( -get_storage => $mock );
    $mock->set_always ( -getId => 1 );
    $mock->set_always ( -type_title => 'a_type' );
    $mock->set_always(getNodeByIdNew => { key1 => 'value1', key2 => 'value2'} );
    $mock->fake_new('XML::DOM::Document');
    $mock->fake_new('XML::DOM::Text');
    $mock->fake_new('XML::DOM::Element');
    $mock->fake_new('XML::DOM::Element');

    $mock->set_true('-setAttribute', '-appendChild');
    $mock->set_always('toString', 'a string of xml');

    is ($instance->toXML, 'a string of xml', '...should return XML.');

    my ($method, $args) = $mock->next_call( );

    is($method, 'getNodeByIdNew', '...should get exportable keys from node object.');

    is_deeply ( $fieldtoxml_args[0], [$instance, $mock, 'key1', '  '], '...calls fieldToXML with arguments.');

}

1;
