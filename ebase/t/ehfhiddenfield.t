#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use Test::More tests => 8;

use_ok( 'Everything::HTML::FormObject::HiddenField' );
my $ho = Everything::HTML::FormObject::HiddenField->new();

use CGI;
use FakeNode;
my ($query, $bindNode) = ( CGI->new(), FakeNode->new() );
$$bindNode{node_id} = 123; 

# genObject()
{
	my ($params1, $params2);
	local (*Everything::HTML::FormObject::HiddenField::getParamArray,
		*Everything::HTML::FormObject::genObject);

	*Everything::HTML::FormObject::HiddenField::getParamArray = sub {
		shift @_;  # first value is not part of @_
		$params1 = join '', @_;
		return @_;
	};

	*Everything::HTML::FormObject::genObject = sub {
		$params2 = join '', @_;
	};

	my @params = ($query, $bindNode, "node_id", "name", "def");
	$ho->genObject(@params);
	is ( $params1, join('', @params),
		'genObject() should call getParamArray() with @_' );
	is ( $params2, join('', $ho, $query, $bindNode, "node_id", "name"),
		'... should call SUPER::genObject()' );
}

like ( $ho->genObject($query, $bindNode, "node_id", "", "def"),
	qr/name="node_id"/i,
	'... should set name to field if name is not set' );
like ( $ho->genObject ($query, $bindNode, "node_id", "name", "def"),
	qr/name="name"/i,
	'... and leave it alone if it is set' );
like ( $ho->genObject($query, $bindNode, "node_id", "name", ""),
	qr/value="123"/i,
	'... should set default to field of bindNode if default not set' );
like ( $ho->genObject($query, "", "", "name", ""),
	qr/value=""/i,
	'... or leave it blank if bindNode not set' );
like ( $ho->genObject($query, $bindNode, "node_id", "name", "def"),
	qr/value="def"/i,
	'... and leave it alone if it is set' );
