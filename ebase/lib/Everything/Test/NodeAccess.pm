package Everything::Test::NodeAccess;

use Test::More;
use Test::MockObject;
use strict;
use warnings;

use base 'Everything::Test::Abstract';


sub fixture :Test(setup) {

    my $self = shift;
    my $instance = $self->{class}->new;
    $instance->set_node( Test::MockObject->new );
    $self->{instance} = $instance;
}

sub test_usergroup: Test(3) {

    my $self = shift;
    return "Not implemented" unless $self->{class}->can('determine_usergroup');
    my $i = $self->{instance};
    $i->get_node->set_always( get_group_usergroup => 4 );
    is( $i->determine_usergroup, 4, '...returns usergroup if set in node.' );

    $i->get_node->set_always( get_group_usergroup => undef );

    $i->set_type_hierarchy( [ { defaultgroup_usergroup => -1 },  { defaultgroup_usergroup => 5 }, { defaultgroup_usergroup => 2 } ] );

    is( $i->determine_usergroup, 5, '...chooses user group.' );

    $i->get_node->set_always( get_group_usergroup => -1 );

    is( $i->determine_usergroup, 5, '...chooses user group.' );

}

sub test_permission: Test(3) {

    my $self = shift;
    return "Not implemented" unless $self->{class}->can('permission');
    $TODO = "Not implemented";
    my $i = $self->instance;

    

}


sub test_user_permissions : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'user_permissions' ) or return;

}

sub test_get_user_relation : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'getUserRelation' ) or return;

}

sub test_derive_usergroup : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'deriveUsergroup' ) or return;

}

sub test_default_accesses : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'default_accesses' ) or return;

}

sub test_dynamic_permissions : Test(1) {
    my $self = shift;
    can_ok( $self->{class}, 'dynamic_permissions' ) or return;

}

1;
