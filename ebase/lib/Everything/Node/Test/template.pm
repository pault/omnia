package Everything::Node::Test::template;

use strict;
use warnings;

use base 'Everything::Node::Test::document';

use Test::More;

sub test_process :Test( 5 )
{
	my $self  = shift;
	my $class = $self->node_class();
	can_ok( $class, 'process' );

	my $nodebase = $self->{mock_db};
	my $doc = $nodebase->getNode( 'document', 'nodetype', 'create force' );

	$doc->set_extends_nodetype( 1 );
	$doc->set_sqltable( 'document' );
	$doc->insert( -1 );

	my $dbh = $nodebase->getDatabaseHandle;
	$dbh->do('create table document ( doctext text, document_id int)' );

	my $tem = $nodebase->getNode( 'template', 'nodetype', 'create force' );

	$tem->set_extends_nodetype( $doc->getId );
	$tem->insert( -1 );

	my $template_node = $nodebase->getNode( 'test template', 'template', 'create force');
	$template_node->set_doctext(qq{This is a test});
	$template_node->insert( -1 );

	my $result;

	is ( $result = $template_node->process( undef, $nodebase ), 'This is a test', '...should return template text');

	$template_node->set_doctext( q{ This is a [% var %] } );
	$template_node->update( -1 );

	is ( $result = $template_node->process( { var => 'var' }, $nodebase ), ' This is a var ', '...should substitute vars');

	my $t2 = $nodebase->getNode( 'test template 2', 'template',  'create force');

	$t2->set_doctext(q{ This is test template 2 including [% INCLUDE "test template" %] });
	$t2->insert( -1 );

	is ( $result = $t2->process( { var => 'test_template' }, $nodebase ), ' This is test template 2 including  This is a test_template  ', '...should return template text');

	$t2->set_doctext(q{ This is test template 2 including [% PROCESS "test template" %] });
	$t2->insert( -1 );

	is ( $result = $t2->process( { var => 'test_template' }, $nodebase ), ' This is test template 2 including  This is a test_template  ', '...also with PROCESS directive.');
}

1;
