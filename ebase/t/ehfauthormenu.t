#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
	push @INC, '/home/shane/dev/TestMockObject/Test/MockObject/lib';
}

package Everything::HTML::FormObject::AuthorMenu;
use vars qw( $DB );

package main;

use vars qw( $AUTOLOAD );
my $package = 'Everything::HTML::FormObject::AuthorMenu';

use Test::More tests => 39;
use Test::MockObject;
my $mock = Test::MockObject->new();

my @imports;
for ( 'Everything', 'Everything::HTML', 'Everything::HTML::FormObject') {
	Test::MockObject->fake_module( $_, import => sub { push @imports, $_[0] } );
}

use_ok( 'Everything::HTML::FormObject::AuthorMenu' );
is( $imports[0], 'Everything', 'Module should use Everything' );
is( $imports[1], 'Everything::HTML', 'Module should use Everything::HTML' );
is( $imports[2], 'Everything::HTML::FormObject',
	'Module should use Everything::HTML::FormObject' );

# genObject()
my (%gpa, @gpa);
can_ok( $package, 'genObject' );
$mock->fake_module( $package,
	getParamArray => sub { push @gpa, \@_; return @gpa{qw( q bn f n d )}}
);

my @go;
$mock->fake_module( 'Everything::HTML::FormObject',
	genObject => sub { push @go, \@_; return 'some html' }
);

$Everything::HTML::FormObject::AuthorMenu::DB = $mock;
$mock->set_always( 'textfield', 'more html' );
$mock->set_series( 'getNode', 0, $mock, $mock );
$gpa{q} = $mock;
$gpa{f} = 'field';

my $result = genObject( $mock, 1, 2, 3 );
is( @gpa, 1, 'genObject() should call getParamArray' );
is( $gpa[0][0], 'query, bindNode, field, name, default',
	'... requesting the appropriate arguments' );
like( join(' ', @{ $gpa[0] }), qr/1 2 3$/, '... with the method arguments' );
unlike( join(' ', @{ $gpa[0] }), qr/$mock/, '... but not the object itself' );
ok( ! $mock->called( 'getNode' ),
	'... should not fetch bound node without one' );

my ($method, $args) = $mock->next_call();
shift @$args;
my %args = @$args;

is( $method, 'textfield', '... and should create a text field' );
is( join(' ', sort keys %args ),
	join(' ', sort qw( -name -default -size -maxlength -override )), 
	'... passing the essential arguments' );
is( $args{-name}, 'field', '... and widget name should default to field name' );
is( $result, "some html\nmore html\n",
	'... returning the parent object plus the new textfield html' );

$mock->{field} = 'bound node';
$gpa{bn} = $mock;
genObject( $mock );

($method, $args) = $mock->next_call();
is( $method, 'getNode', '... should get bound node, if provided' );
is( $args->[1], 'bound node', '... identified by its name' );
($method, $args) = $mock->next_call();
isnt( $method, 'isOfType',
	'... not checking bound node type if it is not found' );
shift @$args;
%args = @$args;
is( $args{-default}, undef, '... and not modifying default selection' );

$mock->{title} = 'bound title';
$mock->set_series( 'isOfType', 0, 1 );

genObject( $mock );
($method, $args) = $mock->next_call( 2 );
is( $method, 'isOfType', '... if bound node is found, should check type' );
is( $args->[1], 'user', '... (the user type)' );

($method, $args) = $mock->next_call();
shift @$args;
%args = @$args;
is( $args{-default}, '',
	'... setting default to blank string if it is not a user' );

genObject( $mock );
($method, $args) = $mock->next_call( 3 );
shift @$args;
%args = @$args;
is( $args{-default}, 'bound title', '... but using node title if it is' );

# cgiVerify()
my $qmock = Test::MockObject->new();
$mock->set_series( 'getBindNode', 0, 0, 0, $mock, $mock );
$qmock->set_series( 'param', 0, 'author', 'author' );
$result = cgiVerify( $mock, $qmock, 'boundname' );

($method, $args) = $mock->next_call();
is( $method, 'getBindNode', 'cgiVerify() should get bound node' );
is( join(' ', @$args), "$mock $qmock boundname",
	'... with query object and query parameter name' );

($method, $args) = $qmock->next_call();
is( $method, 'param', '... fetching parameter' );
is( $args->[1], 'boundname', '... by name' );

isa_ok( $result, 'HASH', '... and should return a data structure which' );

$mock->set_series( 'getNode', 0, { node_id => 'node_id' } );
$result = cgiVerify( $mock, $qmock, 'boundname' );
($method, $args) = $mock->next_call( 2 );
is( $method, 'getNode', '... fetching the node, if an author is found' );
is( join(' ', @$args), "$mock author user",
	'... with the author, for the user type' );
is( $result->{failed}, "User 'author' does not exist!",
	'... setting a failure message on failure' );

$qmock->clear();
$result = cgiVerify( $mock, $qmock, 'boundname' );
($method, $args) = $qmock->next_call( 2 );
is( $method, 'param', '... setting parameters, on success' );
is( join(' ', @$args), "$qmock boundname node_id",
	'... with the name and node id' );
is( $result->{failed}, undef, '... and no failure message' );

$mock->set_always( 'getId', 'id' );
$mock->set_series( 'hasAccess', 0, 1 );
$result = cgiVerify( $mock, $qmock, 'boundname', 'user' );
$mock->called_pos_ok( -2 , 'getId',
	'... should get bound node id, if it exists' );
is( $result->{node}, 'id', '... setting it in the resulting node field' );
$mock->called_pos_ok( -1, 'hasAccess', '... checking node access ');
is( $mock->call_args_string( -1, ' ' ), "$mock user w",
	'... for user with write permission' );

is( $result->{failed}, 'You do not have permission',
	'... setting a failure message if user lacks write permission' );

$result = cgiVerify( $mock, $qmock, 'boundname', 'user' );
is( $result->{failed}, undef, '... and none if the user has it' );

sub AUTOLOAD {
	my ($subname) = $AUTOLOAD =~ /([^:]+)$/;
	if (my $sub = UNIVERSAL::can( $package, $subname )) {
		$sub->( @_ );
	} else {
		warn "Cannot ($package) <$subname>\n";
	}
}
