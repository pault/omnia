package Everything::HTML;

#############################################################################
#
#	Everything::HTML.pm
#
#	Copyright 1999,2000 Everything Development Company
#
#		A module for the HTML stuff in Everything.  This
#		takes care of CGI, cookies, and the basic HTML
#		front end.
#
#############################################################################

use strict;
use Everything;
use Everything::MAIL;
use CGI;
use CGI::Carp qw(fatalsToBrowser);


sub BEGIN {
	use Exporter ();
	use vars qw($DB $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		$DB
		%HTMLVARS
		%GLOBAL
		$query
		jsWindow
		parseLinks
		htmlScreen
		htmlFormatErr
		quote
		urlGen
		getCode
		getPage
		getPages
		getPageForType
		linkNode
		linkNodeTitle
		searchForNodeByName
		evalCode
		htmlcode
		embedCode
		displayPage
		gotoNode
		confirmUser
		encodeHTML
		decodeHTML
		mod_perlInit);
}

use vars qw($query);
use vars qw(%HTMLVARS);
use vars qw(%GLOBAL);  # This is used for nodes to pass vars back-n-forth
use vars qw($GNODE);
use vars qw($USER);
use vars qw($VARS);
use vars qw($THEME);
use vars qw($NODELET);



####### Depricated functions #############
sub getVars
{ 
	my ($NODE) = @_;
	getRef($NODE);
	return $NODE->getVars();
}

sub setVars
{ 
	my ($NODE, $VARS) = @_;
	getRef($NODE);
	return $NODE->setVars($VARS, -1);
}

sub insertIntoNodegroup
{
	my ($GROUP, $USER, $insert, $orderby) = @_;
	getRef($GROUP);
	return $GROUP->insertIntoGroup($USER, $insert, $orderby);
}

sub replaceNodegroup
{
	my ($GROUP, $REPLACE, $USER) = @_;
	getRef($GROUP);
	return $GROUP->replaceGroup($REPLACE, $USER);
}

sub removeFromNodegroup
{
	my ($GROUP, $NODE, $USER) = @_;
	getRef($GROUP);
	return $GROUP->removeFromGroup($NODE, $USER);
}


######################################################################
#	sub
#		tagApprove
#
#	purpose
#		determines whether or not a tag (and it's specified attributes)
#		are approved or not.  Returns the cleaned tag.  Used by htmlScreen
#
#	Parameters
#		$close - either '/' or '' (nothing).  Determines if the tag is the
#			opening or closing tag.
#		$tag - the name of the tag (ie "font")
#		$attr - the attributes of the tag (ie "size=1 color=red")
#		$APPROVED - a hash of approved tags, where the keys are the names
#			of the tags and the values are a comma delimited string of
#			allowed attributes.  ie:
#			{ "font" => "size,color" }
#
#	Returns
#		The tag with any unapproved attributes removed.  If the tag itself
#		is not approved, "" (nothing) will be returned.
#
sub tagApprove {
	my ($close, $tag, $attr, $APPROVED) = @_;

	$tag = uc($tag) if (exists $$APPROVED{uc($tag)});
	$tag = lc($tag) if (exists $$APPROVED{lc($tag)});

	if (exists $$APPROVED{$tag}) {
		my @aprattr = split ",", $$APPROVED{$tag};
		my $cleanattr;
		foreach (@aprattr) {
			if (($attr =~ /\b$_\b\='(\w+?)'/) or
					($attr =~ /\b$_\b\="(\w+?)"/) or
					($attr =~ /\b$_\b\="?'?(\w*)\b/)) {
				$cleanattr.=" ".$_.'="'.$1.'"';
			}
		}
		"<".$close.$tag.$cleanattr.">";
	} else { ""; }
}




#############################################################################
#	Sub
#		htmlScreen
#
#	Purpose
#		screen out html tags from a chunk of text
#		returns the text, sans any tags that aren't "APPROVED"		
#
#	Params
#		text -- the text/html to filter
#		APPROVED -- ref to hash where approved tags are keys.  Null means
#			all HTML will be taken out.
#
#	Returns
#		The text stripped of any HTML tags that are not approved.
#
sub htmlScreen
{
	my ($text, $APPROVED) = @_;
	$APPROVED ||= {};

	if ($text =~ /\<[^>]+$/) { $text .= ">"; } 
	#this is required in case someone doesn't close a tag
	$text =~ s/\<\s*(\/?)(\w+)(.*?)\>/tagApprove($1,$2,$3, $APPROVED)/gse;
	$text;
}



#############################################################################
#	Sub
#		encodeHTML
#
#	Purpose
#		Convert the HTML markup characters (>, <, ", etc...) into encoded
#		characters (&gt;, &lt;, &quot;, etc...).  This causes the HTML to be
#		displayed as raw text in the browser.  This is useful for debugging
#		and displaying the HTML.
#
#	Parameters
#		$html - the HTML text that needs to be encoded.
#		$adv - Advanced encoding.  Pass 1 if some non-HTML, but Everything
#			specific characters should be encoded.
#
#	Returns
#		The encoded string
#
sub encodeHTML
{
	my ($html, $adv) = @_;

	# Note that '&amp;' must be done first.  Otherwise, it would convert
	# the '&' of the other encodings.
	$html =~ s/\&/\&amp\;/g;
	$html =~ s/\</\&lt\;/g;
	$html =~ s/\>/\&gt\;/g;
	$html =~ s/\"/\&quot\;/g;

	if($adv)
	{
		$html =~ s/\[/\&\#91\;/g;
		$html =~ s/\]/\&\#93\;/g;
	}

	return $html;
}


#############################################################################
#	Sub
#		decodeHTML
#
#	Purpose
#		This takes a string that contains encoded HTML (&gt;, &lt;, etc..)
#		and decodes them into their respective ascii characters (>, <, etc).
#
#		Also see encodeHTML().
#
#	Parameters
#		$html - the string that contains the encoded HTML
#		$adv - Advanced decoding.  Pass 1 if you would also like to decode
#			non-HTML, Everything-specific characters.
#
#	Returns
#		The decoded HTML
#
sub decodeHTML
{
	my ($html, $adv) = @_;

	$html =~ s/\&lt\;/\</g;
	$html =~ s/\&gt\;/\>/g;
	$html =~ s/\&quot\;/\"/g;

	if($adv)
	{
		$html =~ s/\&\#91\;/\[/g;
		$html =~ s/\&\#93\;/\]/g;
	}

	$html =~ s/\&amp\;/\&/g;
	return $html;
}


#############################################################################
#	Sub
#		htmlFormatErr
#
#	Purpose
#		An error has occured and we need to print or log it.  This will
#		do the appropriate action based on who the user is.
#
#	Parameters
#		$err - the error message returned from the system
#		$CONTEXT - the node in which this code is coming from.
#			This is optional, however you should try to pass this in all
#			cases since it will help a lot when trying to find which node
#			contains the offending code.
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlFormatErr
{
	my ($err, $CONTEXT) = @_;
	my $str;

	if($USER->isGod())
	{
		$str = htmlErrorGods($err, $CONTEXT);
	}
	else
	{
		$str = htmlErrorUsers($err, $CONTEXT);
	}

	$str;
}


#############################################################################
#	Sub
#		htmlErrorUsers
#
#	Purpose
#		Format an error for the general user.  In this case we do not
#		want them to see the error or the perl code.  So we will log
#		the error and give them a simple one.
#
#		You can define a custom error text by creating an htmlcode
#		node that formats a string error.  The code is passed a single
#		numeric value that can be used to reference the error that is
#		written to the log file.  However, be very careful that your
#		htmlcode for your custom message doesn't have an error, or
#		you may cause a user to get stuck in an infinite loop.  Since,
#		an error in that code would cause the system to call itself
#		to handle the error.
#
#	Parameters
#		$err - the error message returned from the system
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlErrorUsers
{
	my ($errors, $CONTEXT) = @_;
	my $errorId = int(rand(9999999));  # just generate a random error id.
	my $str = htmlcode("htmlError", $errorId);

	# If the site does not have a piece of htmlcode to format this error
	# for the users, we will provide a default.
	if((not defined $str) || $str eq "")
	{
		$str = "Server Error (Error Id $errorId)!";
		$str = "<font color=\"#CC0000\"><b>$str</b></font>";
		
		$str .= "<p>An error has occured.  Please contact the site";
		$str .= " administrator with the Error Id.  Thank you.";
	}

	# Print the error to the log instead of the browser.  That way users
	# don't see all the messy perl code.
	my $error = "Server Error (#" . $errorId . ")\n";
	$error .= "User: ";
	$error .= "$$USER{title}\n" if(ref $USER);
	$error .= "User agent: " . $query->user_agent() . "\n" if defined $query;

	$error .= "Node: $$CONTEXT{title} ($$CONTEXT{node_id})\n"
		if(defined $CONTEXT);

	foreach my $err (@$errors)
	{
		$error .= "--- Start Error --------\n";
		$error .= "Code:\n$$err{code}\n";
		$error .= "Error:\n$$err{error}\n";
		$error .= "Warning:\n$$err{warning}\n";

		if(defined $$err{context})
		{
			my $N = $$err{context};
			$error .= "From node: $$N{title} ($$N{node_id})\n";
		}
	}

	$error .= "-=-=- End Error -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
	Everything::printLog($error);

	$str;
}


#############################################################################
#	Sub
#		htmlErrorGods
#
#	Purpose
#		Print an error for a god user.  This will dump the code, the call
#		stack and any other error information.  You probably don't want
#		the average user of a site to see this stuff.
#
#	Parameters
#		$code - the code snipit that is causing the error
#		$err - the error message returned from the system
#		$warn - the warning message returned from the system
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlErrorGods
{
	my ($errors, $CONTEXT) = @_;
	my $str;

	foreach my $err (@$errors)
	{
		my $error = $$err{error} . $$err{warning};
		my $linenum;
		my $code = $$err{code};

		$code = encodeHTML($code);

		my @mycode = split /\n/, $code;
		while($error =~ /line (\d+)/sg)
		{
			# If the error line is within the range of the offending code
			# snipit, make it red.  The line number may actually be from
			# a perl module that the evaled code is calling.  If thats the
			# case, we don't want some bogus number to add lines.
			if($1 < (scalar @mycode))
			{
				# This highlights the offending line in red.
				$mycode[$1-1] = "<FONT color=cc0000><b>" . $mycode[$1-1] .
					"</b></font>";
			}
		}

		$str .= "<b>$error</b><br>\n";

		my $count = 1;
		$str .= "<PRE>";
		foreach my $line (@mycode)
		{
			$str .= sprintf("%4d: $line\n", $count++);
		}

		# Print the callstack to the browser too, so we can see where this
		# is coming from.
		$str .= "\n\n<b>Call Stack</b>:\n";
		my @callStack = getCallStack();
		while(my $func = pop @callStack)
		{
			$str .= "$func\n";
		}
		$str .= "<b>End Call Stack</b>\n";
		$str.= "</PRE>";
	}
	return $str;
}


#############################################################################
sub jsWindow
{
	my($name,$url,$width,$height)=@_;
	"window.open('$url','$name','width=$width,height=$height,scrollbars=yes')";
}


#############################################################################
sub urlGen {
	my ($REF, $noquotes) = @_;

	my $str;
	$str .= '"' unless $noquotes;
	$str .= "$ENV{SCRIPT_NAME}?";

	$str .= join('&', map { $query->escape($_) .'='. $query->escape($$REF{$_}) }
				 keys %$REF);
	$str .= '"' unless $noquotes;
	return $str;
}


#############################################################################
#   Sub
#       getCode
#
#   Purpose
#       This gets the node of the appropriate htmlcode function
#
#   Parameters
#       funcname - The name of the function to rerieve
#       args - optional arguments to the function.
#           arguments must be in a comma delimited list, as with
#           embedded htmlcode calls
#
#	Returns
#		A string containing the code to execute or a blank string.
sub getCode
{
	my ($funcname, $args) = @_;
	my $user = $USER;
	my $CODE = getNode($funcname, getType("htmlcode"));
	
	# If no user has been loaded yet, we default to the "super user".
	# This sounds scary, but the only time where $USER is not defined
	# is before we log the user in.  Only basic setup code gets run
	# before the user gets logged in.
	$user ||= -1;
	
	# If the user is not allowed to execute this code, we don't want to
	# show anything.
	return '"";' unless ((defined $CODE) && ($CODE->hasAccess($user, "x")));

	my $str;
	$str = "\@\_ = split (/\\s\*,\\s\*/, '$args');\n" if defined $args;
	$str .= $$CODE{code};

	return $str;
}


#############################################################################
#	Sub
#		getPages
#
#	Purpose
#		This gets the edit and display pages for the given node.  Since
#		nodetypes can be inherited, we need to find the display/edit pages.
#
#		If the given node is a nodetype, it will get the display pages for
#		that particular nodetype rather than the main 'nodetype'.
#		Difference is subtle between this function and getPage().  If you
#		pass a nodetype to getPage() it will return the htmlpages to display
#		it, while this will return the htmlpages needed to display nodes
#		of the type passed in.
#
#		For example, lets say you pass the nodetype 'document' to both
#		this and getPage().  This would return 'document display page'
#		and 'document edit page', while getPage would return 'nodetype
#		dipslay page' and 'nodetype edit page'.
#
#		Basically, the purpose for this function is for nodetype display
#		page to show what display pages there are for a type, but that
#		should be reworked to do a different query (htmlpages by type)
#		and this function should be removed.  DPB 18-Apr-00.
#
#	Parameters
#		$NODE - the nodetype in which to get the display/edit pages for.
#
#	Returns
#		An array containing the display/edit pages for this nodetype.
#
sub getPages
{
	my ($NODE) = @_;
	getRef $NODE;
	my $TYPE;
	my @pages;

	$TYPE = $NODE if ($NODE->isNodetype() && $$NODE{extends_nodetype});
	$TYPE ||= getType($$NODE{type_nodetype});

	push @pages, getPageForType($TYPE, "display");
	push @pages, getPageForType($TYPE, "edit");

	return @pages;
}


#############################################################################
#	Sub
#		getPageForType
#
#	Purpose
#		Given a nodetype, get the htmlpages needed to display nodes of this
#		type.  This runs up the nodetype inheritance hierarchy until it
#		finds something.
#
#	Parameters
#		$TYPE - the nodetype hash to get display pages for.
#		$displaytype - the type of display (usually 'display' or 'edit')
#
#	Returns
#		A node hashref to the page that can display nodes of this nodetype.
#
sub getPageForType
{
	my ($TYPE, $displaytype) = @_; 
	my %WHEREHASH;
	my $PAGE;
	my $PAGETYPE;
	
	$PAGETYPE = getType("htmlpage");
	$PAGETYPE or die "HTML PAGES NOT LOADED!";

	# Starting with the nodetype of the given node, We run up the
	# nodetype inheritance hierarchy looking for some nodetype that
	# does have a display page.
	do
	{
		# Clear the hash for a new search
		undef %WHEREHASH;
		
		%WHEREHASH = (pagetype_nodetype => $$TYPE{node_id}, 
				displaytype => $displaytype);

		$PAGE = getNode(\%WHEREHASH, $PAGETYPE);

		if(not defined $PAGE)
		{
			if($$TYPE{extends_nodetype})
			{
				$TYPE = getType($$TYPE{extends_nodetype});
			}
			else
			{
				# No pages for the specified nodetype were found.
				# Use the default node display.
				$PAGE = getNode(
						{ pagetype_nodetype => getId(getType("node")),
						displaytype => $displaytype }, 
						$PAGETYPE);

				$PAGE or die "No default pages loaded.  " .  
					"Failed on page request for $WHEREHASH{pagetype_nodetype}" .
					" $WHEREHASH{displaytype}\n";
			}
		}
	} until($PAGE);

	return $PAGE;
}


#############################################################################
#	Sub
#		getPage
#
#	Purpose
#		This gets the htmlpage of the specified display type for this
#		node.  An htmlpage is basically a database form that knows
#		how to display the information for a particular nodetype.
#
#	Parameters
#		$NODE - a node hash of the node that we want to get the htmlpage for
#		$displaytype - the type of display of the htmlpage (usually
#			'display' or 'edit')
#
#	Returns
#		The node hash of the htmlpage for this node.  If none can be
#		found it uses the basic node display page.
#
sub getPage
{
	my ($NODE, $displaytype) = @_; 
	my $TYPE;
	
	getRef $NODE;
	$TYPE = getType($$NODE{type_nodetype});
	$displaytype ||= $$VARS{'displaypref_'.$$TYPE{title}}
	  if exists $$VARS{'displaypref_'.$$TYPE{title}};
	$displaytype ||= $$THEME{'displaypref_'.$$TYPE{title}}
	  if exists $$THEME{'displaypref_'.$$TYPE{title}};
	$displaytype ||= 'display';


	my $PAGE = getPageForType $TYPE, $displaytype;
	$PAGE ||= getPageForType $TYPE, 'display';

	die "can't load a page $displaytype for $$TYPE{title} type" unless $PAGE;

	return $PAGE;
}


#############################################################################
#	Sub
#		linkNode
#
#	Purpose
#		This creates a <a href> link to the specified node.
#
#	Parameters
#		$NODE - the node to create a link to
#		$title - the title of the link (<a href="...">title</a>)
#		$PARAMS - a hashref that contains any CGI parameters to add
#			to the URL.  (ie { 'op' => 'logout' })
#		$SCRIPTS - a hashref of stuff that goes on the <a> tag itself.
#			This can be other parameters for the <a> tag or javascript
#			like stuff.
#			ie { 'onMouseOver' => 'showStatus("hey!")' }
#
#	Returns
#		An '<a href="...">title</a>' HTML link to the given node.
#
sub linkNode
{
	my ($NODE, $title, $PARAMS, $SCRIPTS) = @_;
    my $link;
	
	return "" unless $NODE;

	# We do this instead of calling getRef, because we only need the node
	# table data to create the link.
	$NODE = getNode($NODE, 'light') unless (ref $NODE);

	return "" unless ref $NODE;	
	
	$title ||= $$NODE{title};
	$$PARAMS{node_id} = getId $NODE;
	my $tags = "";

	$$PARAMS{lastnode_id} = getId ($GNODE) unless exists $$PARAMS{lastnode_id};

	# any params that have a "-" preceding 
	# get added to the anchor tag rather than the URL
	foreach my $key (keys %$PARAMS)
	{
		next unless ($key =~ /^-/); 
		my $pr = substr $key, 1;
		$tags .= " $pr=\"$$PARAMS{$key}\""; 
		delete $$PARAMS{$key};
	}

	my @scripts;
	foreach my $key (keys %$SCRIPTS)
	{
		push @scripts, $key . "=" . $$SCRIPTS{$key}
	}

	my $scripts = "";
	$scripts = join ' ', @scripts if(@scripts);
	
	$link = "<A HREF=" . urlGen ($PARAMS) . $tags;
	$link .= " " . $scripts if($scripts ne "");
	$link .= ">$title</a>";

	return $link;
}


#############################################################################
#	Sub
#		linkNodeTitle
#
#	Purpose
#		Given a node title, create an HTML link to that node.
#
#	Notes
#		This creates a link pointing a node with a specific title.  If
#		there exists more than one node in the system, the result of
#		following the link will result in a "duplicates found".  If you
#		know the exact node you want to go to, you should use linkNode()
#		instead.
#
#	Parameters
#		$nodename - the name of the node to go to.
#		$lastnode - id of the node that you are currently on (used for
#			building links)
#		$title - the title of the link as seen from the browser.
#
sub linkNodeTitle
{
	my ($nodename, $lastnode, $title) = @_;

	($nodename, $title) = split /\|/, $nodename;
	$title ||= $nodename;
	$nodename =~ s/\s+/ /gs;
	
	my $urlnode = $query->escape($nodename);
	my $str = "";
	$str .= "<a href=\"$ENV{SCRIPT_NAME}?node=$urlnode";
	if ($lastnode) { $str .= "&lastnode_id=" . getId($lastnode);}
	$str .= "\">$title</a>";

	return $str;
}


#############################################################################
#	Sub
#		searchForNodeByName
#
#	Purpose
#		This looks for a node by the given name.  If it finds something,
#		it displays the node.
#
#	Parameters
#		$node - the string name of the node we are looking for.
#		$user_id - the user trying to view this node (for authorization)
#
#	Returns
#		nothing
#
sub searchForNodeByName
{
	my ($node, $user_id) = @_;

	my @types = $query->param("type");
	foreach(@types)
	{
		$_ = getId(getType($_));
	}
	
	my %selecthash = (title => $node);
	my @selecttypes = @types;
	$selecthash{type_nodetype} = \@selecttypes if @selecttypes;
	my $select_group = selectNodeWhere(\%selecthash);
	my $search_group;
	my $NODE;

	my $type = $types[0];
	$type ||= "";

	if (not $select_group or @$select_group == 0)
	{ 
		# We did not find an exact match, so do a search thats a little
		# more fuzzy.
		$search_group = searchNodeName($node, \@types); 
		
		if($search_group && @$search_group > 0)
		{
			$NODE = getNode($HTMLVARS{searchResults_node});
			$$NODE{group} = $search_group;
		}
		else
		{
			$NODE = getNode($HTMLVARS{notFound_node});	
		}

		gotoNode ($NODE, $user_id);
	}
	elsif (@$select_group == 1)
	{
		# We found one exact match, goto it.
		my $node_id = $$select_group[0];
		gotoNode ($node_id, $user_id);
		return;
	}
	else
	{
		#we found multiple nodes with that name.  ick
		my $NODE = getNode($HTMLVARS{duplicatesFound_node});
		
		$$NODE{group} = $select_group;
		gotoNode($NODE, $user_id);
	}
}


#############################################################################
#	Sub
#		evalCode
#
#	Purpose
#		This is a wrapper for the standard eval.  This way we can trap eval
#		errors and warnings and do something appropriate with them.
#
#		The scope of variables are:
#			$NODE is the node we are trying to display (the main node)
#			$CURRENTNODE is the node in which this code is embedded.  Like
#				a nodelet for example.
#
#		This differentiates the main node from where this code is coming
#		from, which allows the code to work on the two different items.
#
#	Parameters
#		$code - the code to be evaled
#		$CURRENTNODE - the context in which this code is being evaled.  For
#			example, if this code is coming from a nodelet, CURRENTNODE
#			would be the nodelet.
#
#	Returns
#		The result of the evaled code.  If there were any errors, the
#		return string will be the error nicely HTML formatted for easy
#		display.
#
sub evalCode
{
	my ($code, $CURRENTNODE) = @_;
	#these are the vars that will be in context for the evals

	# Make sure that $NODE is the node we are displaying.
	my $NODE = $GNODE;
	my $warnbuf = "";

	$CURRENTNODE ||= $NODE;

	# if there are any logged errors when we get here, they have nothing
	# to do with this.  So, push them to the backside error log for them to
	# get displayed later.
	flushErrorsToBackside();

	my $str = evalX($code, { '$NODE' => $NODE,
		'$CURRENTNODE' => $CURRENTNODE }, $CURRENTNODE);

	my $errors = getFrontsideErrors();

	if (int(@$errors) > 0)
	{
		$str .= htmlFormatErr($errors, $CURRENTNODE);
	}

	clearFrontside();
		
	return $str;
}


#########################################################################
#	Sub
#		evalX
#
#	Purpose
#		This function is a wrapper for the normal eval so that we can
#		trap errors and log them.  This is intended to be called only
#		from within this package (HTML.pm) as all the globals to this
#		package will be accessable to any code that gets evaled.
#
#		However, this does not mean that it can't be called from other
#		packages.  Just be aware that HTML.pm globals will be in scope.
#
#		Note all variables in scope when the eval() is called should be
#		namespaced with $EVALX_ -- avoiding  "accidents" involving
#		the same variable names in the evalled code.
#
#	Parameters
#		$EVALX_CODE - the string of code that is to be evaled.
#		$EVALX_SCOPE - a hashref that contains variables that should be
#			in scope when the code is evaled.  ie { '$NODE' => $NODE, etc }.
#			The keys are the names of the variable (and must include the
#			$, @, % at the beginning) and the values are what they need to
#			be assigned to.
#		$NODE - optional, however useful.  This way we know where the
#			code is coming from.
#
sub evalX
{
	my ($EVALX_CODE, $EVALX_SCOPE, $NODE) = @_;
	my $EVALX_STR = "";
	my $EVALX_WARN;

	if(defined $EVALX_SCOPE)
	{
		foreach my $var (keys %$EVALX_SCOPE)
		{
			$EVALX_STR .= "my $var = \$\$EVALX_SCOPE{'$var'};\n";
		}
	}

	$EVALX_STR .= $EVALX_CODE;
	
	local $SIG{__WARN__} = sub {
		$EVALX_WARN .= $_[0]
		 unless $_[0] =~ /^Use of uninitialized value/;
	};
	
	# If the code was ever edited on Windows, the newlines are carriage
	# return, line feed combos.  We only want \n.  We are removing the \r
	# (line feed) here.  This should probably be done on the database
	# insert/update routines so that this Windows crap never even gets
	# into the database.
	$EVALX_STR =~ s/\015//gs;

	# If we define any subroutines in our code, this will prevent
    # us from getting the "subroutine * redefined" warning.
	local $^W = 0;
		
	my $result = eval($EVALX_STR);

	local $SIG{__WARN__} = sub { };

	# Log any errors that we get so that we may display them later.
	logErrors($EVALX_WARN, $@, $EVALX_CODE, $NODE);

	return $result;
}


#########################################################################
#	Sub
#		htmlcode
#
#	Purpose
#		allow for easy use of htmlcode functions in embedded perl
#		[{textfield:title,80}] would become:
#		htmlcode('textfield', 'title,80');
#
#	Parameters
#		func -- the function name
#		args -- the arguments in a comma delimited list
#
#	Returns
#		The result from the evaled code
#
sub htmlcode
{
	my ($func, $args) = @_;
	my $CODE = getNode($func, 'htmlcode');
	my $code = getCode($func, $args);
	evalCode($code, $CODE) if($code);
}


#############################################################################
#	Sub
#		embedCode
#
#	Purpose
#		This takes code in the form of [%...%], [{...}], [<...>], or
#		["..."] and evals the internal code.
#
#	Parameters
#		$block - The block of code to eval.  It must be of one of the forms
#			described above.
#		$CURRENTNODE - the node in which this code is coming from.  Some
#			code may need to know this (nodelets that modify themselves).
#			If not defined, this will default to the main node we are
#			trying to display
#
#	Returns
#		The eval-ed result of the code.
#
sub embedCode
{
	my ($block, $CURRENTNODE) = @_;

	my $NODE = $GNODE;
	
	if ($block =~ /^".*"$/)
	{
		# This is used to eval data that a user may have entered.  It is
		# wrapped in quotes so that variables are evaled, but if they
		# contain code, that code is not evaled.  This prevents users from
		# hacking the system by having node titles like:
		# 	$DB->do("drop table nodes")
		$block = evalCode ($block . ';', $CURRENTNODE);	
	}
	elsif ($block =~ /^\{(.*)\}$/s)
	{
		# This is htmlcode.  We need to get the htmlcode node and
		# create a [%...%] block out of its code and pass it back to
		# this function.
		
		my ($func, $args) = split /\s*:\s*/, $1;
		$args ||= "";

		# This line puts the args in the default array
		my $pre_code = "\@\_ = split (/\\s*,\\s*/, \"$args\");\n";
		
		$block = embedCode ('%'. $pre_code . getCode ($func) . '%', 
			$CURRENTNODE);
	}
	elsif ($block =~ /^\%(.*)\%$/s)
	{
		$block = evalCode ($1, $CURRENTNODE);	
	}
	elsif ($block =~ /^<(.*)>$/s)
	{
		my $snippet = getNode($1, "htmlsnippet");

		# User must have execute permissions for this to be embedded.
		if((defined $snippet) && $snippet->hasAccess($USER, "x"))
		{
			$block = parseCode('code', $snippet);
		}
		else
		{
			$block = "";
		}	
	}
	
	# Block needs to be defined, otherwise the search/replace regex
	# stuff will break when it gets an undefined return from this.
	$block ||= "";

	return $block;
}


#############################################################################
#	Sub
#		parseCode
#
#	Purpose
#		Given the text from a node that is to be displayed, parse out the
#		code blocks and eval them.
#
#		NOTE!!! This is a full parse and eval.  You do NOT NOT NOT want to
#		call this on text that an untrusted user can modify.  You don't
#		want users creating nodes with [% `rm -rf /*` %] in their code.
#		Calling this on untrusted user text is a security breach.
#
#		
#
#	Parameters
#		$field - the field to be parsed for the code blocks
#		$CURRENTNODE - the node which this text is coming from.  
#
sub parseCode
{
	my ($field, $CURRENTNODE) = @_;

    my $text = $$CURRENTNODE{$field};
	# the embedding styles are:  
	# [% %]s -- full embedded perl
	# [{ }]s -- calls to the code database
	# [< >]s -- embedded HTML
	# [" "]s -- embedded code strings
	# this is important to know when you are writing pages -- you 
	# always want to print user data through [" "] so that they
	# cannot embed arbitrary code...
	$text=~s/
	 \[
	 (
	 \{.*?\}
	 |".*?"
	 |%.*?%
	 |<.*?>
	 )
	 \]
	  /embedCode($1,$CURRENTNODE)/egsx;

	$text;
}

###################################################################
#	Sub
#		listCode
#
#	Purpose
#		To list code so that it will not be parsed by Everything or the browser
#
#	Parameters
#		$code -- the block of code to display
#		$numbering -- set to true if linenumbers are desired
#
sub listCode
{
	my ($code, $numbering) = @_;
	return unless($code); 

	$code = encodeHTML($code, 1);

	my @lines = split /\n/, $code;
	my $count = 1;

	if($numbering)
	{
		foreach my $ln (@lines) {
			$ln = sprintf("%4d: %s", $count++, $ln);
		}
	}

	my $text = "<PRE>" . join ("\n", @lines) . "</PRE>";
	my $TYPE = getType("htmlsnippet");
	$text =~ s/(&#91;\&lt;)(.*?)(\&gt;&#93;)/$1 . linkCode($2, $TYPE) . $3/egs;

	$TYPE = getType("htmlcode");
	$text =~ s/(&#91;\{)(.*?)(\}&#93;)/$1 . linkCode($2, $TYPE) . $3/egs;

	return $text;
}


#############################################################################
#	Sub
#		linkCode
#
#	Purpose
#		Used in listCode() to create links to the embedded htmlcode and
#		htmlsnippets.  Just a usability thing.  This function should not
#		be used by anybody else.  This is considered a "private" function.
#
#	Parameters
#		$func - the name of the htmlcode/htmlsnippet.  Basically, this is
#			the string between the delimiting brackets.
#		$NODE - the nodetype of the destination link (optional ?)
#
#	Returns
#		A HTML link to the appropriate node, or the function name.
#
sub linkCode
{
	my ($func, $TYPE) = @_;
	my $name;
	
	# First we need to figger out the name of the htmlsnippet or htmlcode.
	# If this is an htmlcode, it may have parameters.  We need to extract
	# the name.
	($name, undef) = split(/:/, $func, 2);
	
	my $NODE = getNode($name, $TYPE);

	return linkNode($NODE, $func) if($NODE);
	return $func;
}


#############################################################################
#	Sub
#		quote
#
#	Purpose
#		Not sure.  It seems that nothing uses this.  Nate?
#
#	Parameters
#		$text - the text to encode
#
sub quote
{
	my ($text) = @_;

	$text =~ s/([\W])/sprintf("&#%03u", ord $1)/egs;
	$text; 
}


#############################################################################
#	Sub
#		insertNodelet
#
#	Purpose
#		This generates the nodelet by grabbing the nodelet, executing its
#		code, and then wrapping it in all the specified nodelet containers
#		to generate the nodelet.
#
#	Parameters
#		$NODELET - the nodelet to insert
#
sub insertNodelet
{
	# Don't "my" NODELET!  It is a global!
	($NODELET) = @_;
	getRef $NODELET;

	# If the user can't "execute" this nodelet, we don't let them see it!
	return undef unless($NODELET->hasAccess($USER, "x"));
	
	my $html = genContainer($$NODELET{parent_container}) 
		if $$NODELET{parent_container};

	# Make sure the nltext is up to date
	updateNodelet($NODELET);
	return unless ($$NODELET{nltext} =~ /\S/);
	
	# now that we are guaranteed that nltext is up to date, sub it in.
	if ($html) { $html =~ s/CONTAINED_STUFF/$$NODELET{nltext}/s; }
	else { $html = $$NODELET{nltext}; }
	return $html;
}


#############################################################################
#	Sub
#		updateNodelet
#
#	Purpose
#		Nodelets store their code in the nlcode (nodelet code) field.
#		This code is not eval-ed every time the nodelet is displayed.
#		Call this function every time you display a nodelet.  This
#		will eval the code if the specified interval has passed.
#
#		The updateinterval field dictates how often we eval the nlcode.
#		If it is -1, we eval the code the first time and never do it
#		again.
#
#	Parameters
#		$NODELET - the nodelet to update
#
sub updateNodelet
{
	my ($NODELET) = @_;
	my $interval;
	my $lastupdate;
	my $currTime = time; 

	$interval = $$NODELET{updateinterval};
	$lastupdate = $$NODELET{lastupdate};
	
	# Return if we have generated it, and never want to update again (-1) 
	return if($interval == -1 && $lastupdate != 0);
	
	# If we are beyond the update interval, or this thing has never
	# been generated before, generate it.
	if((not $currTime or not $interval) or
		($currTime > $lastupdate + $interval) || ($lastupdate == 0))
	{
		$$NODELET{nltext} = parseCode('nlcode', $NODELET);
		$$NODELET{lastupdate} = $currTime; 

		$NODELET->update(-1) unless $interval == 0;
		#if interval is zero then it should only be updated in cache
	}
	
	""; # don't return anything
}


#############################################################################
sub genContainer
{
	my ($CONTAINER) = @_;
	getRef $CONTAINER;
	my $replacetext;
	my $containers;

	$replacetext = parseCode ('context', $CONTAINER);
	$containers = $query->param('containers') || '';

	# SECURITY!  Right now, only gods can see the containers.  When we get
	# a full featured security model in place, this will change...
	if($USER->isGod() && ($containers eq "show"))
	{
		my $start = "";
		my $middle = $replacetext;
		my $end = "";
		my $debugcontainer = getNode('show container', 'container');
		
		# If this container contains the body tag, we do not want to wrap
		# the entire thing in the debugcontainer.  Rather, we want to wrap
		# the contents inside the body tag.  If we don't do this, we end up
		# wrapping the <head> and <body> in a table, which makes the page
		# not display right.
		if($replacetext =~ /<body/i)
		{
			$replacetext =~ /(.*<body.*>)(.*)(<\/body>.*)/i;
			$start = $1;
			$middle = $2;
			$end = $3;
		}

		if($debugcontainer)
		{
			my $debugtext = parseCode('context', $debugcontainer);
			$debugtext =~ s/CONTAINED_STUFF/$middle/s;
			$replacetext = $start . $debugtext . $end;
		}
	}
	
	if ($$CONTAINER{parent_container}) {
		my $parenttext = genContainer($$CONTAINER{parent_container});	
		$parenttext =~ s/CONTAINED_STUFF/$replacetext/s;
		$replacetext = $parenttext;
	} 
	
	return $replacetext;	
}


############################################################################
#	Sub	containHtml
#
#	Purpose
#		Wrap a given block of HTML in a container specified by title
#		hopefully this makes containers easier to use
#
#	Parameters
#		$container - title of container
#		$html - html to insert
#
#	Returns
#		The HTML of the container with $html inside.
#
sub containHtml
{
	my ($container, $html) =@_;
	my ($TAINER) = getNode($container, getType("container"));
	my $str = genContainer($TAINER);

	$str =~ s/CONTAINED_STUFF/$html/g;
	return $str;
}


#############################################################################
#	Sub
#		displayPage
#
#	Purpose
#		This is the meat of displaying a node to the user.  This gets
#		the display page for the node, inserts it into the appropriate
#		container, prints the HTML header and then prints the page to
#		the users browser.
#
#	Parameters
#		$NODE - the node to display
#		$user_id - the user that is trying to 
#
#	Returns
#		Nothing of use.
#
sub displayPage
{
	my ($NODE, $user_id) = @_;
	die "NO NODE!" unless $NODE;
	
	my $displaytype = $query->param('displaytype');
	$displaytype ||= 'display';
	
	# If this node we are trying to display is a symlink, we may need
	# to go to a different node.
	if($NODE->isOfType("symlink") && $displaytype ne "edit")
	{
		$$VARS{followSymlinks} ||= "";
		if($$VARS{followSymlinks} ne "no")
		{
			$NODE = getNode($$NODE{symlink_node});

			# Then go to the node to make sure all relevant code for
			# hitting a node gets executed.
			gotoNode($NODE);
			return;
		}
	}
	
	$GNODE = $NODE;
	
	my $PAGE = getPage($NODE, $query->param('displaytype')); 

	die "NO PAGE!" unless $PAGE;

	# If the user does not have the needed permission to view this
	# node through the desired htmlpage, we send them to the permission
	# denied node.
	unless($NODE->hasAccess($USER, $$PAGE{permissionneeded}))
	{
		# Make sure the display type is set to display.  Otherwise we
		# may get stuck in an infinite loop of permission denied.
		$query->param("displaytype", "display");

		gotoNode($HTMLVARS{permissionDenied_node});
		return;
	}

	if ($$PAGE{permissionneeded} eq "w")
	{
		# If this is an "edit" page.  We need to lock the node while
		# this user is editing.
		if (not $NODE->lock($USER))
		{
			# Someone else already has a lock on this node, go to the
			# "node locked" node.
			$query->param('displaytype', 'display');
			gotoNode($HTMLVARS{nodeLocked_node});
		}
	}

	my $page = parseCode('page', $PAGE);

	if ($$PAGE{parent_container}) {
		my $container = genContainer($$PAGE{parent_container}); 
		$container =~ s/CONTAINED_STUFF/$page/s;
		$page = $container;
	}	

	# Lastly, we need to insert backside errors into the page once everything
	# has had its chance to run.  The <BacksideError> tag is inserted by
	# the backsideErrors htmlsnippet.  That node should have permissions set
	# such that it is only executable by gods (or whoever should see the
	# errors).
	if($USER->isGod())
	{
		my $errors = formatGodsBacksideErrors();
		$page =~ s/<BacksideErrors>/$errors/;
	}
	else
	{
		printBacksideToLogFile();
	}
	
	# Print the appropriate MIME type header so that browser knows what
	# kind of data is coming down the pipe.
	printHeader($$NODE{datatype});
	
	# We are done.  Print the page (or data) to the browser.
	$query->print($page);
}


#############################################################################
#	Sub
#		formatGodsBacksideErrors
#
#	Purpose
#		This formats any errors that we may have in our "cache" so that
#		gods can see them and correct them if necessary.
#
#	Parameters
#		None.
#
#	Returns
#		A nicely formatted HTML table suitable for display somewhere, or a
#		blank string if there aren't any errors.
#
sub formatGodsBacksideErrors
{
	Everything::flushErrorsToBackside();

	my $errors = Everything::getBacksideErrors();

	return "" unless(@$errors > 0);

	my $str = "<table border=1>\n";
	$str .= "<tr><td bgcolor='black'><font color='red'>Backside Errors!" .
		"</font></td></tr>\n";

	foreach my $error (@$errors)
	{
		$str .= "<tr><td bgcolor='yellow'>";
		$str .= "<font color='black'>Warning: $$error{warning}</font>";
		$str .= "</td></tr>\n";
		
		$str .= "<tr><td bgcolor='#ff3333'>";
		$str .= "<font color='black'>Error: $$error{error}</font></td></tr>\n";
		$str .= "<tr><td>From: " . linkNode($$error{context}) . "</td></tr>\n"
				if($$error{context});
		$str .= "<tr><td><pre>$$error{code}</pre></td></tr>\n";
	}

	$str .= "</table>\n";

	return $str;
}


#############################################################################
#	Sub
#		printBacksideToLogFile
#
#	Purpose
#		This formats any errors that we may have in our "cache" so that
#		they'll appear nicely in the log.  Normal users can't see them.
#
#	Parameters
#		None.
#
#	Returns
#		Nothing of value.
#
sub printBacksideToLogFile
{
	Everything::flushErrorsToBackside();

	my $errors = Everything::getBacksideErrors();
	my $str;

	return "" unless(@$errors > 0);

	$str = "\n>>> Backside Errors!\n";
	foreach my $error (@$errors)
	{
		$str .= "-=-=-=-=-=-=-=-=-=-=-=-\n";
		$str .= "Warning:   $$error{warning}\n";
		$str .= "Error:     $$error{error}\n";
		$str .= "From node: $$error{context}{title} ";
		$str .= "$$error{context}{node_id}\n";
		$str .= "Code:\n";
		$str .= "$$error{code}\n";
	}

	$str .= "-=-=-=-=-=-=-=-=-=-=-=-\n";

	Everything::printLog($str);
}


#############################################################################
#	Sub
#		gotoNode
#
#	Purpose
#		Once we know the exact node that we want to go to, we call this
#		function.  
#
#	Parameters
#		$NODE - the node we want to go to.
#
#	Returns
#		Nothing of value.
#
sub gotoNode
{
	my ($NODE) = @_;
	getRef($NODE);

	$NODE = getNode($HTMLVARS{notFound_node}) unless ($NODE);
	
	$NODE->updateHits();
	$NODE->updateLinks($query->param('lastnode_id'));

	displayPage($NODE);
}


#############################################################################
#	Sub
#		confirmUser
#
#	Purpose
#		Given a username and the passwd they entered in encrypted form,
#		verify that the passwd/username combo is correct.
#
#	Parameters
#		$nick - the user name
#		$crpasswd - the passwd that the user entered, encrypted
#
#	Returns
#		The USER node if everything checks out.  undef if the
#		username/passwd combo failed.
#
sub confirmUser
{
	my ($nick, $crpasswd) = @_;
	my $USER = getNode($nick, getType('user'));
	my $genCrypt;

	return undef unless($USER);

	$genCrypt = crypt($$USER{passwd}, $$USER{title});

	if ($genCrypt eq $crpasswd)
	{
		my $rows = $DB->getDatabaseHandle()->do("
			UPDATE user SET lasttime=now() WHERE
			user_id=$$USER{node_id}
			");

		# We force a reload of the node to make sure that the 'lasttime'
		# field (updated by the database), is current.  If there was a
		# way to just get the now() string from the database, we would
		# not need to do this, which would save at least 1 node load
		# per page load.
		# 'SELECT now()' will work... where's it go?
		return getNode($$USER{node_id}, 'force');
	} 

	return undef;
}


#############################################################################
#	Sub
#		parseLinks
#
#	Purpose
#		This finds any [...] blocks in the text and creates a link to
#		the node named in the brackets.
#
#		NOTE - we should add some setting to only allow links to
#		certain types of nodes.  Obviously, if a user puts [node] in
#		their text, you don't want it to link to the "node" nodetype.
#
#	Parameters
#		$text - the text in which to search for [...] links
#		$NODE - The node that contains this link.  Used for "lastnode".
#
#	Returns
#		The text with the [...] replaced with the appropriate links.
#
sub parseLinks
{
	my ($text, $NODE) = @_;

	$text =~ s/\[(.*?)\]/linkNodeTitle ($1, $NODE)/egs;
	return $text;
}


#############################################################################
#	Sub
#		loginUser
#
#	Purpose
#		For each page request, we need to know the user trying to view
#		the page.  This logs in a user if they are logging in and stores
#		the info in a cookie.  If they have already logged in, we use
#		their cookie information.
#
#	Parameters
#		None.  Uses global package vars.
#
#	Returns
#		The USER node hash reference
#
sub loginUser
{
	my ($user_id, $cookie, $user, $passwd);
	my $USER_HASH;
	
	if(my $oldcookie = $query->cookie("userpass"))
	{
		$USER_HASH = confirmUser (split (/\|/,
			Everything::Util::unescape($oldcookie)));
	}

	# If all else fails, use the guest_user
	$user_id ||= $HTMLVARS{guest_user};

	# Get the user node
	$USER_HASH ||= getNode($user_id);	

	die "Unable to get user! ($user_id)" unless ($USER_HASH);

	# Assign the user vars to the global.
	$VARS = $USER_HASH->getVars();
	
	# Store this user's cookie!
	$$USER_HASH{cookie} = $cookie if $cookie; 

	return $USER_HASH;
}


#############################################################################
#	Sub
#		getCGI
#
#	Purpose
#		This gets and sets up the CGI interface for an individual request.
#
#	Parameters
#		None
#
#	Returns
#		The CGI object.
#
sub getCGI
{
	my $cgi;
	
	if ($ENV{SCRIPT_NAME}) { 
		$cgi = new CGI;
	} else {
		$cgi = new CGI(\*STDIN);
	}

	if (not defined ($cgi->param("op"))) {
		$cgi->param("op", "");
	}

	return $cgi;
}

############################################################################
#	Sub
#		getTheme
#
#	Purpose
#		this creates the $THEME variable that various components can
#		reference for detailed settings.  The user's theme is a system-wide
#		default theme if not specified, then a "themesetting" can be 
#		used to override specific values.  Finally, if there are user-specific
#		settings, they are kept in the user's settings
#
#	Parameters
#		this function references global variables, so no params are needed
#
#	Returns
#		Blank string if it succeeds, undef if it fails.
#
sub getTheme
{
	my $theme_id;
	$theme_id = $$VARS{preferred_theme} if(exists $$VARS{preferred_theme});
	$theme_id ||= $HTMLVARS{default_theme};
	my $TS = getNode($theme_id);

	if ($TS->isOfType('themesetting'))
	{
		# We are referencing a theme setting.
		my $BASETHEME = getNode($$TS{parent_theme});
		my $REPLACEMENTVARS;
		my $TEMPTHEME;

		return undef unless($BASETHEME);

		$TEMPTHEME = $BASETHEME->getVars();
		$REPLACEMENTVARS = $TS->getVars();

		# Make a copy of the base theme vars.  We don't want to modify
		# the actual node.
		undef %$THEME;
		@$THEME{keys %$TEMPTHEME} = values %$TEMPTHEME;
		@$THEME{keys %$REPLACEMENTVARS} = values %$REPLACEMENTVARS;
	} 
	elsif($TS->isOfType('theme'))
	{
		# This whatchamacallit is a theme
		$THEME = $TS->getVars();
	}
	else
	{
		die "Node $theme_id is not a theme or themesetting!";
	}
	
	"";
}


#############################################################################
#	Sub
#		printHeader
#
#	Purpose
#		For each page we serve, we need to pass standard HTML header
#		information.  If we are script, we are responsible for doing
#		this (the web server has no idea what kind of information we
#		are passing).
#
#	Parameters
#		$datatype - (optional) the MIME type of the data that we are
#			to display	('image/gif', 'text/html', etc).  If not
#			provided, the header will default to 'text/html'.
#
#	Returns
#		Nothing of value.
sub printHeader
{
	my ($datatype) = @_;

	# default to plain html
	$datatype ||= "text/html";
	
	if($ENV{SCRIPT_NAME})
	{
		if ($$USER{cookie})
		{
			$query->header(-type=> $datatype, 
		 		-cookie=>$$USER{cookie});
		}
		else
		{
			$query->header(-type=> $datatype);
		}
	}
}


#############################################################################
#	Sub
#		handleUserRequest
#
#	Purpose
#		This checks the CGI information to find out what the user is trying
#		to do and execute their request.
#
#	Parameters
#		None.  Uses the global package variables.
#
#	Returns
#		Nothing of value.
#
sub handleUserRequest
{
	my $user_id = $$USER{node_id};
	my $node_id;
	my $nodename;
	my $code;
	my $handled = 0;

	if ($query->param('node'))
	{
		# Searching for a node my string title
		my $type  = $query->param('type');
		my $TYPE = getType($type);
		
		$nodename = cleanNodeName($query->param('node'));
		$query->param("node", $nodename);
		
		searchForNodeByName($nodename, $user_id, $type); 
	}
	else
	{
		$node_id = $query->param('node_id');
		
		if(defined $node_id)
		{
			# searching by ID
			gotoNode($node_id, $user_id);
		}
		else
		{
			# no node was specified -> default
			gotoNode($HTMLVARS{default_node}, $user_id);
		}
	}
}


#############################################################################
#	Sub
#		cleanNodeName
#
#	Purpose
#		We limit names of nodes so that they cannot contain certain
#		characters.  This is so users can't play games with the names
#		of their nodes.  For example, we don't want "hello there" and
#		"hello      there" to be different nodes.
#
#	Parameters
#		$nodename - the raw name that the user has given
#
#	Returns
#		The name after we have cleaned it up a bit
#
sub cleanNodeName
{
	my ($nodename) = @_;

	$nodename =~ tr/[]|<>//d;
	$nodename =~ s/^\s*|\s*$//g;
	$nodename =~ s/\s+/ /g;
	$nodename ="" if $nodename=~/^\W$/;
	#$nodename = substr ($nodename, 0, 80);

	return $nodename;
}


#############################################################################
#	Sub
#		initForPageLoad
#
#	Purpose
#		Each page load requires us to have a fresh start.  Each page load
#		stores info in module variables and caches some stuff.  Since each
#		page load could come from a completely different person, we need to
#		clear this stuff out so they don't get stale/undesirable info.
#
sub initForPageLoad
{
	my ($db) = @_;

	undef %GLOBAL;

	$GNODE = {};
	$USER = {};
	$VARS = {};
	$NODELET = {};
	$THEME = {};

	$query = "";

	# Initialize our connection to the database
	Everything::initEverything($db, 1);

	# Clear the method cache for searching.  Something may have changed.
	# This is similar to the resetCache() below.
	Everything::Node::initMethodCache();
	
	# The cache has a performance enhancement where it will only check
	# versions once.  This clears the version check cache so that we
	# will do fresh version checks each page load.
	$DB->resetNodeCache();
}


#############################################################################
sub opNuke
{
	my $NODE = getNode($query->param("node_id"));
	
	$NODE->nuke($USER) if($NODE);
}


#############################################################################
sub opLogin
{
	my $user = $query->param("user");
	my $passwd = $query->param("passwd");
	my $cookie;

	$USER = confirmUser ($user, crypt ($passwd, $user));
	
	# If the user/passwd was correct, set a cookie on the users
	# browser.
	$cookie = $query->cookie(-name => "userpass", 
		-value => $query->escape($user . '|' . crypt ($passwd, $user)), 
		-expires => $query->param("expires")) if $USER;

	$USER ||= getNode($HTMLVARS{guest_user});
	$VARS = $USER->getVars() if($USER);

	$$USER{cookie} = $cookie if($cookie);
}


#############################################################################
sub opLogout
{
	# The user is logging out.  Nuke their cookie.
	my $cookie = $query->cookie(-name => 'userpass', -value => "");

	$USER = getNode($HTMLVARS{guest_user});
	$VARS = $USER->getVars() if($USER);

	$$USER{cookie} = $cookie if($cookie);
}


#############################################################################
sub opNew
{
	my $node_id = 0;
	my $user_id = $$USER{node_id};
	my $type = $query->param('type');
	my $TYPE = getType($type);
	my $nodename = cleanNodeName($query->param('node'));
	
	# Depending on whether the TYPE allows for duplicate names or not,
	# we need to create them with different create ops.
	my $create;
	$create = "create" if($$TYPE{restrictdupes});
	$create ||= "create force";

	my $NEWNODE = getNode($nodename, $TYPE, $create);
	$NEWNODE->insert($USER);

	$query->param("node_id", $$NEWNODE{node_id});
	$query->param("node", "");
	
	if($NEWNODE->getId() < 1)
	{
		$GLOBAL{permissionDenied} = "You do not have permission to create " .
			"a node of type '$$NEWNODE{type}{title}'.";
		$query->param("node_id", $HTMLVARS{permissionDenied_node});
	}
}


#############################################################################
sub opUnlock
{
	my $LOCKEDNODE = getNode($query->param('node_id'));
	$LOCKEDNODE->unlock($USER);
}


#############################################################################
#	Sub
#		getOpCode
#
#	Purpose
#		Get the 'op' code for the specified operation.
#
#	Parameters
#		$opname - the title of the operation
#
#	Returns
#		A string containing the operation's code, or undef.
#
sub getOpCode
{
	my ($opname) = @_;
	my $OPNODE = getNode($opname, "opcode");
	my $code;
	
	# If a user cannot execute this, don't do it.
	return undef unless($OPNODE && $OPNODE->hasAccess($USER, "x"));

	$code = $$OPNODE{code} if(defined $OPNODE);

	return $code;
}


#############################################################################
#	Sub
#		execOpCode
#
#	Purpose
#		One of the CGI parameters that can be passed to Everything is the
#		'op' parameter.  "Operations" are discrete pieces of work that are
#		to be executed before the page is displayed.  They are useful for
#		providing functionality that can be shared from any node.
#
#		By creating an opcode node you can create new ops or override the
#		defaults.  Just be careful if you override any default operations.
#		For example, if you override the 'login' op with a broken
#		implementation you may not be able to log in.
#
#	Parameters
#		None
#
#	Returns
#		Nothing
#
sub execOpCode
{
	my $op = $query->param('op');
	my $code;
	my $handled = 0;
	
	return 0 unless(defined $op && $op ne "");
	
	$code = getOpCode($op, $USER);

	if(defined $code)
	{
		$handled = evalX($code);
	}

	unless($handled)
	{
		# These are built in defaults.  If no 'opcode' nodes exist for
		# the specified op, we have some default handlers.

		if($op eq 'login')
		{
			opLogin()
		}
		elsif($op eq 'logout')
		{
			opLogout();
		}
		elsif($op eq 'nuke')
		{
			opNuke();
		}
		elsif($op eq 'new')
		{
			opNew();
		}
		elsif($op eq 'unlock')
		{
			opUnlock();
		}
	}
}


#############################################################################
#	Sub
#		setHTMLVARS
#
#	Purpose
#		This gets the 'system settings' node and assigns the settings
#		hash to the global HTMLVARS for our use during this page load.
#
sub setHTMLVARS
{
	# Get the HTML variables for the system.  These include what
	# pages to show when a node is not found (404-ish), when the
	# user is not allowed to view/edit a node, etc.  These are stored
	# in the dbase to make changing these values easy.	
	my $SYSSETTINGS = getNode('system settings', getType('setting'));
	my $SETTINGS;
	if($SYSSETTINGS && ($SETTINGS = $SYSSETTINGS->getVars()))
	{
		%HTMLVARS = %{ $SETTINGS } if(ref $SETTINGS);
	}
	else
	{
		die "Error!  No system settings!";
	}
}


#############################################################################
#	Sub
#		updateNodeData
#
#	Purpose
#		If we have a node_id, we may be getting some params that indicate
#		that we should be updating the node.  This checks for those
#		parameters and updates the node if necessary.
#
#		THIS WILL BE MOVING TO THE "update" OPCODE!
#
sub updateNodeData
{
	my $node_id = $query->param('node_id');

	return undef unless($node_id);
	
	my $NODE = getNode($node_id);
	my $updateflag = 0;

	return 0 unless($NODE);
	
	if ($NODE->hasAccess($USER, 'w'))
	{
		if (my $groupadd = $query->param('add'))
		{
			$NODE->insertIntoGroup($USER, $groupadd,
				$query->param('orderby'));
			$updateflag = 1;
		}
		
		if ($query->param('group'))
		{
			my @newgroup;
			my $counter = 0;

			while (my $item = $query->param($counter++))
			{
				push @newgroup, $item;
			}

			$NODE->replaceGroup(\@newgroup, $USER);
			$updateflag = 1;
		}

		my @updatefields = $query->param;
		my $RESTRICT = getNode('restricted fields', 'setting');
		my $RESTRICTED = $RESTRICT->getVars() if($RESTRICT);

		$RESTRICTED ||= {};
		foreach my $field (@updatefields)
		{
			if ($field =~ /^$$NODE{type}{title}\_(\w*)$/)
			{
				next if exists $$RESTRICTED{$1};	
				$$NODE{$1} = $query->param($field);
				$updateflag = 1;
			}	
		}
		
		if ($updateflag)
		{
			$NODE->update($USER); 

			# This is the case where the user is modifying their own user
			# node.  If we want the user node to take effect in one page
			# load, we need to set it here.
			if ($$USER{node_id} == $$NODE{node_id}) { $USER = $NODE; }
		}
	}
}


#############################################################################
#	Sub
#		mod_perlInit
#
#	Purpose
#		This is the "main" function of Everything.  This gets called for
#		each page load in an Everything system.
#
#	Parameters
#		$db - the string name of the database to get our information from.
#
#	Returns
#		nothing useful
#
sub mod_perlInit
{
	my ($db, $staticNodetypes) = @_;

	initForPageLoad($db);

	setHTMLVARS();

	$query = getCGI();

	$USER = loginUser();

	# Execute any operations that we may have
	execOpCode();

	updateNodeData();
	
	# Fill out the THEME hash
	getTheme();

	# Do the work.
	handleUserRequest();

	# Lastly, set the vars on the user node so that things get saved.
	$USER->setVars($VARS, $USER);
	$USER->update($USER);
}


#############################################################################
# End of package
#############################################################################

1;
