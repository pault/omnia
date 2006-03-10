#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use strict;
use vars qw( $AUTOLOAD );

use Test::More tests => 19;
use Test::MockObject;

my $mock = Test::MockObject->new();

my ( $method, $args, $results, @le );

$mock->fake_module( 'Everything', logErrors => sub { push @le, [@_] } );
$mock->fake_module('XML::DOM');

my $package = 'Everything::XML';
use_ok($package) or exit;

sub AUTOLOAD
{
	$AUTOLOAD =~ s/main:://;
	if ( my $sub = $package->can($AUTOLOAD) )
	{
		no strict 'refs';
		*{$AUTOLOAD} = $sub;
		goto &$AUTOLOAD;
	}
}

can_ok( $package, 'readTag' );

can_ok( $package, 'initXMLParser' );
my $unfixed = _unfixed();
$unfixed->{foo} = 'bar';
initXMLParser();
is( keys( %{ _unfixed() } ), 0, 'initXMLParser() should clear unfixed keys' );

can_ok( $package, 'fixNodes' );
{
	my ( @gn, @gnret );

	local *Everything::XML::getNode;
	*Everything::XML::getNode = sub {
		push @gn, [@_];
		return shift @gnret;
	};

	my $unfixed = _unfixed();
	$unfixed->{foo} = 'bar';

	fixNodes(0);
	is( @le, 0, 'fixNodes() should log nothing unless error flag is set' );

	fixNodes(1);
	is( @le, 1, '... but should log with error flag' );

	@gnret = ($mock) x 4;

	$mock->set_series( applyXMLFix => 1, 0, 1 )->set_true('commitXMLFixes')
		->clear();
	$unfixed->{foo} = [ 1, 2 ];

	fixNodes('printflag');
	( $method, $args ) = $mock->next_call();
	is( $method, 'applyXMLFix', '... calling applyXMLFix() for all unfixed' );
	is( join( '-', @$args ),
		"$mock-1-printflag", '... with fix and print error' );
	is_deeply( $unfixed, { foo => [1] }, '... saving only unfixed nodes' );

	$mock->clear();

	$unfixed = { bar => [] };
	fixNodes('printflag');
	is( $mock->next_call(2), 'commitXMLFixes', '... committing fixes' );
}

can_ok( $package, 'xml2node' );
can_ok( $package, 'xmlfile2node' );
can_ok( $package, 'genBasicTag' );
can_ok( $package, 'parseBasicTag' );
can_ok( $package, 'patchXMLwhere' );
can_ok( $package, 'makeXmlSafe' );
can_ok( $package, 'unMakeXmlSafe' );
can_ok( $package, 'getFieldType' );
