package Everything::Test::Node;

use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Scalar::Util qw/blessed/;
use base 'Test::Class';
use strict;
use warnings;

BEGIN {
    Test::MockObject->fake_module('Everything::Util');
    Test::MockObject->fake_module('XML::Dom');
}

sub module_class {
    my $self = shift;
    my $name = blessed($self);
    $name =~ s/Test:://;
    return $name;
}

sub startup : Test(startup => 1) {
    my $self = shift;

    $self->{class} = $self->module_class;

    $self->{errors} = [];
    my $mock = Test::MockObject->new();
    $mock->fake_module(
        'Everything',
        logErrors => sub {
            push @{ $self->{errors} }, [@_];
        }
    );

    $self->{mock} = $mock;

    use_ok( $self->{class} ) || exit;

}

sub make_fixture : Test(setup) {
    my $self = shift;
    $self->{instance} = bless {}, $self->{class};
    $self->{instance}->{DB} = Test::MockObject->new;

}

sub test_new : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'new' ) or return;

}

sub test_DESTROY : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'DESTROY' ) or return;

}

sub test_get_id : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getId' ) or return;

}

sub test_get_node_method : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getNodeMethod' ) or return;

}

sub test_get_clone : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getClone' ) or return;

}

sub test_assign_type : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'assignType' ) or return;

}

sub test_cache : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'cache' ) or return;

}

sub test_remove_from_cache : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'removeFromCache' ) or return;

}

sub test_quote_field : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'quoteField' ) or return;

}

sub test_is_of_type : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'isOfType' ) or return;

}

sub test_has_access : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'hasAccess' ) or return;

}

sub test_get_user_permissions : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getUserPermissions' ) or return;

}

sub test_get_user_relation : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getUserRelation' ) or return;

}

sub test_derive_usergroup : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'deriveUsergroup' ) or return;

}

sub test_get_default_permissions : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getDefaultPermissions' ) or return;

}

sub test_get_dynamic_permissions : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getDynamicPermissions' ) or return;

}

sub test_lock : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'lock' ) or return;

}

sub test_unlock : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'unlock' ) or return;

}

sub test_update_links : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'updateLinks' ) or return;

}

sub test_update_hits : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'updateHits' ) or return;

}

sub test_select_links : Test(6) {
    my $self     = shift;
    my $instance = $self->{instance};
    can_ok( $self->{class}, 'selectLinks' ) or return;

    $instance->{node_id} = 11;
    my $DB = $instance->{DB};

    $DB->set_series( sqlSelectMany => undef, $DB )
      ->set_series( fetchrow_hashref => 'bar', 'baz' )->set_true('finish')
      ->clear();

    my $result = $instance->selectLinks();
    my ( $method, $args ) = $DB->next_call();
    is( $method, 'sqlSelectMany',
        'selectLinks() should select from the database' );
    is( join( '-', ( @$args[ 1 .. 4 ], @{ $args->[5] } ) ),
        "*-links-from_node=?--11", '... from links table for node_id' );
    is( $result, undef, '... returning if that fails' );

    is_deeply(
        $instance->selectLinks('order'),
        [ 'bar', 'baz' ],
        '... returning an array reference of results'
    );
    ( $method, $args ) = $DB->next_call();
    like( $args->[4], qr/ORDER BY order/, '... respecting order parameter' );

}

sub test_get_tables : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getTables' ) or return;

}

sub test_get_hash : Test(8) {
    my $self = shift;
    can_ok( $self->{class}, 'getHash' ) or return;
    my $instance = $self->{instance};

    $instance->{hash_field} = 'stored';
    is( $instance->getHash('field'),
        'stored', 'getHash() should return stored hash if it exists' );

    $instance->{node_id} = 11;
    $instance->{title}   = 'title';

    is( $instance->getHash('nofield'),
        undef, '... returning nothing if field does not exist' );
    is( @{ $self->{errors} }, 1, '... logging a warning' );
    like(
        $self->{errors}->[0]->[0],
        qr/nofield.+does not exist.+11.+title/,
        '... with the appropriate message'
    );

    $instance->{falsefield} = 0;
    is_deeply( $instance->getHash('falsefield'),
        {}, '... returning hash even if value is false' );

    $instance->{realfield} = 'foo=bar&baz=quux&blat= ';

    my $result;
    {
        local *Everything::Util::unescape;
        *Everything::Util::unescape = sub { reverse $_[0] };
        $result = $instance->getHash('realfield');
    }

    is_deeply(
        $result,
        {
            foo  => 'rab',
            baz  => 'xuuq',
            blat => '',
        },
        '... returning hash reference of stored parameters'
    );

    is( $instance->{hash_realfield}, $result, '... and caching it in node' );

}

sub test_set_hash : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'setHash' ) or return;

}

sub test_get_node_database_hash : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getNodeDatabaseHash' ) || return;

}

sub test_is_nodetype : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'isNodetype' ) || return;

}

sub test_get_parent_location : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getParentLocation' ) || return;

}


sub test_existing_node_matches : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'existingNodeMatches' ) || return;

}

1;
