package Everything::Config::Test::URL;


use strict;
use Test::Exception;
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Scalar::Util 'blessed';


use base 'Test::Class';


sub module_class
{
        my $self =  shift;
        my $name =  blessed( $self );
        $name    =~ s/Test:://;
        return $name;
}


sub startup : Test(startup => 3) {
    my $self = shift;
    my $class = $self->module_class();
    my $mock = Test::MockObject->new;
    $self->{mock} = $mock;
    $self->{class} = $class;
    use_ok($class) or die;
    can_ok($class, 'new');
    my $instance = $class->new;
    isa_ok($instance, $class) || exit;
    $self->{instance} = $instance;

}



sub test_create_nodetype_rule : Test(5) {
    my $self = shift;
    my $instance = Test::MockObject::Extends->new($self->{instance});
    can_ok($self->{class}, 'create_nodetype_rule') || return;


    my $node = $self->{mock};

    $node->set_always('get_nodebase', $node);
    $node->set_always('getNode', $node);
    $node->{type} = $node;
    my $nodetype_name = 'nodetypename';
    $node->{title} = $nodetype_name;
    my $sub = sub {'for real'};
    ### takes a code ref, node, nodename as arguments
    my $nodetype_rule;
    ok ($nodetype_rule = $instance->create_nodetype_rule($sub, $nodetype_name),
	'...should run nodetype rule');

    is (ref $nodetype_rule, 'CODE', '...and return a code ref.');
    $node->set_series('getType', {title => 'nodetypename'}, {title => 'notnodetypename'});

    my $obj = bless {}, 'Everything::Node::nodetypename';
    is ($nodetype_rule->($obj), 'for real', '...should run the code if our node conforms.');
    $node->{title} = "differentname";
    is ($nodetype_rule->($node), undef, '...and return undef when it does not.');

}

1;
