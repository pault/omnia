package Everything::HTML::FormObject::Test::FormMenu;

use base 'Everything::HTML::Test::FormObject';
use Test::More;
use Scalar::Util qw/blessed/;
use base 'Test::Class';
use SUPER;
use strict;
use warnings;


sub test_get_values_array : Test(3)
{
    my $self = shift;
    can_ok($self->{class}, 'getValuesArray') || return 'getValuesArray not implemented.';
    my $instance = $self->{instance};
    is_deeply ($instance->getValuesArray, [], '...should return and empty array ref if no values.');

    my $values = [qw/one two/];
    $instance->{VALUES} = $values;
        is_deeply ($instance->getValuesArray, $values, '...should return the VALUES attribute if exists.');


}

sub test_get_labels_hash : Test(3)
{
    my $self = shift;
    can_ok($self->{class}, 'getLabelsHash') || return 'getLabelsHash not implemented.';
    my $instance = $self->{instance};
    is_deeply ($instance->getLabelsHash, {}, '...should return and empty stringif no values.');

    my $values = {one => 'two'};
    $instance->{LABELS} = $values;
        is_deeply ($instance->getLabelsHash, $values, '...should return the LABELS attribute if exists.');


}

sub test_clear_menu : Test(3)
{
    my $self = shift;
    can_ok($self->{class}, 'clearMenu') || return 'clearMenu not implemented.';
    my $instance = $self->{instance};
    $instance->{VALUES} = [qw/one two three/];
    $instance->{LABELS} = {four => 'five'};
    $instance->clearMenu;
    is_deeply($instance->{VALUES}, [], '...should clear VALUES array ref');
    is_deeply($instance->{LABELS}, {}, '...should clear LABELS hash ref');

}

sub test_sort_menu : Test(1)
{
    my $self = shift;
    can_ok($self->{class}, 'sortMenu') || return 'sortMenu not implemented.';
    my $instance = $self->{instance};


}

sub test_remove_items : Test(1)
{
    my $self = shift;
    can_ok($self->{class}, 'removeItems') || return 'removeItems not implemented.';
    my $instance = $self->{instance};


}

sub test_add_type : Test(1)
{
    my $self = shift;
    can_ok($self->{class}, 'addType') || return 'addType not implemented.';
    my $instance = $self->{instance};


}

sub test_add_group : Test(1)
{
    my $self = shift;
    can_ok($self->{class}, 'addGroup') || return 'addGroup not implemented.';
    my $instance = $self->{instance};


}

sub test_add_hash : Test(1)
{
    my $self = shift;
    can_ok($self->{class}, 'addHash') || return 'addHash not implemented.';
    my $instance = $self->{instance};


}

sub test_add_array : Test(1)
{
    my $self = shift;
    can_ok($self->{class}, 'addArray') || return 'addArray not implemented.';
    my $instance = $self->{instance};


}

sub test_add_labels : Test(1)
{
    my $self = shift;
    can_ok($self->{class}, 'addLabels') || return 'addLabels not implemented.';
    my $instance = $self->{instance};


}

sub test_gen_popup_menu : Test(1)
{
    my $self = shift;
    can_ok($self->{class}, 'genPopupMenu') || return 'genPopupMenu not implemented.';
    my $instance = $self->{instance};


}

sub test_gen_list_menu : Test(1)
{
    my $self = shift;
    can_ok($self->{class}, 'genListMenu') || return 'genListMenu not implemented.';
    my $instance = $self->{instance};


}

sub test_gen_object : Test(+0)
{
    my $self = shift;
    $self->SUPER;
    my $instance = $self->{instance};


}

1;
