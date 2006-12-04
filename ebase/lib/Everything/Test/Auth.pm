package Everything::Test::Auth;

use base 'Everything::Test::Abstract';
use Test::More;
use Test::Exception;
use Test::MockObject;
use File::Spec;
use File::Path;
use SUPER;
use strict;

sub startup : Test( startup => +5 ) {
    my $self = shift;
    $self->SUPER;
    can_ok( $self->{class}, 'new' );

    my $db = Test::MockObject->new();
    local *Everything::Auth::DB;
    *Everything::Auth::DB = \$db;
    $db->set_always( getNode => { node_id => 88 } );
    $self->{db} = $db;
    my $instance = $self->{class}->new();
    isa_ok( $instance, $self->{class} );
    $self->{instance} = $instance;

    ok(
        exists $INC{'Everything/Auth/EveryAuth.pm'},
        'new() should load default auth plugin by default'
    );
    isa_ok( $instance->{plugin}, 'Everything::Auth::EveryAuth' );
    is( $instance->{options}{guest_user},
        88, '... setting guest user id from database' );

    $self->{options} = { guest_user => 77, Auth => 'Plugin' };

}

sub test_load_module : Test(2) {

    my $self = shift;
    my $success;
    my $options = $self->{options};
    my $package = $self->{class};
    my $path    = File::Spec->catdir(qw( lib Everything Auth ));
    my $mod;
    if ( -d $path or mkpath $path) {
        $mod = File::Spec->catfile( $path, 'Plugin.pm' );
        if ( open( OUT, ">$mod" ) ) {
            print OUT "package Everything::Auth::Plugin;\n"
              . 'sub new { bless {}, $_[0] }'
              . "\n1;\n";

            $success = close OUT;
        }
    }

    return ( "Cannot open fake auth package", 2 ) unless $success;
    $options->{Auth} = 'Plugin';
    my $result = $package->new($options);
    isa_ok( $result->{plugin}, 'Everything::Auth::Plugin' );
    is( $result->{options}, $options, '... setting options to passed-in opts' );

    unlink $mod;

}

sub test_load_fake_module : Test(1) {
    my $self    = shift;
    my $options = $self->{options};

    $options->{Auth} = 'Fake';
    throws_ok { $self->{class}->new($options) } qr/No authentication plugin/,
      '... should die if it finds no auth plugin';

}

sub test_public_methods : Test(18) {

    my $self    = shift;
    my $package = $self->{class};

    for my $public (qw( loginUser logoutUser authUser )) {
        can_ok( $package, $public );
        my $mock = Test::MockObject->new();
        $mock->set_always( $public      => 'user' )
          ->set_always( generateSession => 'generated' );

        $mock->{plugin} = $mock;

        my $sub = $package->can($public);

        my $result = $sub->( $mock, 'args', 'args' );

        my ( $method, $args ) = $mock->next_call();
        is( $method, $public, "$public() should delegate to plugin" );
        is_deeply( $args, [ $mock, qw( args args ) ], '... passing all args' );

        ( $method, $args ) = $mock->next_call();
        is( $method,    'generateSession', '... generating a session' );
        is( $args->[1], 'user',            '... for the user' );
        is( $result,    'generated',       '... returning the results' );
    }

}

sub test_generate_session : Test(5) {

    my $self    = shift;
    my $package = $self->{class};
    my $db      = $self->{db};
    local *Everything::Auth::DB;
    *Everything::Auth::DB = \$db;

    can_ok( $package, 'generateSession' );
    my $mock = Test::MockObject->new();
    $mock->{options} = { guest_user => 'guest' };
    $mock->set_always( getVars => 'vars' );

    $db->set_false('getNode')->clear();

    throws_ok { Everything::Auth::generateSession($mock) }
      qr/Unable to get user!/, 'generateSession() should die with no user';
    my ( $method, $args ) = $db->next_call();
    is( $method, 'getNode', '... so should fetch a user given none' );
    is( $args->[1], 'guest', '... using guest user option' );

    my @results = Everything::Auth::generateSession( $mock, $mock );
    is_deeply(
        \@results,
        [ $mock, 'vars' ],
        '... returning user and user vars'
    );

}

1;
