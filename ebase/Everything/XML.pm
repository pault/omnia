package Everything::XML;

############################################################
#
#        Everything::XML.pm
#                A module for the XML stuff in Everything
#
############################################################

use strict;
use Everything;
use XML::Generator;
use XML::DOM;

sub BEGIN
{
   use Exporter();
   use vars qw($VERSIONS @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
   @ISA=qw(Exporter);
   @EXPORT=qw(
		xml2node
		xmlfile2node
		fixNodes 
		readTag	
		genBasicTag
		parseBasicTag
		patchXMLwhere
	);
}

# This version is used to make sure that we are importing something that
# was generated with an equal or earlier version of this parser/exporter.
my $XML_PARSER_VERSION = 0.5;
my %UNFIXED_NODES;


###########################################################################
#	Sub
#		readTag
#
#	purpose - to quickly read an xml tag, without parsing the whole document
#		right now, it doesn't read attributes, only contents.
#
sub readTag
{
	my ($tag, $xml) = @_;
	
	if ($xml =~ /\<field\s*name="$tag".*?\>(.*?)\<\/field\>/gsi)
	{
		return unMakeXmlSafe($1);
	}
	"";
}


#############################################################################
sub initXMLParser
{
	undef %UNFIXED_NODES;
}


#############################################################################
sub fixNodes
{
	my ($printError) = @_;

	foreach my $node (keys %UNFIXED_NODES)
	{
		my $NODE = getNode($node);
		my $UNFIXED = [];

		unless($NODE)
		{
			print "Error!  Node that we are supposed to fix is not here " .
				"(id $node)!\n" if($printError);
			next;
		}
		
		foreach my $FIX (@{$UNFIXED_NODES{$node}})
		{
			if($NODE->applyXMLFix($FIX, $printError))
			{
				# The node attempted to apply the fix, but none was found.
				# Put them back at the start, so we don't run through them
				# again.
				unshift @$UNFIXED, $FIX;
			}
		}

		if(@$UNFIXED > 0)
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


#########################################################################
#	Function
#		xml2node
#
#	Purpose
#		takes a chunk of XML -- returns a $NODE hash
#		any broken dependancies are pushed on @FIXES, and the node is 
#		inserted into the database (with -1 on any broken fields)
#		returns the node_id of the new node
#
#	Parameters
#		xml -- the string of xml to parse
#
#	Returns
#		An array ref of node id's that were parsed from the xml and
#		inserted or updated.
#
sub xml2node
{
	my ($xml) = @_;

	# XML::Parser doen't like it when there is more than one top level
	# document tag.  If we have an XML file that contains more than one
	# node, XML::Parser will error on it.  So, to make everything happy,
	# we just wrap the entire doc in a single tag.
	$xml = "<everything>\n" . $xml . "\n</everything>";
	
	my $XMLPARSER = new XML::DOM::Parser (ErrorContext => 2,
		ProtocolEncoding => 'ISO-8859-1');
	my $doc = $XMLPARSER->parse ($xml);
	my @ids;
	my $NODE;


	# A single XML file may contain multiple nodes (same name/type).  We
	# iterate through each defined node.
	my @nodes = $doc->getElementsByTagName("NODE");

	foreach my $node (@nodes)
	{
		my $title = $node->getAttribute("title");
		my $type = $node->getAttribute("nodetype");
		my $version = $node->getAttribute("export_version");
		my @FIXES;

		if($version > $XML_PARSER_VERSION)
		{
			print "Warning!  XML was created with a newer version of " .
				"Everything.  This\nmay not import correctly.\n";
		}
		
		# Start with a basic node.  We force create this to avoid over
		# writing any existing nodes... see xmlFinal() for more info.
		$NODE = getNode($title, $type, "create force");

		# Note, we are using XML::DOM::Node here.  Don't get the DOM
		# API confused with our API.  The 'Nodes' idea can be confusing.
		my @childFields = $node->getChildNodes();
		foreach my $field (@childFields)
		{
			# If this child is not a tag (node) skip it.  We don't care
			# about text within the <NODE> tag.
			next if($field->getNodeType() == XML::DOM::TEXT_NODE());
			
			my $fixes = $NODE->xmlTag($field);
			push @FIXES, @$fixes if($fixes);
		}

		my $id = $NODE->xmlFinal();

		if($id > 0)
		{
			push @ids, $id;
		}
		else
		{
			print "Error!  Failed to import node '$$NODE{title}'\n";
		}

		# We store any fixes that node reported so we can hopefully
		# resolve them later.
		$UNFIXED_NODES{$id} = \@FIXES if(@FIXES > 0)
	}

	return \@ids;
}


#############################################################################
#
#	Sub
#		xmlfile2node
#
#	purpose
#		Wrapper for xml2node that takes a filename as a parameter
#		rather than a string of XML
#
#
sub xmlfile2node
{
    my ($filename) = @_;
	my $file;

	open MYXML, $filename or die "could not access file $filename";
	
	$file = join "", <MYXML>;
	close MYXML;
	
	xml2node($file);
}


#############################################################################
#	Sub
#		genBasicTag
#
#	Purpose
#		For most fields in a node, there are 2 types that the field could
#		be.  Either a literal value, or a reference to a node.  This
#		function will generate the tag based on the fieldname and the
#		content.
#
#	Parameters
#		$doc - the root document node for which this new tag belongs
#		$tagname - the name of the xml tag
#		$fieldname - the name of the field
#		$content - the content of the tag
#
#	<tagname name="fieldname" *generated params*>content</tagname>
#
#	Returns
#		The generated XML tag
#
sub genBasicTag
{
	my ($doc, $tagname, $fieldname, $content) = @_;
	my $isRef = 0;
	my $isNum = 0;
	my $type;
	my $xml;
	my $PARAMS;
	my $data;

	# Check to see if the field name ends with a "_typename"
	if($fieldname =~ /_(\w+)$/)
	{
		$type = $1;

		# if the numeric value is not greater than zero, it is a liter value.
		# Nodes cannot have an id of less than 1.
		$isRef = 1 if($content =~ /^\d+$/ && $content > 0);
	}

	if($isRef)
	{
		# This field references a node
		my $REF = getNode($content);

		unless($REF->isOfType($type, 1))
		{
			print "Warning! Field '$fieldname' needs a node of type '$type', " .
				"but it is pointing to a node of type '$$REF{type}{title}'!\n";
		}

		$data = makeXmlSafe($$REF{title});
		$PARAMS = { name => $fieldname, type => "noderef",
			type_nodetype => "$$REF{type}{title},nodetype" };

		# Merge the standard title/type with any unique identifiers given
		# by the node.
		my $ID = $REF->getIdentifyingFields();
		$ID ||= ();

		foreach my $id (@$ID)
		{
			if($id =~ /_(\w*)$/)
			{
				my $N = getNode($$REF{$id});
				$$PARAMS{$id} = "$$N{title},$$N{type}{title}";
			}
			else
			{
				$$PARAMS{$id} = $$REF{$id};
			}
		}
	}
	else
	{
		# This is just a literal value
		#$data = makeXmlSafe($content);
		$data = $content;
		$PARAMS = { name => $fieldname, type => "literal_value" };
	}

	# Now that we have gathered the attributes and data for this tag, we
	# need to construct it.
	my $tag = new XML::DOM::Element($doc, $tagname);
	my $contents = new XML::DOM::Text($doc, $data);

	# Set the attributes on the tag.
	foreach my $param (keys %$PARAMS)
	{
		$tag->setAttribute($param, $$PARAMS{$param});
	}

	# And insert the content into our tag
	$tag->appendChild($contents);
	
	return $tag;
}


#############################################################################
#	Sub
#		parseBasicTag
#
#	Purpose
#		
sub parseBasicTag
{
	my ($TAG, $fixBy) = @_;
	my %PARSEDTAG;
	my %WHERE;
	
	# Our contents is always the first TEXT_NODE object... just convert
	# it to a string, which is what we want anyway. 
	my $contents = $TAG->getFirstChild()->toString();

	$contents = unMakeXmlSafe($contents);

	my $ATTRS = $TAG->getAttributes();
	my $type = $$ATTRS{type}->getValue();
	my $name = $$ATTRS{name}->getValue();

	$PARSEDTAG{name} = $name;
	if($type eq "noderef")
	{
		my %WHERE;

		my $len = $ATTRS->getLength();
		for (my $i = 0;  $i < $len; $i++)
		{
			my $ATTR = $ATTRS->item($i);
			my $attr = $ATTR->getName();
			my $value = $ATTR->getValue();

			next if($attr eq "type");
			next if($attr eq "name");

			$WHERE{$attr} = $value;
		}

		$WHERE{title} = $contents;
		
		patchXMLwhere(\%WHERE);

		my $TYPE = getType($WHERE{type_nodetype});
		my $NODEREF = getNode(\%WHERE, $TYPE);
		if($NODEREF)
		{
			$PARSEDTAG{$name} = $$NODEREF{node_id};
		}
		else
		{
			$PARSEDTAG{$name} = -1;

			# Return our "fix".  We need to mark what field this fix is for
			# and who created it
			$PARSEDTAG{fixBy} = $fixBy;
			$PARSEDTAG{field} = $name;

			$PARSEDTAG{where} = \%WHERE;
		}
	}
	elsif($type eq "literal_value")
	{
		$PARSEDTAG{$name} = $contents;
	}
	else
	{
		print "Error! XML::parseBasicTag does not understand field type '$type'\n";
	}

	return \%PARSEDTAG;
}


#############################################################################
#	Sub
#		patchXMLwhere
#
#	Purpose
#		A utility method.
#		When parseBasicTag is called, we take an XML tag and if it is
#		determined that the tag is a noderef, we construct a where hash
#		to try to find that node in our system.  However, sometimes fields
#		that identify a particular node point to a node that has not been
#		inserted yet.  This causes a problem where our 'where' hash contains
#		text information about nodes that do not yet existing the database
#		(they get installed later) rather than a node id.
#
#		This in itself is not a problem, but we need to make sure that
#		when the fixes come around that we update our where hash so that
#		any references that didn't exist before are now patched.
#
#	Parameters
#		$WHERE - a hash ref to a where hash that we need to patch up.
#
#	Returns
#		The where hash
#
sub patchXMLwhere
{
	my ($WHERE) = @_;

	foreach my $attr (keys %$WHERE)
	{
		if(($attr =~ /_(\w*)/) && ($$WHERE{$attr} =~ /^(.+?),(.+)$/))
		{
			my $N = getNode($1, $2);
			$$WHERE{$attr} = $$N{node_id} if($N);
		}
	}

	return $WHERE;
}


#####################################################################
#	Sub
#		makeXmlSafe
#
#	Purpose
#		Make a string not interfere with the xml
#
#	Parameters
#		$str - the literal string 
#
#	Returns
#		The encoded string.
#
sub makeXmlSafe {
	my ($str) = @_;

	#we use an HTML convention...  
	$str =~ s/\&/\&amp\;/g;
	$str =~ s/\</\&lt\;/g;
	$str =~ s/\>/\&gt\;/g;

	return $str;
}

#####################################################################
#	Sub
#		unMakeXmlSafe
#
#	Purpose 
#		Decode something encoded by makeXmlSafe
#	
#	Parameters
#		$str - da string!
#	
#	Returns
#		The decoded string.
#
sub unMakeXmlSafe {
	my ($str) = @_;

	$str =~ s/\&lt\;/\</g;
	$str =~ s/\&gt\;/\>/g;
	$str =~ s/\&amp\;/\&/g;
	return $str;
}



###########################################################################
sub getFieldType
{
	my ($field) = @_;
	
	# Check to see if the field name ends with a "_typename"
	if($field =~ /_(\w+)$/ && $1 ne "id")
	{
		return "noderef";
	}

	return "literal_value";
}


###########################################################################
# End of Package
###########################################################################

1;
