#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use strict;
use vars '$AUTOLOAD';

use File::Spec;
use File::Path;
use Test::More tests => 96;
use Test::MockObject;

# temporarily avoid sub redefined warnings
my $mock = Test::MockObject->new();
my @le;

$mock->fake_module( 'Everything', logErrors => sub { push @le, [@_] } );
$mock->fake_module('Everything::Auth');

my $package = 'Everything::HTML';

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

use_ok($package) or die;

my ( $result, $method, $args );
can_ok( $package, 'deprecate' );
deprecate(0);
is( @le, 1, 'deprecate() should log a message' );
like( $le[0][0], qr/^Deprecated function.+called/, '... with a warning' );
like( $le[0][0], qr/'main program'/, '... for main, if not in a sub' );

test_dep();
like(
	$le[1][0],
	qr/function 'main::test_dep' called/,
	'... naming the function'
);

my $l = __LINE__ + 1;
test_nest_dep(2);
like(
	$le[2][0],
	qr/from $0 line #$l/,
	'... reporting package and line, respecting nest level'
);

sub test_dep
{
	my $level = shift || 1;
	deprecate($level);
}

sub test_nest_dep
{
	test_dep(@_);
}

can_ok( $package, 'newFormObject' );
is( newFormObject(), undef, 'newFormObject() should return without name' );

SKIP:
{
	my $flag;

	my $dir = File::Spec->catdir(qw( lib Everything HTML FormObject ));
	if ( -d $dir or $flag = mkpath($dir) )
	{
		local *FILE;
		my $file = File::Spec->catfile( $dir, 'foo.pm' );
		if ( $flag = open( FILE, ">$file" ) )
		{
			( my $module = <<"			END_HERE") =~ s/^\t+//gm;
			package Everything::HTML::FormObject::foo;
			sub new { bless {}, __PACKAGE__ }
			1;
			END_HERE

			print FILE $module;
		}
	}

	skip( "Cannot open fake file: $!", 4 ) unless $flag;

	local @INC = 'lib';
	@le = ();

	$result = newFormObject('foo');
	isa_ok(
		$result,
		'Everything::HTML::FormObject::foo',
		'... creating object that'
	);

	$result = newFormObject('not foo');
	is( @le, 1, '... logging error if form object does not exist' );
	like( $le[0][0], qr/Can't locate/, '... with error message' );
	is( $result, undef, '... returning undef' );
	rmtree( $dir, 0, 1 ) or diag "Cannot remove '$dir': $!";
}

can_ok( $package, 'tagApprove' );
can_ok( $package, 'htmlScreen' );
can_ok( $package, 'encodeHTML' );
can_ok( $package, 'decodeHTML' );
{

	#individually:
	is( encodeHTML(''),  '',       'encodeHTML() should preserve nullspace' );
	is( encodeHTML('&'), '&amp;',  'encodeHTML() should encode ampersands' );
	is( encodeHTML('"'), '&quot;', 'encodeHTML() should encode double quotes' );
	is( encodeHTML('<'), '&lt;',
		'encodeHTML() should encode left angle brackets' );
	is( encodeHTML('>'), '&gt;',
		'encodeHTML() should encode right angle brackets' );
	is( encodeHTML('['), '[',
		'encodeHTML() should not encode left brackets without the adv parameter'
	);
	is( encodeHTML(']'), ']',
'encodeHTML() should not encode right brackets without the adv parameter'
	);
	is( encodeHTML( '[', 1 ),
		'&#91;',
		'encodeHTML() should encode left brackets with the adv parameter' );
	is( encodeHTML( ']', 1 ),
		'&#93;',
		'encodeHTML() should encode right brackets with the adv parameter' );

	is( decodeHTML(''),       '',  'decodeHTML() should preserve nullspace' );
	is( decodeHTML('&amp;'),  '&', 'decodeHTML() should decode apersands' );
	is( decodeHTML('&quot;'), '"', 'decodeHTML() should decode double quotes' );
	is( decodeHTML('&lt;'), '<',
		'decodeHTML() should decode angle left brackets' );
	is( decodeHTML('&gt;'), '>',
		'decodeHTML() should decode angle right brackets' );
	is( decodeHTML('&#91;'), '&#91;',
		'decodeHTML() should not decode left brackets without the adv parameter'
	);
	is( decodeHTML('&#93;'), '&#93;',
'decodeHTML() should not decode right brackets without the adv parameter'
	);
	is( decodeHTML( '&#91;', 1 ),
		'[',
		'decodeHTML() should decode left brackets with the adv parameter' );
	is( decodeHTML( '&#93;', 1 ),
		']',
		'decodeHTML() should decode right brackets with the adv parameter' );

	#integrated:
	my $string = "'&foo; <br>'";
	is(
		encodeHTML($string),
		"'&amp;foo; &lt;br&gt;'",
		'encodeHTML() should create valid encoded characters in a string'
	);
	is( decodeHTML( encodeHTML($string) ),
		$string, 'encodeHTML() and decodeHTML() should undo each other' );

	$string = ' [ foo &amp;]"Hello';
	is(
		encodeHTML($string),
		' [ foo &amp;amp;]&quot;Hello',
		'encodeHTML() should properly encode a complicated string'
	);
	is(
		decodeHTML($string),
		' [ foo &]"Hello',
		'decodeHTML() should properly decode a complicated string'
	);
	is(
		decodeHTML( encodeHTML($string) ),
		$string,
'encodeHTML() and decodeHTML() should undo each other for a complicated string'
	);

	$string = "<br>\n&lt;p&gt;";
	is(
		encodeHTML($string),
		"&lt;br&gt;\n&amp;lt;p&amp;gt;",
		'encodeHTML() should properly encode a string with a newline'
	);
	is( decodeHTML($string), "<br>\n<p>",
		'decodeHTML() should properly decode a string with a newline' );
	is(
		decodeHTML( encodeHTML($string) ),
		$string,
'encodeHTML() and decodeHTML() should undo each other for a string with a newline'
	);

}
can_ok( $package, 'htmlFormatErr' );
can_ok( $package, 'htmlErrorUsers' );
can_ok( $package, 'htmlErrorGods' );
can_ok( $package, 'urlGen' );
{
	local $ENV{SCRIPT_NAME} = '/this.pl';
	my $q = CGI->new();

	local *Everything::HTML::query;
	*Everything::HTML::query = \$q;

	$result = urlGen( { foo => [ 'bar', 'baz' ] } );
	is( $result, '"this.pl?foo=bar;foo=baz"',
		'urlGen() should generate relative URL from params' );
	is( urlGen( { foo => 'bar' }, 1 ),
		'this.pl?foo=bar', '... without quotes, if noflags is true' );
}

can_ok( $package, 'getPageForType' );
can_ok( $package, 'getPage' );
can_ok( $package, 'linkNode' );
can_ok( $package, 'linkNodeTitle' );
can_ok( $package, 'searchForNodeByName' );
can_ok( $package, 'evalXTrapErrors' );
can_ok( $package, 'evalX' );
can_ok( $package, 'htmlcode' );
can_ok( $package, 'do_args' );
can_ok( $package, 'executeCachedCode' );
can_ok( $package, 'createAnonSub' );
can_ok( $package, 'compileCache' );
can_ok( $package, 'nodemethod' );
can_ok( $package, 'htmlsnippet' );
can_ok( $package, 'embedCode' );
can_ok( $package, 'parseCode' );
can_ok( $package, 'oldparseCode' );               # probably unnecessary
can_ok( $package, 'listCode' );
can_ok( $package, 'linkCode' );
can_ok( $package, 'quote' );                      # may be deprecated
can_ok( $package, 'insertNodelet' );
can_ok( $package, 'updateNodelet' );
can_ok( $package, 'genContainer' );
can_ok( $package, 'containHtml' );
can_ok( $package, 'displayPage' );
can_ok( $package, 'formatGodsBacksideErrors' );
can_ok( $package, 'printBacksideToLogFile' );
can_ok( $package, 'gotoNode' );
can_ok( $package, 'parseLinks' );
can_ok( $package, 'getCGI' );
can_ok( $package, 'getTheme' );
can_ok( $package, 'printHeader' );
can_ok( $package, 'handleUserRequest' );
can_ok( $package, 'cleanNodeName' );
can_ok( $package, 'initForPageLoad' );
can_ok( $package, 'opNuke' );
can_ok( $package, 'opLogin' );
can_ok( $package, 'opLogout' );
can_ok( $package, 'opNew' );
can_ok( $package, 'opUnlock' );                   # deprecated ?
can_ok( $package, 'opLock' );
can_ok( $package, 'opUpdate' );
can_ok( $package, 'getOpCode' );
can_ok( $package, 'execOpCode' );
can_ok( $package, 'setHTMLVARS' );
can_ok( $package, 'updateNodeData' );
can_ok( $package, 'mod_perlInit' );