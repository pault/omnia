#! /usr/bin/perl

use Everything::Template::Plugin::Code;
use Everything::HTML;
use Test::MockObject;
use Template::Context;
use Test::More tests => 3;
use strict;
use warnings;

my $ehtml = Everything::HTML->new;
my $context = Template::Context->new( { VARIABLES => { ehtml => $ehtml } } );
my $obj;

ok( $obj = Everything::Template::Plugin::Code->new( $context ) );

my $tt = Template->new( { PLUGINS => { code => "Everything::Template::Plugin::Code" } } );

my $mock = Test::MockObject->new;
$mock->set_always( getNode => $mock );
$mock->set_always( -get_request => $mock );
$mock->set_always( -get_nodebase => $mock );
$mock->set_always( run => 'ran' );
$ehtml->set_request( $mock );

my $output;
ok( $tt->process( \*DATA, { ehtml => $ehtml }, \$output ) ) || diag $tt->error;

like( $output, qr/ran/ );

__END__

A test template

[% USE code %]

[% code(htmlcode)  %]
