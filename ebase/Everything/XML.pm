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
use XML::Parser;

sub BEGIN
{
   use Exporter();
   use vars qw($VERSIONS @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
   @ISA=qw(Exporter);
   @EXPORT=qw(
      xml2node
      xmlfile2node
      node2xml
	  initXmlParse
	  fixNodes 
	  dumpFixes
	  readTag	
	);
}

use vars qw($NODE);
use vars qw($VARS);
use vars qw($isVars);
use vars qw(@activetag);
use vars qw(%TABLES);
use vars qw(@FIXES);
use vars qw($XMLGEN);
use vars qw($XMLPARSE);
	
# Skip these tags in the node XML
my %skips = {
	"NODE" => 1,
	"INFO" => 1
};

###########################################################################
#	Sub
#		readTag
#
#	purpose - to quickly read an xml tag, without parsing the whole document
#		right now, it doesn't read attributes, only contents.
#
sub readTag {
	my ($tag, $xml) = @_;
	if ($xml =~ /\<\s*$tag.*?\>(.*?)\<\s*\/$tag.*?\>/gsi) {
		return unMakeXmlSafe($1);
	}
	"";
}


#############################################################################
#	Sub
#		start_handler
#
#	Purpose  
#		This is a callback for the XML parser.  This gets called when we
#		hit a start XML tag.
#
sub start_handler
{
	my $parser = shift @_;
	my $tag = shift @_;
	
	# Initialize the tag
	my $isReference = 0;

	unless(exists $skips{$tag})
	{
		# Clear the field for this tag.  We will set it later.
		$$NODE{$tag} = "";

		while (@_) 
		{
			my $attr = shift @_;
			my $val = shift @_;
			
			if ($attr eq "table")
			{
				$isVars = 1 if ($tag eq "vars");

				# Add this tag to the list of fields for the given table.
				push @{ $TABLES{$val} }, $tag;	
			}
			elsif (($attr eq "type") && ($val ne "literal_value"))
			{
				# This tag represents a reference to another node.  Add
				# this to the list of fixes that we will need to apply later.
				$isReference=1;
				push @FIXES, { type => $val, field => $tag, title => $tag,
					isVars => $isVars, node_id => 0 };
			}
		}
	}

	push @activetag, { isReference => $isReference, title => $tag};
}


#############################################################################
#	Sub
#		char_handler
#
#	Purpose
#		Callback for the XML parser, this gets called on data between the
#		start and end tag.
#
sub char_handler
{
	my ($parser, $data) = @_;
	my $tag = pop @activetag;

	unless(exists $skips{$$tag{title}})
	{
		if ($isVars) {
			$$VARS{$$tag{title}} .= $data;
		} else {
			$$NODE{$$tag{title}} .= $data;
		}
	}

	push @activetag, $tag;
}

#############################################################################
#	Sub
#		end_handler
#
#	Purpose
#		Callback for the XML parser.  This gets called when it encounters
#		the end tag.
#
sub end_handler
{
	my $tag = pop @activetag;

	return if(exists $skips{$$tag{title}});
	
	if ($isVars and $$tag{isReference})
	{
		my $fix = pop @FIXES;
		$$fix{title} = $$VARS{$$tag{title}};
		push @FIXES, $fix;
		$$VARS{$$tag{title}} = -1;
	}
	elsif ($$tag{isReference})
	{
		# If this tag is a field value that is reference to another node,
		# we need to check to see if we have the node in the system.
		# Otherwise we need to mark it for fixing.

		# Set the title of the fix
		my $fix = pop @FIXES;
		$$fix{title} = $$NODE{$$tag{title}};
		my $type = $$fix{type};
		my $found = 0;

		unless($$fix{isVars} or $$fix{field} =~ /^groupnode/)
		{
			my $REF = getNode($$NODE{$$tag{title}}, $type); 
			if ($REF)
			{
				# When installing nodes, the type_nodetype may be a string
				# name, but we really want the Id.
				$$NODE{$$tag{title}} = getId $REF; 	
				$found = 1;
			}
			else
			{
				# Note: if this happens for a reference to a nodetype
				# (specifically the type_nodetype field) this will be a fatal
				# error as all nodetypes are expected to be installed first.
				$$NODE{$$tag{title}} = -1;
			}
		}
		
		# If we did not find the node that this field references, we need
		# to push the fix back on the fix list.
		push @FIXES, $fix unless($found);
	}
	elsif ($$tag{title} eq "vars")
	{
		$isVars = 0;
		delete $$VARS{vars};
	}
}


##############################################################################
#	sub
#		findRef
#
#	purpose
#		find a node referred to by a node reference.  Spit out an error if 
#		it isn't found and the printError flag is set.  
#		Returns the referenced node's id
#
sub findRef
{
	my ($FIX, $printError) = @_;
	my $id;

	my $REFNODE = getNode($$FIX{title}, getType($$FIX{type}));

	$id = getId $REFNODE;
	if (not $id)
	{
		print "ERROR!  Fix failed on $$FIX{node_id}: needs" .
				" a $$FIX{type} named $$FIX{title}\n" if $printError;	 
		return -1;
	}

	return $id;
}


#############################################################################
#	sub
#		fixNodes		
#
#	purpose
#		fix all errors registered in the @FIXES array
#		these are usually broken dependancies, and node references
#		to nodes that didn't exist when the node was inserted from the XML
#
sub fixNodes 
{
	my ($printError) = @_;
	my @UNFIXED;
	my $fix;
	my %FIELDS;
	my %VARS;
	my $FIXHASH;
	my $VARSHASH;
	my $N;
	my $NODE;
	
	# First, lets organize all the fixes by node.  This way we can update
	# each node all at once instead of hitting the database for each field
	# update.  This helps while updating a site under load.
	while ($fix = shift @FIXES)
	{
		next if ($$fix{field} eq "group");
		
		my $id = findRef $fix, $printError;
		
		if ($id == -1)
		{
			# the node that we have a dependancy for isn't available.  It
			# may be coming later so store the unfixed ones.
			push @UNFIXED, $fix;
			next;
		}
		
		if ($$fix{isVars})
		{
			# This fix is for a reference in a vars "hash" field.  We need
			# to store them in our %VARS hash.
			my $FIXVARS = $VARS{$$fix{node_id}};
			$FIXVARS ||= {};

			$$FIXVARS{$$fix{field}} = $id;

			# Put the fixes back in the parent hash.
			$VARS{$$fix{node_id}} = $FIXVARS;
		}
		elsif ($$fix{field} =~ /^groupnode/)
		{	
			# This fix is for a node in a nodegroup.
			# Each addition to a group is an SQL insert so we can't do them
			# all at once to save time (well, technically we could, but oh
			# well).  We will just add the node to the group here since we
			# have all the needed data anyway.
			my $GROUP = getNode($$fix{node_id});
			$GROUP->insertIntoGroup(-1, $id);
		}
		else
		{
			# This is a fix for a database field.  We store all the
			# fields/fix pairs in a hash, that is stored in a parent hash
			# keyed by the node id.
			$FIXHASH = $FIELDS{$$fix{node_id}};
			$FIXHASH ||= {};

			$$FIXHASH{$$fix{field}} = $id;

			# Put the fix hash back in the parent hash
			$FIELDS{$$fix{node_id}} = $FIXHASH;
		}
	}
	
	# Leave unresolved fixes on the list
	push @FIXES, @UNFIXED;

	# OK, all of the fixes that we were able to find are stored in the
	# the %FIELDS hash.  Lets update all them nodes.
	foreach $N (keys %FIELDS)
	{
		my $field;
		my $FIXHASH;

		$NODE = getNode($N);
		$FIXHASH = $FIELDS{$N};

		next unless($FIXHASH);

		foreach $field (keys %$FIXHASH)
		{
			$$NODE{$field} = $$FIXHASH{$field};
		}

		$NODE->update(-1);
	}

	# Update all the nodes that have a vars field that contains
	# unresolved references
	foreach $N (keys %VARS)
	{
		my $TEMPVARS;
		my $setvars;
		my $FIXVARS;

		$NODE = getNode($N);
		$setvars = 0;
		$TEMPVARS = $NODE->getVars();
		$FIXVARS = $VARS{$N};
		
		next unless($FIXVARS);

		foreach my $var (keys %$FIXVARS)
		{
			# Settings are usually specific to a site.  We don't want to
			# overwrite any custom settings they may have, so only set
			# the ones that do not exist.
			if( (not exists $$TEMPVARS{$var}) or ($$TEMPVARS{$var} == -1))
			{
				$$TEMPVARS{$var} = $$FIXVARS{$var};
				$setvars = 1;
			}
		}

		$NODE->setVars($TEMPVARS, -1) if($setvars);
	}
}


###########################################################################
#	sub 
#		dumpFixes
#
#	purpose
#		print out the fixes array for debugging
#
sub dumpFixes {
	foreach (@FIXES) {
		print "Node $$_{node_id} needs $$_{title} ($$_{type}) for "
			."its $$_{field} field.";
		print "  (VARS)  " if $$_{isVars};
		print "\n";
	}
}


###########################################################################
#	Sub
#		initXmlParse
#	
#	purpose
#		initialize the global XMLPARSE object, and returns it
#		if you care.
#
#
sub initXmlParse
{
	$XMLPARSE ||= new XML::Parser (ErrorContext => 2);
	$XMLPARSE->setHandlers(Char => \&char_handler, End => \&end_handler,
		Start => \&start_handler);

	@FIXES = ();

	$XMLPARSE;
}


#########################################################################
#	Function
#		xml2node
#
#	purpose
#		takes a chunk of XML -- returns a $NODE hash
#		any broken dependancies are pushed on @FIXES, and the node is 
#		inserted into the database (with -1 on any broken fields)
#		returns the node_id of the new node
#
#	parameters
#		xml -- the string of xml to parse
#
sub xml2node
{
	my ($xml) = @_;
	my $TYPE;
	
	# Start with a clean "vars".
	%TABLES = ();
	%$NODE = ();
	%$VARS = ();
	$isVars = 0;

	my $node_id;

	# parse the XML
	$XMLPARSE = initXmlParse unless $XMLPARSE;
	$XMLPARSE->parse($xml);
	
	# At this point the $NODE hash has been constructed from the XML
	# data by the parser.
	
	$TYPE = getType($$NODE{type_nodetype});
	if (defined $TYPE)
	{
		#we already have the nodetype for this loaded...
		my $title = $$NODE{title};
		my %data = ();
		my $tableArray = $TYPE->getTableArray(1);
		
		my @fields;
		my $table;
		
		foreach $table (@$tableArray)
		{
			push @fields, @{ $TABLES{$table} };
		}

		#perhaps we already have this node, in which case we should update it
		my $OLDNODE = getNode($title, $TYPE);
		my $OLDVARS;
	
		if ($OLDNODE)
		{
			# We already have a node of this title/type.  Update it.

			$OLDVARS = $OLDNODE->getVars() if($OLDNODE->hasVars());

			@$OLDNODE{@fields} = @$NODE{@fields};
			$OLDNODE->replaceGroup([], -1) if ($OLDNODE->isGroup());
			$node_id = $OLDNODE->update(-1);
		}
		else
		{
			# This node does not exist.  We need to insert it into the
			# database.

			# We insert the group nodes ids during the parsing of the XML,
			# so, we don't want to do anything with them here.
			if ($TYPE->isGroup())
			{
				foreach (keys %$NODE)
				{
					delete $$NODE{$_} if /^groupnode/;
				}
			}

			my $NEWNODE = getNode($title, $TYPE, "create");
			@$NEWNODE{@fields} = @$NODE{@fields};
			if($title eq 'default theme')
			{
				my $a = 0;
			}
			$node_id = $NEWNODE->insert(-1);
		}

		if (keys %$VARS)
		{
			# we never replace old settings in a setting node 
			@$VARS{keys %$OLDVARS} = values %$OLDVARS if($OLDVARS);
			my $VARNODE = getNode($node_id);
			$VARNODE->setVars($VARS);
		}

		# When we were parsing this node from XML, we didn't know what id
		# it was going to be.  So, now that we know, we go through all the
		# fixes and find the ones that do not have an id.  If we find any,
		# we know that the "fix" belongs to this node.  So, assign those
		# fixes to this node!
		foreach (@FIXES)
		{
			$$_{node_id} = $node_id if($$_{node_id} == 0);
		}

		return $node_id;
	}

	print "Error: No nodetype!  (id or name: '$$NODE{type_nodetype}')\n";
	print "Looks like the nodeball is missing a dependency or is\n";
	print "lacking a nodetype that it was supposed to have.\n";
	print "Exiting...\n";
	exit(0);
}

####################################################################
#
#	Sub
#		xmlfile2node
#
#	purpose
#		wrapper for xml2node that takes a filename as a parameter
#		rather than a string of XML
#
#
sub xmlfile2node {
    my ($filename) = @_;
		
	open MYXML, $filename or die "could not access file $filename";
	my $file = join "", <MYXML>;
	close MYXML;
	xml2node($file);
}

####################################################################
#
#	Sub 
#		genTag
#
#	purpose
#		simple wrapper function to generate an xml tag
#		using XML::Generator
#
#	parameters
#		tag -- the name of the tag to generate
#		content -- the stuff to be put inside the tag
#		PARAMS -- hash reference containing tag attributes
#		embedXML -- don't make the content xml-safe (we'll embed XML)

sub genTag {
	my ($tag, $content, $PARAMS, $embedXML) = @_;
	return unless $tag;
	$PARAMS ||= {};
	
	$XMLGEN = new XML::Generator if not $XMLGEN; 
	
	no strict 'refs';
	$content = makeXmlSafe($content) unless $embedXML;	
	*{(ref $XMLGEN) ."::$tag"}->($XMLGEN, $PARAMS, $content)."\n";
	#tricky, but that's how XML::Generator works...
}

#####################################################################
#	Sub
#		makeXmlSafe
#
#	purpose
#		make a string not interfere with the xml
#
#	parameters
#		str - the literal string 
sub makeXmlSafe {
	my ($str) = @_;

	#we use an HTML convention...  
	$str =~ s/\&/\&amp\;/g;
	$str =~ s/\</\&lt\;/g;
	$str =~ s/\>/\&gt\;/g;

	$str;
}

#####################################################################
#	Sub
#		unMakeXmlSafe
#
#	purpose 
#		decode something encoded by makeXmlSafe
#	
#	parameters
#		str - da string!
sub unMakeXmlSafe {
	my ($str) = @_;

	$str =~ s/\&amp\;/\&/g;
	$str =~ s/\&lt\;/\</g;
	$str =~ s/\&gt\;/\>/g;
	$str;
}

######################################################################
#	Sub
#		vars2xml
#
#	purpose
#		Take a "vars" hash -- generate a vars tag with nested item tags
#		also, change node references to a type/title format
#
#	parameters
#		tag - the varable tag 
#		VARS - a hash reference containing the variable data 
#			(procured from getVars)
#		PARAMS - optional additional parameters
#
sub vars2xml
{
	my ($tag, $VARS, $PARAMS) = @_;
	$PARAMS ||= {};
	my $varstr = "";
	
	foreach my $key (keys %$VARS)
	{
		$varstr.="\t\t";

		# Kind of a hack... but it works (reuse dat code!)
		my $type = Everything::Node::node::getFieldDatatype($VARS, $key);
		if ($type eq "noderef")
		{
			# this is a node reference
			$varstr .= noderef2xml($key, $$VARS{$key});
		}
		elsif($type eq "literal_value")
		{
			$varstr .= genTag $key, $$VARS{$key}; 
		}
	}

	genTag ($tag, "\n".$varstr."\t", $PARAMS, 'parseth not the xml tags');
}


#############################################################################
#	Sub
# 		group2xml
#
#	purpose
#		take a list of node references and return them in XML form
#		
#   parameters
#		tag -- the group's parent tag
#		group- a reference to a list of nodes
#		PARAMS -- hash reference with optional additional parameters
#
sub group2xml
{
	my ($tag, $group, $PARAMS) = @_;
	$PARAMS ||= {};
	my $ingroup = "";
	my $count = 1;
	foreach (@$group)
	{
		my $tag = "groupnode" . $count++;
		$ingroup .= "\t\t" .
			noderef2xml($tag, $_, { table=>'nodegroup' }) ;
	}

	genTag($tag, "\n".$ingroup."\t", $PARAMS, "don't parse me please");
}


##################################################################
#	Sub
#		noderef2xml
#
#	purpose
#		generate a tag that references a node by type and title
#
#	parameters
#		tag -- the field to generate
#		node_id -- the node's numeric id (or the node itself)
#		PARAMS -- additional attributes for the tag
#
sub noderef2xml
{
	my ($tag, $node_id, $PARAMS) = @_;
	$PARAMS ||= {};

	my $POINTED_TO = getNode($node_id);
	my ($title, $typetitle, $TYPE);

	if ($POINTED_TO)
	{
		$title = $$POINTED_TO{title};
		$typetitle = $$POINTED_TO{type}{title};
	}
	else
	{
		# This can happen with the '-1' field values when nodetypes
		# are inherited.
		$title = $node_id;
		$typetitle = "literal_value";
	}

	$$PARAMS{type}  = $typetitle;

	genTag ($tag, $title, $PARAMS);
}


###################################################################
#	Sub
#		node2xml
#
#	purpose
#		return a node to us in PORTABLE well-formed XML
#
#	parameters
#		NODE - the node to generate XML for
#
sub node2xml
{
	my ($NODE) = @_;

	getRef($NODE);
	return unless(ref $NODE);

	my $goodfields = $NODE->getNodeKeys(1);
	my $N = {};
	my $str;

	# Put the exportable fields in the copied node
	foreach (keys %$goodfields)
	{
		$$N{$_} = $$NODE{$_};
	}

	$XMLGEN = new XML::Generator unless $XMLGEN;

	# note: should also include server, date/time info
	$str .= $XMLGEN->INFO('rendered by Everything::XML.pm') ."\n";

	my $tables = $NODE->getTables(1);
	my %fieldtable; 

	# Construct the fieldtable hash. fieldname -> table it belongs to
	foreach my $table (@$tables)
	{
		my @fields = $DB->getFields($table);
		foreach (@fields)
		{ 
			$fieldtable{$_} = $table if (exists $$N{$_}); 
		}	
	}

	#now we catch the node table
	my @keys = sort {$a cmp $b} (keys %$N);	
	foreach my $field (@keys)
	{
		my $datatype = $NODE->getFieldDatatype($field);

		# This field needs two identifiers, what table the field belongs to
		# and what kind of datatype it is.
		my $attr = { table => $fieldtable{$field} };

		$str .= "\t";	
		if ($datatype eq "group")
		{
			#we have to deal with a group
			delete $$attr{table};
			$str .= group2xml($field, $$N{$field}, $attr);
		}
		elsif ($datatype eq "vars")
		{
			# we have a setting hash
			my $VARS = $NODE->getVars();
			$str .= vars2xml($field, $VARS, $attr);
		}
		elsif ($datatype eq "noderef")
		{
			# This field is a node reference.  We need to resolve this
			# reference to a node name and type.
			$str .= noderef2xml($field, $$N{$field}, $attr);
		} 
		elsif ($datatype eq "literal_value")
		{ 
			$str .= genTag($field, $$N{$field}, $attr);
		}
		else
		{
			print "Warning: Unknown export type '$datatype' for field '$field'\n";
		}
	}

	$XMLGEN->NODE($str);
}

###########################################################################
# End of Package
###########################################################################

1;
