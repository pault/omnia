
=head1 Everything::XML

A module for the XML stuff in Everything

Copyright 2000 - 2003 Everything Development

=cut

package Everything::XML;

use strict;
use Everything;
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
			if ( $NODE->applyXMLFix( $FIX, $printError ) )
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
		$NODE->commitXMLFixes();
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

			my $fixes = $NODE->xmlTag($field);
			push @FIXES, @$fixes if $fixes;
		}

		if ($nofinal)
		{
			push @ids, $NODE;
			next;
		}

		my $id = $NODE->xmlFinal();

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


=head2 C<genBasicTag>

For most fields in a node, there are 2 types that the field could be.  Either a
literal value, or a reference to a node.  This function will generate the tag
based on the fieldname and the content.

=over 4

=item * $doc

the root document node for which this new tag belongs

=item * $tagname

the name of the xml tag

=item * $fieldname

the name of the field

=item * $content

the content of the tag

=back

  E<lt>tagname name="fieldname" *generated params*E<gt>contentE<lt>/tagnameE<gt>

Returns the generated XML tag.

=cut

sub genBasicTag
{
	my ( $doc, $tagname, $fieldname, $content ) = @_;
	my $isRef = 0;
	my $isNum = 0;
	my $type;
	my $xml;
	my $PARAMS = { name => $fieldname };
	my $data;

	# Check to see if the field name ends with a "_typename"
	if ( $fieldname =~ /_(\w+)$/ )
	{
		$type = $1;

		# if the numeric value is not greater than zero, it is a literal value.
		# Nodes cannot have an id of less than 1.
		$isRef = 1 if $content !~ /\D/ && $content > 0 && getRef($content);
	}

	if ($isRef)
	{

		# This field references a node
		my $REF = getNode($content);

		unless ( $REF->isOfType( $type, 1 ) )
		{
			Everything::logErrors( "Field '$fieldname' needs a node of type "
					. "'$type',\nbut it is pointing to a node of type "
					. "'$REF->{type}{title}'!" );
		}

		$data = makeXmlSafe( $$REF{title} );
		@$PARAMS{qw( type type_nodetype )} =
			( 'noderef', "$REF->{type}{title},nodetype" );

		# Merge the standard title/type with any unique identifiers given
		# by the node.
		my $ID = $REF->getIdentifyingFields() || ();

		foreach my $id (@$ID)
		{
			if ( $id =~ /_(\w*)$/ )
			{
				my $N = getNode( $REF->{$id} );
				$PARAMS->{$id} = "$N->{title},$N->{type}{title}";
			}
			else
			{
				$PARAMS->{$id} = $REF->{$id};
			}
		}
	}
	else
	{

		# This is just a literal value
		$data = $content;
		$PARAMS->{type} = 'literal_value';
	}

	# Now that we have gathered the attributes and data for this tag, we
	# need to construct it.
	my $tag      = XML::DOM::Element->new( $doc, $tagname );
	my $contents = XML::DOM::Text->new( $doc,    $data );

	# Set the attributes on the tag.  We sort the keys so that the
	# attributes come out in an ordered fashion.  That way we won't
	# get merge conflicts in CVS due to seemingly random order of
	# the attributes
	my @sortAttrs = sort { $a cmp $b } keys %$PARAMS;
	foreach my $param (@sortAttrs)
	{
		$tag->setAttribute( $param, $PARAMS->{$param} );
	}

	# And insert the content into our tag
	$tag->appendChild($contents);

	return $tag;
}

=cut


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
	$contents ||= '';

	$contents = unMakeXmlSafe($contents);

	my $ATTRS = $TAG->getAttributes();
	my $type  = $ATTRS->{type}->getValue();
	my $name  = $ATTRS->{name}->getValue();

	$PARSEDTAG{name} = $name;

	if ( $type eq 'noderef' )
	{
		my %WHERE;

		my $len = $ATTRS->getLength();
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


=head2 C<makeXmlSafe>

Make a string not interfere with the xml

=over 4

=item * $str

the literal string 

=back

Returns the encoded string.

=cut

sub makeXmlSafe
{
	my ($str) = @_;

	#we use an HTML convention...
	$str =~ s/\&/\&amp\;/g;
	$str =~ s/\</\&lt\;/g;
	$str =~ s/\>/\&gt\;/g;

	return $str;
}

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

###########################################################################
# End of Package
###########################################################################

1;
