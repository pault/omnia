package Everything::Test::CacheQueue;

use base 'Everything::Test::Abstract';
use Test::More;
use Test::MockObject;
use strict;
use warnings;

sub startup : Test(startup => +0) {
    my $self = shift;

    my $mock = Test::MockObject->new;
    my $import;

    $self->SUPER;
    my $class = $self->{class};
    my $file;
    ( $file = $class ) =~ s/::/\//g;

    $file .= '.pm';

    require $file;
    $class->import;

}

sub setup : Test(setup) {
    my $self = shift;
    $self->{mock} = Test::MockObject->new;

}

sub test_new : Test(startup => 7) {
    my $self = shift;

    local *Everything::CacheQueue::createQueueData;
    *Everything::CacheQueue::createQueueData = sub {
        return { id => $_[1] };
    };

    my $cq = Everything::CacheQueue->new();
    isa_ok( $cq, 'Everything::CacheQueue' );
    is( $cq->{queueHead}{id}, 'HEAD', 'new() should create head queue data' );
    is( $cq->{queueTail}{id}, 'TAIL', '... and tail queue data' );
    is( $cq->{queueHead}{prev}{id}, 'TAIL', '... pointing head prev to tail' );
    is( $cq->{queueTail}{next}{id}, 'HEAD', '... and tail next to head' );
    is( $cq->{queueSize},           0,      '... and queueSize should be 0' );
    is( $cq->{numPermanent}, 0, '... and numPermanent should be 0' );

}

sub test_queue_item : Test(4) {

    my $self = shift;

    my $node = $self->{mock};
    $node->set_always( 'createQueueData', ['queued'] );
    $node->mock(
        'queueData',
        sub {
            my $ref = $_[1];
            $_[1] = join '', @{$ref};
        }
    );

    is( Everything::CacheQueue::queueItem( $node, 'foo', 1 ),
        'queued', 'queueItem() should return queued data' );
    my ( $method, $args ) = $node->next_call;
    shift @{$args};
    is(
        join( ' ', $method, @{$args} ),
        'createQueueData foo 1',
        '... calling createQueueData with item and permanent flag'
    );

    ( $method, $args ) = $node->next_call;

    is( $method, 'queueData', '...calls queueData' );
    is_deeply( $args->[1], ['queued'], '...with correct argument.' );

}

sub test_get_item : Test(3) {
    my $self = shift;

    my $node = $self->{mock};

    my $data = { item => 'foo' };
    $node->set_true( 'removeData', 'queueData' );
    is( Everything::CacheQueue::getItem( $node, $data ),
        'foo', 'getItem() should return cached item' );
    my ( $method, $args ) = $node->next_call;
    is(
        join( ' ', $method, @{$args}[ 1 .. $#$args ] ),
        "removeData $data",
        '... removing it from the queue'
    );
    ( $method, $args ) = $node->next_call;
    is(
        join( ' ', $method, @{$args}[ 1 .. $#$args ] ),
        "queueData $data",
        '... and queueing it again'
    );

}

sub test_get_next_item : Test(4) {

    my $self = shift;
    my $node = $self->{mock};
    $node->set_true( 'removeData', 'queueData' );
    my $queue = {};
    $queue->{prev}     = $node;
    $node->{queueHead} = $queue;
    $node->{item}      = 'foo';

    is( Everything::CacheQueue::getNextItem($node),
        'foo', 'getNextItem() should return first item in queue' );

    my ( $method, $args ) = $node->next_call;
    is(
        join( ' ', $method, @{$args}[ 1 .. $#$args ] ),
        "removeData $node",
        '... and should call removeData() on item'
    );

    $node->mock(
        'queueData',
        sub {
            push @{ $_[0]->{_calls} }, ['queueData'];
            $_[0]{queueHead}{prev} = {
                item      => 'bar',
                permanent => 0,
            };
        }
    );

    $node->{queueHead}{prev}{permanent} = 1;
    $node->{_calls} = [];

    is( Everything::CacheQueue::getNextItem($node),
        'bar', '... should skip nodes with permanent flag' );

    $method = $node->next_call;
    $args   = $node->next_call;
    is(
        join( ' ', $method, $args ),
        'removeData queueData',
        '... and should requeue permanently cached items'
    );
}

sub test_get_size : Test(1) {
    my $self = shift;
    my $node = $self->{mock};
    $node->{queueSize} = 41;
    is( Everything::CacheQueue::getSize($node),
        41, 'getSize() should return queue size' );

}

sub test_remove_item : Test(3) {
    my $self = shift;
    my $node = $self->{mock};

    $node->set_true('removeData');
    is( Everything::CacheQueue::removeItem($node),
        undef, 'removeItem() should return undef if data is undefined' );
    my $data = { item => 'bar' };
    is( Everything::CacheQueue::removeItem( $node, $data ),
        'bar', '... should return queued item' );
    my ( $method, $args ) = $node->next_call;
    is(
        join( ' ', $method, $args->[1] ),
        "removeData $data",
        '... and should call removeData() on it'
    );

}

sub test_list_items : Test(3) {
    my $self = shift;
    my $node = $self->{mock};
    $node->{queueTail}{next} = {
        item => 'first',
        next => {
            item => 'second',
            next => { item => 'HEAD' }
        },
    };

    my $list = Everything::CacheQueue::listItems($node);
    isa_ok( $list, 'ARRAY', 'listItems() should return an array reference' );
    is( scalar @$list, 2, '... of the correct number of items' );
    is( "@$list", 'first second', '... in the correct order (last first)' );
}

sub test_queue_data : Test(2) {
    my $self = shift;
    my $node = $self->{mock};
    $node->set_true('insertData');
    $node->{numPermanent} = 0;
    $node->{queueTail}    = 'tail';
    my $data = {};
    Everything::CacheQueue::queueData( $node, $data );

    my ( $method, $args ) = $node->next_call;
    is(
        join( ' ', $method, @{$args}[ 1 .. $#$args ] ),
        "insertData $data tail",
        'queueData() should call insertData() with data and cache tail'
    );

    $data->{permanent} = 1;
    Everything::CacheQueue::queueData( $node, $data );
    is( $node->{numPermanent}, 1,
        '... and should increment numPermanent only for permanent data' );

}

sub test_insert_data : Test(5) {
    my $self   = shift;
    my $node   = $self->{mock};
    my $data   = {};
    my $after  = { id => 'before next' };
    my $before = { next => $after };
    $node->{queueSize} = 6;

    Everything::CacheQueue::insertData( $node, $data, $before );
    is( $data->{next}{id},
        'before next', 'insertData() should set data next to before next' );
    is( $data->{prev},      $before, '... and its previous to before' );
    is( $before->{next},    $data,   '... and before next to data' );
    is( $after->{prev},     $data,   '... and before next prev to data' );
    is( $node->{queueSize}, 7,       '... and should increment queueSize' );
}

sub test_remove_data : Test(7) {

    my $self = shift;
    my $node = $self->{mock};

    local *removeData = \&Everything::CacheQueue::removeData;

    my $data = {
        next => 0,
        prev => 0,
    };

    $node->{queueSize} = 0;
    is( removeData($node), undef,
        'removeData() should return with nothing in queue' );

    $node->{queueSize}    = 4;
    $node->{numPermanent} = 6;

    is( removeData( $node, $data ),
        undef, '... or if data has already been removed from queue' );

    my $next = { prev => 1, };

    my $prev = { next => 1, };

    $data = {
        next      => $next,
        prev      => $prev,
        permanent => 0,
    };

    removeData( $node, $data );
    is( $next->{prev}, $prev, '... should set next prev to previous' );
    is( $prev->{next}, $next, '... should set prev next to next' );

    is( join( ' ', @$data{qw( next prev )} ),
        '0 0', '... and should set next and prev in data to 0' );

    is( $node->{queueSize}, 3, '... and reduce queueSize' );

    $data = {
        next      => $next,
        prev      => $prev,
        permanent => 1,
    };
    removeData( $node, $data );
    is( $node->{numPermanent}, 5,
        '... but should reduce numPermanent only when removing permanent item'
    );
}

sub test_create_queue_data : Test(5) {
    my $self = shift;
    my $node = $self->{mock};
    local *cqd = \&Everything::CacheQueue::createQueueData;

    my $queued = cqd( $node, 'foo' );
    isa_ok( $queued, 'HASH', 'createQueueData() should return a hashref' );

    is( $queued->{item}, 'foo', '... storing data in "item" slot' );
    is( join( ' ', @$queued{qw( next prev )} ),
        '0 0', '... setting "next" and "prev" slots both to 0' );
    is( $queued->{permanent}, 0, '... vivifying "permanent" to 0 if needed' );

    is( cqd( $node, 'foo', 1 )->{permanent},
        1, '... but should respect passed "permanent" flag' );
}

1;
