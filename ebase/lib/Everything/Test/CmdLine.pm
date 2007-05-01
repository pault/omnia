package Everything::Test::CmdLine;

use Test::More;
use Test::Warn;
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

1;
