package Everything::HTML::Test::FormObject;

use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use base 'Everything::Test::Abstract';
use Scalar::Util qw/blessed/;
use CGI;
use SUPER;
use base 'Test::Class';
use strict;
use warnings;

sub startup : Test(startup => +0) {
    my $self = shift;

    # Unfortunately this imports stuff from Everything.pm.
    my $mock = Test::MockObject->new;
    $self->{mock}  = $mock;
    $self->setup_globals;
    $self->setup_mocks;
    my $module = $self->module_class();
    use_ok($module) or exit;
    $self->{class} = $module;


}

sub setup_mocks {
    my $self = shift;
    $self->{mock}->fake_module('Everything');

}

sub setup_globals {
    my $self = shift;
    no strict 'refs';
    *{ $self->package_under_test(__PACKAGE__) . '::DB' } = \$self->{mock};
    use strict 'refs';

}

sub package_under_test
{
	my ($self, $this_package) =  @_;
	$this_package    =~ s/Test:://;
	return $this_package;
}

sub test_new : Test(startup => 3) {
    my $self     = shift;
    my $instance = $self->{class}->new;
    isa_ok( $instance, $self->{class} );
    ( my $object_name ) = $self->{class} =~ /::(\w+)$/;
    is( $instance->{objectName},
        $object_name, '...the object name should be correct.' );
    is( $instance->{updateExecuteOrder},
        50, '...with the update execute order properly set.' );

}

sub fixture : Test(setup) {
    my $self = shift;
    $self->{instance} = $self->{class}->new;
    $self->{node}     = Test::MockObject->new;
    $self->{mock}->clear;
}

sub test_gen_bind_field : Test(3) {
    my $self     = shift;
    my $instance = $self->{instance};
    my $cgi      = CGI->new;
    my $node     = $self->{node};
    can_ok( $self->{class}, 'genBindField' );

    ## Test no $node passed
    is( $instance->genBindField( $cgi, undef ),
        '', '...should return an empty string with no node object' );

    ## passing a node and field
    $node->{node_id} = 222;
    is(
        $instance->genBindField( $cgi, $node, 'foo', 'foobar' ),
'<input type="hidden" name="formbind_' . $instance->{objectName} . '_foobar" value="50:222:foo"  />',
        '...should return html'
    );
}

sub test_gen_object : Test(2) {
    my $self     = shift;
    my $instance = $self->{instance};
    ## we are assuming that Everything::getParamArray behaves as advertised
    no strict 'refs';
    my $cgi = CGI->new;
    local *{ $self->package_under_test(__PACKAGE__) . '::getParamArray' } = sub { $cgi, @_ };
    use strict 'refs';
    can_ok( $self->{class}, 'genObject' );
    is(
        $instance->genObject(qw/one two three/),
'<input type="hidden" name="formbind_' . $instance->{objectName} . '_two" value="50::one"  />',
        '...returns html.'
    );

}

sub test_cgi_verify : Test(4) {
    my $self = shift;
    my $mock = $self->{mock};
    my $node = $self->{node};
    can_ok( $self->{class}, 'cgiVerify' ) || return "Can't cgiVerify";
    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    $instance->set_series( 'getBindNode', undef, $node, $node );
    is_deeply( $instance->cgiVerify, {},
        '...should return empty array if can\'t retrieve a node' );

    $node->set_series( 'hasAccess', 0, 1 );
    $node->set_always( 'getId', 222 );
    is_deeply(
        $instance->cgiVerify,
        { node => 222, failed => 'User does not have permission' },
'...should return a hash with failure measure, if user does not have permission'
    );
    is_deeply(
        $instance->cgiVerify,
        { node => 222 },
        '...should return a hash with node id, if user has permission.'
    );
}

sub test_cgi_update : Test(13) {
    my $self = shift;
    can_ok( $self->{class}, 'cgiUpdate' ) || return "Can't cgiUpdate";

    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    $instance->set_always( 'getBindField', 'foo' );

    my $cgi = CGI->new;
    $cgi->param( 'foo', 'bar' );

    my $node = $self->{node};
    $node->set_series( 'verifyFieldUpdate', 0, 1, 1, 1, 1 );

    ## permission denied tests
    is( $instance->cgiUpdate( $cgi, 'foo', $node ),
        0, '...returns 0 if update permission denied' );
    my ( $method, $args ) = $node->next_call;
    is( $method, 'verifyFieldUpdate', '...and calls verifyFieldUpdate' );

    ## permission allowed tests

    is( $instance->cgiUpdate( $cgi, 'foo', $node ),
        1, '...returns 1 if update permission allowed' );

    ( $method, $args ) = $node->next_call;

    is( $method, 'verifyFieldUpdate', '...and calls verifyFieldUpdate' );
    is( $node->{foo}, 'bar', '...and sets foo to bar' );

    ## tests with vars
    delete $$node{foo};
    $node->set_always( 'getHash', { one => 'two' } );
    $node->set_true('setHash');
    $instance->set_always( 'getBindField', 'attribute_name::var_name' );
    is( $instance->cgiUpdate( $cgi, 'foo', $node ),
        1, '...returns 1 if update permission allowed' );
    ( $method, $args ) = $node->next_call;
    is( $method, 'verifyFieldUpdate', '...again checks permissions' );
    ( $method, $args ) = $node->next_call;
    is( $method, 'getHash',
        '....should call getHash when updating a node with vars.' );
    is( $args->[1], 'attribute_name',
        '....should pass field name to  getHash.' );

    ( $method, $args ) = $node->next_call;
    is( $method, 'setHash', '...then calls setHash' );

    is_deeply(
        $args->[1],
        { one => 'two', 'var_name' => 'bar' },
        '...with a hash argument.'
    );
    is( $args->[2], 'attribute_name',
        '...with the second argument the field name' );

}

sub test_get_bind_node : Test(7) {
    my $self = shift;
    can_ok( $self->{class}, 'getBindNode' )
      || return "getBindNode not implemented.";
    my $instance = $self->{instance};
    my $node     = $self->{node};
    my $mock     = $self->{mock};       # mock was setup in startup
    $mock->set_always( 'getNode', $node );
    my $cgi = CGI->new;
    $cgi->param( 'formbind_' . $instance->{objectName} . '_' . 'foo',
        '50:bar:' );
    is( $instance->getBindNode( $cgi, 'foo' ),
        $node, '...returns a node object.' );
    my ( $method, $args ) = $mock->next_call;
    is( $method, 'getNode', '...should call getNode.' );
    is( $args->[1], 'bar', '...with a node_id.' );

    ## test new fields
    $cgi->param( 'formbind_' . $instance->{objectName} . '_' . 'foo',
        '50:new:' );
    $cgi->param( 'node_id', 999 );
    $mock->clear;
    is( $instance->getBindNode( $cgi, 'foo' ),
        $node, '...returns a node object again.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'getNode', '...should call getNode.' );
    is( $args->[1], 999, '...with a node_id taken from the cgi object.' );

}

sub test_get_bind_field : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'getBindField' )
      || return "getBindField not implemented.";

    my $instance = $self->{instance};
    my $cgi      = CGI->new;
    is( $instance->getBindField( $cgi, 'gale' ),
        undef, '...returns undef if no field exists.' );

    $cgi->param( 'formbind_' . $instance->{objectName} . '_' . 'grah',
        '40:foo:blah' );
    is( $instance->getBindField( $cgi, 'grah' ),
        'blah', '...otherwise returns the field name.' );

}

1;
