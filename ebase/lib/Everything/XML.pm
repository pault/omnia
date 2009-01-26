
=head1 Everything::XML

A module for the XML stuff in Everything

Copyright 2000 - 2003 Everything Development

=cut

package Everything::XML;

use strict;
use Everything qw/getNode getType selectNodeWhere getRef/;
use XML::DOM;


use base 'Exporter';
our (@EXPORT_OK);

@EXPORT_OK = qw(
		xml2node
		xmlfile2node
		fixNodes
		readTag
		genBasicTag
		parseBasicTag
		patchXMLwhere
	);

# This version is used to make sure that we are importing something that
# was generated with an equal or earlier version of this parser/exporter.
my $XML_PARSER_VERSION = 0.5;
my %UNFIXED_NODES;

=cut


=head2 C<readTag>

To quickly read an XML tag, without parsing the whole document.  Right now, it
doesn't read attributes, only contents.

=cut

sub readTag
{
	my ( $tag, $xml, $type ) = @_;

	$type ||= "field";

	if ( $xml =~ /\<$type\s*name="$tag".*?\>(.*?)\<\/$type\>/gsi )
	{
		return unMakeXmlSafe($1);
	}
	"";
}

our %tag_process = ( field => \&process_field_tag,
		     group => \&process_group_tag,
		     vars  => \&process_vars_tag
		   );


sub process_vars_tag
{
	my ( $node, $TAG ) = @_;

	my @fixes;
	my @childFields = $TAG->getChildNodes();

	# On import, this could start out as nothing and we want it to be at least
	# defined to empty string.  Otherwise, we will get warnings when we call
	# getVars() below.

	$$node{vars} ||= "";

	my $vars = $node->getVars();

	foreach my $child (@childFields)
	{
		next if ( $child->getNodeType() == XML::DOM::TEXT_NODE() );

		my $PARSE = parseBasicTag( $child, 'setting' );

		if ( exists $$PARSE{where} )
		{
			$$vars{ $$PARSE{name} } = -1;

			# The where contains our fix
			push @fixes, $PARSE;
		}
		else
		{
			$$vars{ $$PARSE{name} } = $$PARSE{ $$PARSE{name} };
		}
	}

	$node->setVars($vars);
	return \@fixes;
}

sub process_group_tag {

	my ( $node, $TAG ) = @_;

	my @fixes;
	my @childFields = $TAG->getChildNodes();
	my $orderby     = 0;

	for my $child (@childFields)
	{
		next if $child->getNodeType() == XML::DOM::TEXT_NODE();

		my $PARSE = Everything::XML::parseBasicTag( $child, 'nodegroup' );

		if ( exists $PARSE->{where} )
		{
			$PARSE->{orderby} = $orderby;
			$PARSE->{fixBy}   = 'nodegroup';

			# The where contains our fix
			push @fixes, $PARSE;

			# Insert a dummy node into the group which we can later fix.
			$node->insertIntoGroup( -1, -1, $orderby );
		}
		else
		{
			$node->insertIntoGroup( -1, $PARSE->{ $PARSE->{name} }, $orderby );
		}

		$orderby++;
	}

	return \@fixes if @fixes;
	return;
}

sub process_field_tag {
    my ( $node, $TAG ) = @_;

    my $PARSE = Everything::XML::parseBasicTag( $TAG, 'node' );
    my @fixes;

    # The where contains our fix
    if ( exists $PARSE->{where} )
      {
	  $node->{ $PARSE->{name} } = -1;
	  push @fixes, $PARSE;
      }
    else
      {
	  $node->{ $PARSE->{name} } = $PARSE->{ $PARSE->{name} };
      }

	return \@fixes if @fixes;
	return;
}

sub xmlTag
{
	my ( $node, $TAG ) = @_;
	my $tagname = $TAG->getTagName();

	## to emulate original functionality - not sure if there's any
	## sense to it though.
	$tagname = 'field' if $tagname =~ /field/i;
	return $tag_process{$tagname}->($node, $TAG) if $tag_process{$tagname};

	Everything::logErrors( '',
			       "node.pm does not know how to handle XML tag '$tagname' "
			       . "for type '$$node{type}{title}'" );
	return;

}

#############################################################################
sub initXMLParser
{
	%UNFIXED_NODES = ();
}

sub _unfixed
{
	\%UNFIXED_NODES;
}

#############################################################################

### applyXMLFix
#
#
# nodegroup code: if: $FIX->{fixBy} and $FIX->{fixBy} eq 'nodegroup'
# then use nodegroup code else do standard code
#
# settings code:
# elsif: not( $FIX and (reftype( $FIX ) || '') eq 'HASH' ) then return
# and if not  $FIX->{fixBy} eq 'setting'; then standard
#
# nodeball code:
# if if exists $FIX->{fixBy} and $FIX->{fixBy} eq 'setting'; then
# do the settings code else do the standard code

sub applyXMLFix_general {

    my ( $node, $FIX, $printError ) = @_;

    my $where = $FIX->{where};
    my $type  = $where->{type_nodetype};

    $where = patchXMLwhere($where);

    my $TYPE = $where->{type_nodetype};
    my $NODE = $node->{DB}->getNode( $where, $TYPE );

    unless ($NODE) {
        Everything::logErrors( '',
                "Unable to find '$where->{title}' of type "
              . "'$where->{type_nodetype}'\nfor field '$FIX->{field}'"
              . " of node '$node->{title}', '$node->{type}{title}'\n" )
          if $printError;

        return $FIX;
    }

    $node->{ $FIX->{field} } = $NODE->{node_id};
    return;

}

sub applyXMLFix_nodegroup {
    my ( $node, $FIX, $printError ) = @_;

    my $where = patchXMLwhere( $FIX->{where} );
    my $TYPE  = $where->{type_nodetype};
    my $NODE  = $node->{DB}->getNode( $where, $TYPE );

    unless ($NODE) {
        Everything::logErrors( '',
                "Unable to find '$where->{title}' of type "
              . "'$where->{type_nodetype}'\n for field '$where->{field}'\n"
              . " in node 'node->{title}' of type '$node->{type}{title}'" )
          if $printError;

        return $FIX;
    }

    # Patch our group array with the now found node id!
    $node->{group}[ $FIX->{orderby} ] = $NODE->{node_id};

    return;
}

sub applyXMLFix_setting {
    my ( $node, $FIX, $printError ) = @_;

    my $vars  = $node->getVars();
    my $where = patchXMLwhere( $FIX->{where} );
    my $TYPE  = $where->{type_nodetype};
    my $NODE  = $node->{DB}->getNode( $where, $TYPE );

    unless ($NODE) {
        Everything::logErrors( '',
            "Unable to find '$FIX->{title}' of type '$FIX->{type_nodetype}'\n"
              . "for field '$FIX->{field}' in '$node->{title}'"
              . "of type '$node->{nodetype}{title}'" )
          if $printError;
        return $FIX;
    }

    $vars->{ $FIX->{field} } = $NODE->{node_id};

    $node->setVars($vars);

    return;
}

sub applyXMLFix {
    my ( $node, $FIX, $printError ) = @_;
    return unless $FIX;

    my %dispatches = (
        node      => \&applyXMLFix_general,
        nodegroup => \&applyXMLFix_nodegroup,
        setting   => \&applyXMLFix_setting,
    );

    return $dispatches{ $FIX->{fixBy} }->(@_)
      if $FIX->{fixBy} && $dispatches{ $FIX->{fixBy} };

    if ($printError) {
        my $fixBy = $FIX->{fixBy} || '(no fix by)';
        Everything::logErrors( '',
                "node.pm does not know how to handle fix by '$fixBy'.\n"
              . "'$FIX->{where}{title}', '$FIX->{where}{type_nodetype}'\n" );
    }
    return $FIX;

}


=head2 C<commitXMLFixes>

After all the fixes for this node have been applied, this is called to allow
the node to save those fixes as it needs.

=cut

sub commitXMLFixes
{
	my ($node) = @_;

	# A basic node has no complex data structures, so all we need to do
	# is a simple update.
	$node->update( -1, 'nomodify' );

	return;
}


sub fixNodes
{
	my ($printError) = @_;

	foreach my $node ( keys %UNFIXED_NODES )
	{
		my $NODE = getNode($node);

		unless ($NODE)
		{
			Everything::logErrors( '',
				      "Node that we are supposed to fix is "
					. "not here (id $node)!" )
				if $printError;
			next;
		}

		my $UNFIXED = [];

		foreach my $FIX ( @{ $UNFIXED_NODES{$node} } )
		{
			if ( applyXMLFix( $NODE, $FIX, $printError ) )
			{

				# The node attempted to apply the fix, but none was found.
				# Put them back at the start, so we don't run through them
				# again.
				unshift @$UNFIXED, $FIX;
			}
		}

		if (@$UNFIXED)
		{
			$UNFIXED_NODES{$node} = $UNFIXED;
		}
		else
		{
			delete $UNFIXED_NODES{$node};
		}

		# All the fixes for this node have been applied.
		commitXMLFixes($NODE);
	}
}

=cut


=head2 C<xml2node>

Takes a chunk of XML -- returns a $NODE hash any broken dependancies are pushed
on @FIXES, and the node is inserted into the database (with -1 on any broken
fields) returns the node_id of the new node

=over 4

=item * xml

the string of xml to parse

=back

Returns an array ref of node ids that were parsed from the XML and inserted or
updated.

=cut

sub xml2node
{
	my ( $xml, $nofinal ) = @_;

	my $XMLPARSER = XML::DOM::Parser->new(
		ErrorContext     => 2,
		ProtocolEncoding => 'ISO-8859-1'
	);

	# XML::Parser doesn't like it when there is more than one top level
	# document tag.  If we have an XML file that contains more than one
	# node, XML::Parser will error on it.  So, to make everything happy,
	# we just wrap the entire doc in a single tag.  Ya, its a hack, but
	# does exactly what we need with minimal pain.  So, shuddup.

	my $doc = $XMLPARSER->parse("<everything>\n$xml\n</everything>");

	my @ids;
	my $NODE;

	# A single XML file may contain multiple nodes (same name/type).  We
	# iterate through each defined node.
	my @nodes = $doc->getElementsByTagName("NODE");

	foreach my $node (@nodes)
	{
		my $title   = $node->getAttribute("title");
		my $type    = $node->getAttribute("nodetype");
		my $version = $node->getAttribute("export_version");
		my @FIXES;

		if ( $version > $XML_PARSER_VERSION )
		{
			Everything::logErrors(
				"XML was created with a newer version of Everything.\n"
					. "This may not import correctly.",
				'', "'$title'"
 			);
		}

		# Start with a basic node.  We force create this to avoid over
		# writing any existing nodes... see xmlFinal() for more info.
		$NODE = getNode( $title, $type, "create force" );

		# Note, we are using XML::DOM::Node here.  Don't get the DOM
		# API confused with our API.  The 'Nodes' idea can be confusing.
		foreach my $field ( $node->getChildNodes() )
		{

			# If this child is not a tag (node) skip it.  We don't care
			# about text within the <NODE> tag.
			next if $field->getNodeType() == XML::DOM::TEXT_NODE();

			my $fixes = xmlTag($NODE, $field);
			push @FIXES, @$fixes if $fixes;
		}

		if ($nofinal)
		{
			push @ids, $NODE;
			next;
		}

		my $id = xmlFinal($NODE);

		if ( $id > 0 )
		{
			push @ids, $id;
		}
		else
		{
			Everything::logErrors( '',
				"Failed to import node '$$NODE{title}'" );
		}

		# We store any fixes that node reported so we can hopefully
		# resolve them later.
		$UNFIXED_NODES{$id} = \@FIXES if @FIXES;
	}

	return \@ids;
}

=cut


=head2 C<xmlfile2node>

Wrapper for xml2node that takes a filename as a parameter rather than a string
of XML

=cut

sub xmlfile2node
{
	my ( $filename, $nofinal ) = @_;

	local *MYXML;
	open MYXML, $filename or die "could not access file $filename";

	my $file = do { local $/; <MYXML> };
	close MYXML;

	my $result = eval { xml2node( $file, $nofinal ) };
	Everything::logErrors( '', "Node XML error in '$filename':\n'$@'" ) if $@;
	return $result;
}

=cut


=head2 C<xmlFinal>

This is called when a node has finished being constructed from an XML import.
This is when the node needs to decide whether it is updating an existing node,
or if it should insert itself as a new node.

Returns the id of the node in the database that this has been stored to.  -1 if
unable to save this.

=cut

sub xmlFinal
{
	my ($new_node) = @_;

	# First lets check to see if this node already exists.
	my $NODE = $new_node->existingNodeMatches();

	if ($NODE)
	{
		$NODE->updateFromImport( $new_node, -1 );
		return $NODE->{node_id};
	}
	else
	{

		# No node matches this one, just insert it.
		$new_node->insert(-1);
	}

	return $new_node->{node_id};
}

=head2 C<parseBasicTag>

=cut

sub parseBasicTag
{
	my ( $TAG, $fixBy ) = @_;
	my %PARSEDTAG;

	# Our contents is always the first TEXT_NODE object... just convert
	# it to a string, which is what we want anyway.  XML::Parser parses
	# empty tags (ie <tag></tag>) as an XML empty (ie <tag/>) which causes
	# it to have no child.  So, we need to do a few checks here.
	my $first = $TAG->getFirstChild();
	my $contents;

	$contents = $first->toString() if $first;
	$contents = '' if not defined $contents;

	$contents = unMakeXmlSafe($contents);

	my $ATTRS = $TAG->getAttributes();
	my $type  = $ATTRS->{type}->getValue();
	my $name  = $ATTRS->{name}->getValue();
	my $isNull;
	$isNull++ if $ATTRS->{null};

	$PARSEDTAG{name} = $name;

	if ( $isNull) {
	    $PARSEDTAG{$name} = undef;
	}
	elsif ( $type eq 'noderef' )
	{
		my %WHERE;

		my $len = $ATTRS->getLength();  # number of child nodes
		for my $i ( 0 .. $len - 1 )
		{
			my $ATTR = $ATTRS->item($i);
			next unless $ATTR;
			my $attr  = $ATTR->getName();
			my $value = $ATTR->getValue();

			next if $attr eq 'type' or $attr eq 'name';

			$WHERE{$attr} = $value;
		}

		$WHERE{title} = $contents;

		patchXMLwhere( \%WHERE );

		my $TYPE = getType( $WHERE{type_nodetype} );

		my $NODEID = selectNodeWhere( \%WHERE, $TYPE );

		if ($NODEID)
		{
			$PARSEDTAG{$name} = $NODEID->[0];
		}
		else
		{
			$PARSEDTAG{$name} = -1;

			# Return our "fix".  We need to mark what field this fix is for
			# and who created it
			@PARSEDTAG{qw( fixBy field where )} = ( $fixBy, $name, \%WHERE );
		}
	}
	elsif ( $type eq 'literal_value' )
	{
		$PARSEDTAG{$name} = $contents;
	}
	else
	{
		Everything::logErrors( '',
			"XML::parseBasicTag does not understand field type '$type'" );
	}

	return \%PARSEDTAG;
}

=cut


=head2 C<patchXMLwhere>

A utility method.

When parseBasicTag is called, we take an XML tag and if it is determined that
the tag is a noderef, we construct a where hash to try to find that node in our
system.  However, sometimes fields that identify a particular node point to a
node that has not been inserted yet.  This causes a problem where our 'where'
hash contains text information about nodes that do not yet existing the
database (they get installed later) rather than a node id.

This in itself is not a problem, but we need to make sure that when the fixes
come around that we update our where hash so that any references that didn't
exist before are now patched.

=over 4

=item * $WHERE

a hash ref to a where hash that we need to patch up

=back

Returns the where hash.

=cut

sub patchXMLwhere
{
	my ($WHERE) = @_;

	foreach my $attr ( keys %$WHERE )
	{
		if ( ( $attr =~ /_(\w*)/ ) && ( $$WHERE{$attr} =~ /^(.+?),(.+)$/ ) )
		{
			my $N = getNode( $1, $2 );
			$$WHERE{$attr} = $$N{node_id} if ($N);
		}
	}

	return $WHERE;
}

=cut


=cut


=head2 C<unMakeXmlSafe>

Decode something encoded by makeXmlSafe

=over 4

=item * $str

da string!

=back

Returns the decoded string.

=cut

sub unMakeXmlSafe
{
	my ($str) = @_;

	$str =~ s/\&lt\;/\</g;
	$str =~ s/\&gt\;/\>/g;
	$str =~ s/\&amp\;/\&/g;
	$str =~ s/\&quot\;/\"/g;

	return $str;
}

###########################################################################
sub getFieldType
{
	my ($field) = @_;

	# Check to see if the field name ends with a "_typename"
	if ( $field =~ /_(\w+)$/ && $1 ne "id" )
	{
		return "noderef";
	}

	return "literal_value";
}

my $installed_nodes = {};

sub xmlnode2node_basic {
    my ( $nodebase, $xmlnode) = @_;
    # $xmlnode should already be parsed and have attributes
    my $title =  $xmlnode->get_title;
    my $nodetype = $xmlnode->get_nodetype;
    my $node = $nodebase->getNode($title, $nodetype, 'create force' );
    my $id = $node->insert( -1 );
    $installed_nodes->{ $nodetype }->{ $title } = $id;

    return;
}

sub xmlnode2node_complete {
    my ( $nodebase, $xmlnode ) = @_;

    my $title =  $xmlnode->get_title;
    my $nodetype = $xmlnode->get_nodetype;

    my $node = $nodebase->getNode( $title, $nodetype );

    foreach ( @{ $xmlnode->get_attributes }) {
	if ( $_->get_type eq 'literal_value' ) {
	    $node->{ $_->get_name } = $_->get_content;
	} else {
	    my ( $att_nodetype ) = split /,/, $_->get_type_nodetype;
	    my $noderef = $nodebase->getNode( $_->get_content, $att_nodetype );
	    $node->{ $_->get_name } = $noderef->getId;
	}

    }

    my %vars = ();
    foreach ( @{ $xmlnode->get_vars }) {
	if ( $_->get_type eq 'literal_value' ) {
	    $vars{ $_->get_name } = $_->get_content;
	} else {
	    my ( $nodetype ) = split /,/, $_->get_type_nodetype;
	    my $noderef = $nodebase->getNode( $_->get_content, $nodetype );
	    $vars{ $_->get_name } = $noderef->getId;
	}

    }

    $node->setVars( \%vars ) if %vars;


    my @group = ();
    foreach ( @{ $xmlnode->get_group_members }) {

	    my ( $nodetype ) = split /,/, $_->get_type_nodetype;
	    my $noderef = $nodebase->getNode( $_->get_name, $nodetype );
	    push @group, $noderef->getId;
 
    }
    $node->{group} = \@group if @group;

    $node->update(-1, 'nomodified');

}

###########################################################################
# End of Package
###########################################################################

1;
