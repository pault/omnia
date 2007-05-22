package Everything::Test::CmdLine;

use Test::More;
use Test::Warn;
use Test::MockObject;
use Test::Exception;
use Cwd;
use warnings;
use strict;

use base 'Everything::Test::Abstract';

my $exited;

BEGIN {
    *CORE::GLOBAL::exit = sub { $exited++ };
}

sub test_get_options : Test(4) {
    my $self      = shift;
    my $test_code = \&{ $self->{class} . '::get_options' };

    @ARGV = (
        '-d', 'db',       '-u', 'me',   '-h', 'ahost',
        '-p', 'password', '-P', '1111', '-t', 'atype'
    );

    my $opts = $test_code->();
    is_deeply(
        $opts,
        {
            database   => 'db',
            user       => 'me',
            host       => 'ahost',
            'password' => 'password',
            port       => '1111',
            type       => 'atype'
        },
        '... checks all short command line options.'
    );

    @ARGV = (
        '--database', 'db',    '--user',     'me',
        '--host',     'ahost', '--password', 'password',
        '--port',     '1111',  '--type',     'atype'
    );

    $opts = $test_code->();
    is_deeply(
        $opts,
        {
            database   => 'db',
            user       => 'me',
            host       => 'ahost',
            'password' => 'password',
            port       => '1111',
            type       => 'atype'
        },
        '... checks all long command line options.'
    );

    @ARGV = (
        '--databaes', 'db',    '--user',     'me',
        '--host',     'ahost', '--password', 'password',
        '--port',     '1111',  '--type',     'atype'
    );

    warnings_like { $opts = $test_code->() }[ qr/Unknown option/, qr/Usage/ ],
      '... warns with incorrect options';
    is( $exited, 1, '... and exits.' );

}

sub test_abs_path : Test(4) {
    my $self = shift;
    can_ok( $self->{class}, 'abs_path' ) || return 'abs_path not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::abs_path' };
    my $rv        = $test_code->('~/here');
    is( $rv, $ENV{HOME} . '/here', '..gets absolute unix path.' );

    my $wd = getcwd();
    $rv = $test_code->('./here');
    is( $rv, $wd . '/here', '..resolves the directory ".".' );

    $wd =~ s/[\/][^\/]+$//;

    $rv = $test_code->('../here');
    is( $rv, $wd . '/here', '..resolves the directory "..".' );

}


sub test_make_nodebase : Test(5) {
    my $self = shift;
    can_ok( $self->{class}, 'make_nodebase' )
      || return 'abs_path not implemented.';

    my $mock = Test::MockObject->new;
    $mock->fake_module('Everything::NodeBase');

    my @new_args;
    my $new_returns = $mock;
    local *Everything::NodeBase::new;
    *Everything::NodeBase::new = sub { @new_args = @_; return $new_returns };

    my $test_code = \&{ $self->{class} . '::make_nodebase' };
    my $opts      = {
        database => 'dbname',
        user     => 'dbuser',
        password => 'dbpassword',
        host     => 'dbhost',
        type     => 'dbtype',
        port     => 'dbport'
    };
    my $rv = $test_code->($opts);
    is_deeply(
        \@new_args,
        [
            'Everything::NodeBase', "dbname:dbuser:dbpassword:dbhost",
            1,                      'dbtype'
        ],
        '...args are handled properly.'
    );
    is( "$rv", $mock, '...returns the return value of NodeBase\'s new.' );

    $opts = { database => 'dbname', password => '' };
    $rv = $test_code->($opts);
    is_deeply(
        \@new_args,
        [ 'Everything::NodeBase', "dbname:$ENV{USER}::localhost", 1, 'sqlite' ],
        '...defaults are set.'
    );

    undef $new_returns;
    dies_ok { $test_code->($opts) } '...dies if no nodebase found.';
}

1;
