package Everything::NodeBase::Test::Cached;

use strict;
use warnings;

use Test::More;
use Test::MockObject;
use base 'Everything::Test::NodeBase';

sub test_update_workspaced :Test(+1) {

    my $self = shift;

    my $fake_cache = Test::MockObject->new;
    local $self->{ nb }->{ cache } = $fake_cache;

    $fake_cache->set_true('removeNode');
    $self->SUPER::test_update_workspaced( @_ );


    my ( $method, $args ) = $fake_cache->next_call();

    is( "$method $args->[0]", "removeNode $fake_cache",
	'... removing node from cache' );
}

sub test_reset_node_cache :Test( 1 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	$storage->set_true( 'resetCache' );
	$nb->{cache} = $storage;

	$nb->resetNodeCache();
	is( $storage->next_call(), 'resetCache',
		'resetNodeCache() should call resetCache() on cache' );
}

sub test_get_cache :Test( 1 )
{
	my $self     = shift;
	my $nb       = $self->{nb};
	$nb->{cache} = 'cache';

	is( $nb->getCache(), 'cache', 'getCache() should return cache' );
}

1;
