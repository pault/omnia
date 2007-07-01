package Everything::HTTP::Test::URLLink;

use Test::More;
use base 'Test::Class';
use Test::MockObject;
use Test::MockObject::Extends;
use Scalar::Util 'blessed';
use strict;
use warnings;

sub startup : Test(startup => 2) {
    my $self = shift;
    my $class = $self->module_class;
    $self->{class} = $class;
    use_ok ($class);
    can_ok ($class, 'new');


}

sub startup_attributes : Test(startup => 4) {
    my $self = shift;
    foreach (qw/subs default_sub/) {
	can_ok ($self->{class}, "get_$_");
	can_ok ($self->{class}, "set_$_");
    }


}

sub setup : Test(setup) {
    my $self = shift;
    $self->{instance} = $self->{class}->new;
    $self->{mock} = Test::MockObject->new;
}


sub module_class
{
        my $self =  shift;
        my $name =  blessed( $self );
        $name    =~ s/Test:://;
        return $name;
}

sub test_create_nodetype_rule : Test(6) {
    my $self = shift;
    my $instance = Test::MockObject::Extends->new($self->{instance});
    can_ok($self->{class}, 'create_nodetype_rule') || return;


    my $node = $self->{mock};

    $node->{DB}=$self->{mock};
    $instance->set_always('get_e', $node);
    $node->set_always('get_db', $node);
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

    is ($nodetype_rule->($node), 'for real', '...should run the code if our node conforms.');
    $node->{title} = "differentname";
    is ($nodetype_rule->($node), undef, '...and return undef when it does not.');
    is ($instance->get_subs->[-1], $nodetype_rule, '...and add it to the subs.')
}

sub test_create_linknode : Test(3) {
    my $self = shift;
    my $instance = $self->{instance};
    can_ok($self->{class}, 'create_linknode') || return;
    my $sub;
    ok($sub = $instance->create_linknode, '...should return a true value');
    is(ref $sub, 'CODE', '...which is a code ref');
    
}

sub test_set_default : Test(3) {
    my ($self) = @_;
    my $instance = $self->{instance};
    can_ok($self->{class}, 'set_default') || return;
    local *Foo::linkNode = sub { "linked node"};
    ok ($instance->set_default('Foo'));
    no warnings 'redefine';
    *Foo::linkNode = sub {"wrong one"};
    is($instance->get_default_sub->(), "linked node", '...executes the correct linkNode');

}

1;
