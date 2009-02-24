package Everything::Test::NodeCache;

use Test::More;
use Test::MockObject;
use Scalar::Util qw/blessed/;
use base 'Everything::Test::Abstract';
use strict;
use warnings;


sub startup :Test(startup => +0) {
    my $self = shift;
    $self->SUPER;
    my $class = $self->{class};
    my $file;
    ($file = $class) =~ s/::/\//g;

    $file .= '.pm';

    require $file;
    $class->import;
    $self->{mock} = Test::MockObject->new;
}


sub test_set_cache_size : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'setCacheSize' );

}

sub test_get_cache_size : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'getCacheSize' );

}

sub test_get_cached_node_by_name : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'getCachedNodeByName' );
}

sub test_get_cached_node_by_id : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'getCachedNodeById' );

}

sub test_cache_node : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'cacheNode' );

}

sub test_remove_node : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'removeNode' );

}

sub test_flush_cache : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'flushCache' );
}

sub test_flush_cache_global : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'flushCacheGlobal' );
}

sub test_dump_cache : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'dumpCache' );
}

sub test_purge_cache : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'purgeCache' );
}

sub test_remove_node_from_hash : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'removeNodeFromHash' );
}

sub test_get_global_version : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'getGlobalVersion' );
}

sub test_is_same_version : Test(9)
{
    my $self = shift;
    my $package = $self->{class};
    my $mock = $self->{mock};
    can_ok( $package, 'isSameVersion' );
    is( Everything::NodeCache::isSameVersion(), undef,
    'isSameVersion() should return undef without node' );

    $mock->{version}{12}      = 1;
    $mock->{verified}{11}     = 1;
    $mock->{typeVerified}{10} = 1;

    my $node = Test::MockObject->new;
    $node->{node_id} = 11;
    $node->set_always( type => $mock );

    $mock->set_always( getId => 11 );
    ok( Everything::NodeCache::isSameVersion( $mock, $node ), '... true if node type is verified' );

    $node->{node_id} = 11;
    ok( Everything::NodeCache::isSameVersion( $mock, $node ), '... true if node id is verified' );

    $node->{node_id} = 13;
    ok( ! Everything::NodeCache::isSameVersion( $mock, $node ),
	'... false unless node version is verified' );

    $node->{node_id} = 12;
    $mock->set_series( getGlobalVersion => undef, 2, 1 );
    ok( ! Everything::NodeCache::isSameVersion( $mock, $node ),
	'... false unless node has global version' );
    ok( ! Everything::NodeCache::isSameVersion( $mock, $node ), '... false unless global version matches' );
    ok( Everything::NodeCache::isSameVersion( $mock, $node ), '... true if global version matches' );
    ok( $mock->{verified}{12}, '... setting verified flag' );


}

sub test_increment_global_version : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'incrementGlobalVersion' );

}

sub test_reset_cache : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'resetCache' );
}

sub test_cache_method : Test(1)
{
    my $self = shift;
    my $package = $self->{class};
    can_ok( $package, 'cacheMethod' );

}

1;
