package Everything::Test;

use base 'Everything::Test::Abstract';
use Scalar::Util 'blessed';
use TieOut;
use Test::More;
use Test::MockObject;
use File::Spec;
use File::Temp;
use IO::File;
use SUPER;
use strict;
use warnings;

BEGIN {

    ## This is required because Everything.pm reads the log file name
    ## from %ENV and copies it to a lexical. So we need to set it up
    ## %ENV before Everything.pm is 'required'. Everything.pm
    ## effectively creates a closure and we can no longer access the
    ## log file name.

    ## XXXX - This "feature" must be changed so we can amend the log
    ## file at run time, preferably in a way that uses encapsulation
    ## properly, i.e. using methods.

    ## THIS
    my $tmpdir = File::Spec->tmpdir;
    my $fh     = File::Temp->new(
        TEMPLATE => $$ . 'XXXXXXX',
        DIR      => $tmpdir,
        UNLINK   => 0
    );
    my $fname = $fh->filename;
    $ENV{EVERYTHING_LOG} = $fname;

    $fh->close;

}

BEGIN {
    ## needed so we can override CORE subs.
    *Everything::gmtime = sub { CORE::gmtime };
    *Everything::caller = sub { };
}

sub module_class {
    my $self = shift;
    my $name = blessed($self);
    $name =~ s/::Test//;
    return $name;
}

sub test_imported_subs : Test(7) {
    my $self = shift;

    for my $sub (
        qw(
        getNode getNodeById getType getNodeWhere selectNodeWhere getRef getId )
      )
    {
        can_ok( $self->{class}, $sub );
    }

}

sub test_getTime : Test(2) {
    my $self = shift;

    local *Everything::gmtime;
    *Everything::gmtime =
      sub { return wantarray ? ( 0 .. 6 ) : 'long time' };
    is(
        Everything::getTime(),
        '1905-05-03 02:01:00',
        'getTime() should format gmtime output nicely'
    );
    is( Everything::getTime(1), 'long time',
        '... respecting the long flag, if passed' );

}

sub test_getParamArray : Test(5) {
    my $self = shift;
    no strict 'refs';

    local *{ __PACKAGE__ . '::getParamArray' } =
      \&{ $self->{class} . '::getParamArray' };
    my $order   = 'red, blue, one , two';
    my @results = getParamArray( $order, qw( one two red blue ) );
    my @args    = ( -one => 1, -two => 2, -red => 'red', -blue => 'blue' );
    is( @results, 4, 'getParamArray() should return array params unchanged' );

    @results = getParamArray( $order, @args );
    is( @results, 4, '... and the right number of args in hash mode' );

    # now ask for a repeated parameter
    @results = getParamArray( $order . ', one', @args );
    is( @results, 5, '... (even when being tricky)' );
    is( join( '', @results ), 'redblue121', '... the values in hash mode' );

    # and leave out some parameters
    is( join( '', getParamArray( 'red,blue', @args ) ),
        'redblue', '... and only the requested values' );
}

sub test_cleanLinks : Test(3) {
    my $self = shift;

    my $mock = Test::MockObject->new();
    $mock->set_always( 'sqlSelectJoined', $mock )->set_series(
        'fetchrow_hashref',
        { node_id => 1 },
        { to_node => 8 },
        0,
        { node_id => 2, to_node => 9 },
        { to_node => 10 }
    )->set_true('sqlDelete');

    local *Everything::DB;
    *Everything::DB = \$mock;

    Everything::cleanLinks();

    my @expect = ( to_node => 8, from_node => 10 );
    my $count;

    while ( my ( $method, $args ) = $mock->next_call() ) {
        next unless $method eq 'sqlDelete';
        my $args = join( '-', $args->[1], $args->[2]->{ shift @expect } );
        is(
            $args,
            'links-' . shift @expect,
            'cleanLink() should delete bad links'
        );
        $count++;
    }

    is( $count, 2, '... and only bad links' );
}

sub test_initEverything : Test(8)

{
    my $self = shift;
    no strict 'refs';
    local *{ __PACKAGE__ . '::initEverything' } =
      \&{ $self->{class} . '::initEverything' };
    use strict 'refs';
    no warnings qw/redefine once/;
    local @Everything::fsErrors = '123';
    local @Everything::bsErrors = '321';
    local ( $Everything::DB, %Everything::NODEBASES );
    my $db = Test::MockObject->new;
    $db->fake_module('Everything::DB::mysql');

    local *Everything::NodeBase::getType              = sub { 0 };
    local *Everything::NodeBase::buildNodetypeModules = sub { undef };

    $db->fake_new('Everything::DB::mysql');
    $db->set_true( 'databaseConnect', 'getNodeByIdNew', 'getNodeByName' );
    initEverything( 'onedb', { staticNodetypes => 1 } );
    isa_ok( $Everything::DB, 'Everything::NodeBase' );
    is( @Everything::fsErrors, 0, '... and should clear @fsErrors' );
    is( @Everything::bsErrors, 0, '... and @bsErrors' );

    initEverything('onedb');
    is(
        $Everything::DB,
        $Everything::NODEBASES{onedb},
        '... should reuse NodeBase object with same DB requested'
    );

    initEverything('twodb');
    is( keys %Everything::NODEBASES, 2, '... and should cache objects' );

    eval { initEverything( 'threedb', { dbtype => 'badtype' } ) };
    like(
        $@,
        qr/Unknown database type 'badtype'/,
        '... dying given bad dbtype'
    );

    my $status;
    local @INC = 'lib';

    @INC = 'lib';
    $db->fake_module('Everything::DB::foo');
    $db->fake_new('Everything::DB::foo');

    eval { initEverything( 'foo', { dbtype => 'foo' } ) };
    is( $@, '', '... loading nodebase for requested database type' );
    ok( exists $Everything::NODEBASES{foo}, '... and caching it' );
}

sub test_clearFrontside : Test(1)

{
    my $self = shift;
    no strict 'refs';
    local *{ __PACKAGE__ . '::clearFrontside' } =
      \&{ $self->{class} . '::clearFrontside' };
    use strict 'refs';

    local @Everything::fsErrors = '123';
    clearFrontside();
    is( @Everything::fsErrors, 0, 'clearFrontside() should clear @fsErrors' );
}

sub test_clearBackside : Test(1) {
    my $self = shift;
    no strict 'refs';
    local *{ __PACKAGE__ . '::clearBackside' } =
      \&{ $self->{class} . '::clearBackside' };
    use strict 'refs';

    local @Everything::bsErrors = '123';
    clearBackside();
    is( @Everything::bsErrors, 0, 'clearBackside() should clear @bsErrors' );
}

sub test_logHash : Test(4) {
    my $self = shift;
    no strict 'refs';
    local *{ __PACKAGE__ . '::logHash' } = \&{ $self->{class} . '::logHash' };
    use strict 'refs';

    my $log;
    local *Everything::printLog;
    *Everything::printLog = sub {
        $log .= join( '', @_ );
    };

    my $hash = { foo => 'bar', boo => 'far' };
    ok( logHash($hash), 'logHash() should succeed' );

    # must quote the parenthesis in the stringified references
    like( $log, qr/\Q$hash\E/, '... and should log hash reference' );
    like( $log, qr/foo = bar/, '... and hash keys' );
    like( $log, qr/boo = far/, '... and hash keys (redux)' );
}

sub test_callLogStack : Test(2) {

    my $self = shift;
    no strict 'refs';
    local *{ __PACKAGE__ . '::logCallStack' } =
      \&{ $self->{class} . '::logCallStack' };
    use strict 'refs';

    my $log;
    local *Everything::printLog;
    *Everything::printLog = sub {
        $log .= join( '', @_ );
    };

    local *Everything::getCallStack;
    *Everything::getCallStack = sub {
        return ( 1 .. 10 );
    };

    Everything::logCallStack();
    like( $log, qr/^Call Stack:/, 'logCallStack() should print log' );
    like( $log, qr/9.8.7/s,
        '... and should report stack backwards, minus first element' );
}

sub test_getCallStack_dumpCallStack : Test(6) {
    my $self = shift;
    local *Everything::caller;
    *Everything::caller = sub {
        my $frame = shift;
        return if $frame >= 5;
        return ( 'Everything', 'everything.t', 100 + $frame, $frame,
            $frame % 2 );
    };

    my @stack = Everything::getCallStack();
    is( @stack, 4, 'getCallStack() should not report self' );

    is( $stack[0], 'everything.t:104:4',
        '... should report file, line, subname' );
    is( $stack[-1], 'everything.t:101:1',
        '... and report frames in reverse order' );
    local *STDOUT;
    my $out = tie *STDOUT, 'TieOut';
    Everything::dumpCallStack();

    my $stackdump = $out->read();
    like( $stackdump, qr/Start/, 'dumpCallStack() should print its output' );
    like( $stackdump, qr/102:2.+103:3.+104:4/s,
        '... should report stack in forward order' );
    ok( $stackdump !~ /101/, '... but should remove current frame' );
}

sub test_printErr : Test(2) {
    my $self = shift;
    no strict 'refs';
    local *{ __PACKAGE__ . '::printErr' } = \&{ $self->{class} . '::printErr' };
    use strict 'refs';

    local *STDERR;
    my $out = tie *STDERR, 'TieOut';
    printErr('error message');
    is( $out->read, 'error message', 'printErr() should print to STDERR' );
    printErr( 7, 6, 5 );
    is( $out->read, 7, '... and only the first parameter' );
}

sub test_logErrors : Test(7) {
    my $self = shift;
    no strict 'refs';
    local *{ __PACKAGE__ . '::logErrors' } =
      \&{ $self->{class} . '::logErrors' };
    use strict 'refs';

    local *STDOUT;
    my $out = tie *STDOUT, 'TieOut';
    is( logErrors(), undef,
        'logErrors() should return, lacking passed a warning or an error' );

    local $Everything::commandLine = 0;
    ok(
        logErrors( 'warning', undef, 'code', 'CONTEXT' ),
        '... and should succeed given a warning or an error'
    );

    is( join( '', sort values %{ $Everything::fsErrors[-1] } ),
        'CONTEXTcodewarning',
        '... should store message in @fsErrors normally' );
    logErrors( undef, 'error', 'code', 'CONTEXT' );
    is( join( '', sort values %{ $Everything::fsErrors[-1] } ),
        'CONTEXTcodeerror',
        '... should use blank string lacking a warning or error' );
    is( $$out, undef, '... and should not print unless $commandLine is true' );

    $Everything::commandLine = 1;
    logErrors( 'warn', 'error', 'code' );
    my $output = $out->read();

    like( $output, qr/^###/, '... should print if $commandLine is true' );
    like(
        $output,
        qr/Warning: warn.+Error: error.+Code: code/s,
        '... should print warning, error, and code'
    );
}

sub test_flushErrorsToBackside : Test(4) {
    my $self = shift;
    no strict 'refs';
    local *{ __PACKAGE__ . '::flushErrorsToBackside' } =
      \&{ $self->{class} . '::flushErrorsToBackside' };

    local *{ __PACKAGE__ . '::getFrontsideErrors' } =
      \&{ $self->{class} . '::getFrontsideErrors' };
    local *{ __PACKAGE__ . '::getBacksideErrors' } =
      \&{ $self->{class} . '::getBacksideErrors' };
    use strict 'refs';

    local ( @Everything::fsErrors, @Everything::bsErrors );

    @Everything::fsErrors = ( 1 .. 3 );
    @Everything::bsErrors = 'a';

    flushErrorsToBackside();
    is( join( '', @Everything::bsErrors ),
        'a123',
        'flushErrorsToBackside() should push @fsErrors onto @bsErrors' );
    is( @Everything::fsErrors, 0, '... should clear @fsErrors' );

    is( getFrontsideErrors(), \@Everything::fsErrors,
        'getFrontsideErrors() should return reference to @fsErrors' );
    is( getBacksideErrors(), \@Everything::bsErrors,
        'getBacksideErrors() should return reference to @bsErrors' );
}

sub test_searchNodeName : Test(12) {
    my $self = shift;
    local $Everything::DB = Test::MockObject->new;
    my $mock = Test::MockObject->new;
    my $quotes;
    my $id = [];
    my @calls;
    my $fake_nodes = { foo => 1, bar => 2 };
    $Everything::DB->mock(
        'getId',
        sub {
            push @$id, $fake_nodes->{ $_[1] };
            return $fake_nodes->{ $_[1] };
        }
      )->set_always( 'getNode', $mock )
      ->set_always( 'getDatabaseHandle', $mock )->mock(
        'sqlSelectMany',
        sub { push @calls, [ 'sqlSelectMany', @_ ]; $mock }
      );

    $mock->mock( 'quote', sub { my $r = qq{'$_[1]'}; $quotes .= $r; $r; } );
    $mock->set_series( 'fetchrow_hashref', 1, 2, 3 );

    ## to test skipped words
    $mock->set_always( getVars => { ab => 1, abcd => 1, } );

    is( Everything::searchNodeName(''),
        undef,
        'searchNodeName() should return without workable words to find' );

    Everything::searchNodeName( '', [ 'foo', 'bar' ] );
    is( $id->[0], 1, '... should call getId() for first type' );
    is( $id->[1], 2,
        '... should call getId() for subsequent types (if passed)' );

    Everything::searchNodeName('quote');
    is( $quotes, q{'[[:<:]]quote[[:>:]]'},
        '... should quote() searchable words' );

    # reset series
    $mock->set_series( 'fetchrow_hashref', 1, 2, 3 );

    my $found =
      Everything::searchNodeName( 'ab aBc!  abcd a ee', [ 'foo', 'bar' ] );

    like( $quotes, qr/abc\\!/, '... should escape nonword chars too' );

    is( $calls[-1]->[0], 'sqlSelectMany',
        '... should sqlSelectMany() matching titles' );
    like(
        $calls[-1]->[2],
        qr/\*.+?lower.title.+?rlike.+abc.+/,
        '... selecting by title with regexes'
    );

    like(
        $calls[-1]->[4],
        qr/AND .type_nodetype = 1 OR type_nodetype = 2/,
        '... should constrain by type, if provided'
    );
    is(
        $calls[-1]->[5],
        'ORDER BY matchval DESC',
        '... and should order results properly'
    );

    is( ref $found, 'ARRAY', '... should return an arrayref on success' );

    is( @$found, 3, '... should find all proper results' );
    is( join( '', @$found ), '123', '... and should return results' );
}

sub test_clearLog : Test(4) {
    my $self = shift;
    local *Everything::getTime;
    *Everything::getTime = sub { 'timestamp' };

    my $log_file = $ENV{EVERYTHING_LOG};
    unlink 'log' if -e 'log';

    Everything::printLog('logme');

    my $fh = IO::File->new;
    $fh->open($log_file) || return "log open failed, $!";

    #		'printLog() should log to file specified in %ENV' );

    my $line = <$fh>;

    is( $line, "timestamp: logme\n", '... logging time and message' );
    close $fh;

    Everything::printLog('second');
    $fh->open($log_file) or return "log open failed again, $!";

    my @lines = <$fh>;
    close $fh;

    is( $lines[1], "timestamp: second\n", '... appending to log' );

    Everything::clearLog();

    $fh->open($log_file) or return "log open failed on third try, $!";
    @lines = <$fh>;

    is( @lines, 1, 'clearLog() should clear old lines' );
    is(
        $lines[0],
        'timestamp: Everything log cleared',
        '... writing a cleared message'
    );
    $fh->close;
    unlink $log_file;
}

1;
