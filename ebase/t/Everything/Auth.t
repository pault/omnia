#!/usr/bin/perl -w

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../lib', '../blib/lib', 'lib';
}

use strict;
use File::Path;
use File::Spec;

use Test::More tests => 32;

use Test::Exception;
use Test::MockObject;

my $package = 'Everything::Auth';

use_ok( $package ) or die;

my ($result, $method, $args, @le);

can_ok( $package, 'new' );
my $db = Test::MockObject->new();
local *Everything::Auth::DB;
*Everything::Auth::DB = \$db;
$db->set_always( getNode => { node_id => 88 } );

$result = $package->new();
isa_ok( $result, $package );
ok( exists $INC{'Everything/Auth/EveryAuth.pm'},
	'new() should load default auth plugin by default' );
isa_ok( $result->{plugin}, 'Everything::Auth::EveryAuth' );
is( $result->{options}{guest_user}, 88,
	'... setting guest user id from database' );

my $options = { guest_user => 77, Auth => 'Plugin' };

SKIP:
{
	my $success;

	my $path = File::Spec->catdir(qw( lib Everything Auth ));

	if (-d $path or mkpath $path)
	{
		my $mod  = File::Spec->catfile( $path, 'Plugin.pm' );
		if (open( OUT, ">$mod" ))
		{
			print OUT "package Everything::Auth::Plugin;\n" .
				'sub new { bless {}, $_[0] }' . "\n1;\n";

			$success = close OUT;
		}
	}

	skip( "Cannot open fake auth package", 2 ) unless $success;

	$result = $package->new( $options );
	isa_ok( $result->{plugin}, 'Everything::Auth::Plugin' );
	is( $result->{options}, $options, '... setting options to passed-in opts' );

	rmtree $path;
}

$options->{Auth} = 'Fake';
throws_ok { $package->new( $options ) } qr/No authentication plugin/,
	'... should die if it finds no auth plugin';


for my $export (qw( loginUser logoutUser authUser ))
{
	can_ok( $package, $export );
	my $mock = Test::MockObject->new();
	$mock->set_always( $export => 'user' )
		 ->set_always( generateSession => 'generated' );

	$mock->{plugin} = $mock;

	my $sub = main->can( $export );
	$result = $sub->( $mock, 'args', 'args' );

	($method, $args) = $mock->next_call();
	is( $method, $export, "$export() should delegate to plugin" );
	is_deeply( $args, [$mock, qw( args args )], '... passing all args' );

	($method, $args) = $mock->next_call();
	is( $method, 'generateSession', '... generating a session' );
	is( $args->[1], 'user', '... for the user' );
	is( $result, 'generated', '... returning the results' );
}

can_ok( $package, 'generateSession' );
my $mock = Test::MockObject->new();
$mock->{options} = { guest_user => 'guest' };
$mock->set_always( getVars => 'vars' );

$db->set_false( 'getNode' )->clear();

throws_ok { Everything::Auth::generateSession( $mock ) }
	qr/Unable to get user!/, 'generateSession() should die with no user';
($method, $args) = $db->next_call();
is( $method, 'getNode', '... so should fetch a user given none' );
is( $args->[1], 'guest', '... using guest user option' );

my @results = Everything::Auth::generateSession( $mock, $mock );
is_deeply( \@results, [ $mock, 'vars' ], '... returning user and user vars' );
