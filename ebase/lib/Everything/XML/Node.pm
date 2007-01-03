=head1 Everything::XML::Node

A package to turn nodes into XML for exporting to Nodeballs and revisions.

=cut

package Everything::XML::Node;

{
    use Object::InsideOut;

    my @node
      :Field
      :Standard(node)
      :Arg(node);

    my @nodebase
      :Field
      :Standard(nodebase)
      :Arg(nodebase);

}


=head2 C<fieldToXML_vars>

This is called when the node is being exported to XML and the field we
are creating is a var field.

=over 4

=item * $DOC

an XML::DOM::Document object that this field belongs to

=item * $field

the field of this node that needs to be exported as XML

=item * $indent

string that contains the amount that this will be indented (used for formatting
purposes)

=back

Returns the XML::DOM::Element that represents this field.

=cut

sub fieldToXML_vars
{
	my ( $this, $DOC, $field, $indent ) = @_;
	$indent ||= '';

	my $VARS = XML::DOM::Element->new( $DOC, "vars" );
	my $vars = $this->get_node->getVars();
	my @raw  = keys %$vars;
	my @vars = sort { $a cmp $b } @raw;
	my $indentself  = "\n" . $indent;
	my $indentchild = $indentself . "  ";

	foreach my $var (@vars)
	{
		$VARS->appendChild( XML::DOM::Text->new( $DOC, $indentchild ) );
		my $tag = $this->genBasicTag( $DOC, "var", $var, $$vars{$var} );
		$VARS->appendChild($tag);
	}

	$VARS->appendChild( XML::DOM::Text->new( $DOC, $indentself ) );

	return $VARS;
}


=head2 C<fieldToXML_group>

Convert the field that contains the group structure to an XML format.

=over 4

=item * $DOC

the base XML::DOM::Document object that contains this structure

=item * $field

the field of the node to convert (if it is not the group field, we just call
SUPER())

=item * $indent

string that contains the spaces that this will be indented

=back

=cut

sub fieldToXML_group
{
	my ( $this, $DOC, $field, $indent ) = @_;

	my $GROUP       = XML::DOM::Element->new( $DOC, 'group' );
	my $indentself  = "\n" . $indent;
	my $indentchild = $indentself . "  ";

	for my $member ( @{ $this->get_node->{group} } )
	{
		$GROUP->appendChild( XML::DOM::Text->new( $DOC, $indentchild ) );

		my $tag = $this->genBasicTag( $DOC, 'member', 'group_node', $member );
		$GROUP->appendChild($tag);
	}

	$GROUP->appendChild( XML::DOM::Text->new( $DOC, $indentself ) );

	return $GROUP;
}


sub fieldToXML_field {

    my ( $this, $DOC, $field, $indent ) = @_;
    return $this->genBasicTag( $DOC, 'field', $field, $this->get_node->{$field} );
}

=head2 C<fieldToXML>

Given a field of this node (ie title), convert that field into an XML tag.

=over 4

=item * $DOC

the base XML::DOM::Document object that this tag belongs to

=item * $field

the field of the node to convert

=item * $indent

string that contains the amount this tag will be indented.  node::fieldToXML
does not use this.  This is for more complicated structures that want to have a
nice formatting.  This lets them know how far they are going to be indented so
they know how far to indent their children.

=back

Returns an XML::DOM::Element object that can be inserted into the parent
structure.

=cut

sub fieldToXML
{
	my ( $this, $DOC, $field, $indent ) = @_;
	return unless exists $this->get_node->{$field};

	my %dispatches = ( field => \&fieldToXML_field,
			   group => \&fieldToXML_group,
			   vars => \&fieldToXML_vars,
			 );

	my $sub = $dispatches{$field} || $dispatches{'field'};
	return $sub->(@_);
}


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
	my ( $this, $doc, $tagname, $fieldname, $content ) = @_;
	my $db = $this->get_nodebase;
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
		$isRef = 1 if $content !~ /\D/ && $content > 0 && $db->getRef($content);
	}

	if ($isRef)
	{

		# This field references a node
		my $REF = $db->getNode($content);

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
				my $N = $db->getNode( $REF->{$id} );
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


=head2 C<toXML>

This returns a string that contains an XML representation for this node.
A way to export this node.

Returns the XML string.

=cut

sub toXML
{
	my ($this) = @_;
	my $DOC = new XML::DOM::Document();
	my $NODE;
	my $enode = $this->get_node;
	my $exportFields = $enode->getNodeKeys(1);
	my $tag;
	my @fields;
	my @rawFields;

	push @rawFields, keys %$exportFields;

	# This is used to determine if our parser can read in a particular
	# export.  If the parser is upgraded/modified, this should be bumped
	# so that older versions of this code will know that it may have
	# problems reading in XML that generated by a newer version.
	my $XMLVERSION = "0.5";

	$NODE = new XML::DOM::Element( $DOC, "NODE" );

	$NODE->setAttribute( "export_version", $XMLVERSION );
	$NODE->setAttribute( "nodetype",       $$enode{type}{title} );
	$NODE->setAttribute( "title",          $$enode{title} );

	# Sort them so that the exported XML has some order to it.
	@fields = sort { $a cmp $b } @rawFields;

	foreach my $field (@fields)
	{
		$NODE->appendChild( new XML::DOM::Text( $DOC, "\n  " ) );

		$tag = $this->fieldToXML( $DOC, $field, "  " );
		$NODE->appendChild($tag);
	}

	$NODE->appendChild( new XML::DOM::Text( $DOC, "\n" ) );

	$DOC->appendChild($NODE);

	# Return the structure as a string
	return $DOC->toString();
}


1;
