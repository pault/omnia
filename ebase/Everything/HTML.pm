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
		newFormObject
		parseLinks
		htmlScreen
		htmlFormatErr
		quote
		urlGen
		getPage
		getPageForType
		linkNode
		linkNodeTitle
		searchForNodeByName
		evalX
		evalXTrapErrors
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
use vars qw(%INCJS);


####### Deprecated functions #############
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


#############################################################################
#	Sub
#		newFormObject
#
#	Purpose
#		A little wrapper to make getting form object references easier.
#
#	Parameters
#		$objName - the name of a form object (ie 'TextField').  Note!!!
#			This name must be of the same capitalization as the actual
#			.pm implementation of the desired form object.
#
#	Returns
#		The form object ref if successful, undef otherwise.
#
sub newFormObject
{
	my ($objName) = @_;
	my $obj;

	$objName = "Everything::HTML::FormObject::$objName";

	# We eval so that if the requested nodetype doesn't exist, we don't
	# crap a brick.	
	eval("require $objName; \$obj = new $objName()");
	Everything::logErrors($@);

	return $obj;
}


#############################################################################
#	sub
#		tagApprove
#
#	Purpose
#		determines whether or not a tag (and its specified attributes)
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
		return "<".$close.$tag.$cleanattr.">";
	} else { return ""; }
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
#		$err - a list ref of error messages returned from the system
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

	return $str;
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
#		$errors - a list ref of error messages returned from the system
#		$CONTEXT - the node in which this code is coming from.
#			This is optional, however you should try to pass this in all
#			cases since it will help a lot when trying to find which node
#			contains the offending code.
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlErrorUsers
{
	my ($errors, $CONTEXT) = @_;
	my $errorId = int(rand(9999999));  # just generate a random error id.
	my $str; #= htmlError($errorId);

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
#		$errors - a list ref of error messages returned from the system
#		$CONTEXT - the node from which the error came (optional)
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

		$str .= "<p><b>$error</b><br>\n";

		my $count = 1;
		$str .= "<PRE>";
		foreach my $line (@mycode)
		{
			$str .= sprintf("%4d: %s\n", $count++, $line);
		}

		# Print the callstack to the browser too, so we can see where this
		# is coming from.
		if (exists $$VARS{showCallStack} and $$VARS{showCallStack}) {
			$str .= "\n\n<b>Call Stack</b>:\n";
			$str .= join("\n", reverse(getCallStack()));
			$str .= "<b>End Call Stack</b>\n";
		}
		$str.= "</PRE>";
	}
	return $str;
}


#############################################################################
#   Sub
#       urlGen
#
#   Purpose
#       This creates a URL to the current installation
#
#   Parameters
#       $REF - a hashref of parameters and values used to create a query string
#       $noquotes - an optional flag.  If true, it suppreses quotes around the
#       	URL.
#
#	Returns
#		A string containing the generated URL.
#
sub urlGen
{
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

		$PAGE = $DB->getNode(\%WHEREHASH, $PAGETYPE);

		if(not defined $PAGE)
		{
			if($$TYPE{extends_nodetype})
			{
				$TYPE = $DB->getType($$TYPE{extends_nodetype});
			}
			else
			{
				# No pages for the specified nodetype were found.
				# Use the default node display.
				$PAGE = $DB->getNode(
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

	my $PAGE;
	
	# If the displaytype is 'display' and this node has a preferred
	# htmlpage that it specifically wants, we will use that.
	if($displaytype eq 'display' && $$NODE{preferred_htmlpage} && $$NODE{preferred_htmlpage} != -1)
	{
		my $PREFER = $DB->getNode($$NODE{preferred_html});
		$PAGE = $PREFER if($PREFER && $PREFER->isOfType('htmlpage'));
	}
	
	# First, we try to find the htmlpage for the desired display type,
	# if one does not exist, we default to using the display page.
	$PAGE ||= getPageForType $TYPE, $displaytype;
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
	
	return "" unless defined($NODE);

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
			$GLOBAL{searchgroup} = $search_group;
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
		my @canread;
		foreach (@$select_group) {
			my $N = getNode $_;
			next unless $N->hasAccess($USER, 'r');
			push @canread, $_;
		}
		
		return gotoNode($HTMLVARS{not_found}, $user_id) unless @canread;
		return gotoNode($canread[0], $user_id) if @canread == 1;
		
		#we found multiple nodes with that name.  ick
		my $NODE = getNode($HTMLVARS{duplicatesFound_node});
		
		$$NODE{group} = \@canread;
		gotoNode($NODE, $user_id);
	}
}


#############################################################################
#	Sub
#		evalXTrapErrors
#
#	Purpose
#		This is a wrapper for the standard eval.  This way we can trap eval
#		errors and warnings and do something appropriate with them.  The
#		difference between this and evalX is that this function assumes that
#		you want to report all eval errors right now.  If you wish to do
#		multiple evals, then report all the errors, call evalX for each
#		code and grab the errors yourself.
#
#	Parameters
#		$code - the code to be evaled
#		$CURRENTNODE - the context in which this code is being evaled.  For
#			example, if this code is coming from a nodelet, CURRENTNODE
#			would be the nodelet.  This helps if we encounter an error.
#			That way we know which node the code is coming from. If you
#			do not pass $CURRENTNODE, you *must* pass an undef in its place
#		@_ - the remaining items in @_ will be in context for the evaled
#			code.
#
#	Returns
#		The result of the evaled code.  If there were any errors, the
#		return string will be the error nicely HTML formatted for easy
#		display.
#
sub evalXTrapErrors
{
	my ($code, $CURRENTNODE) = @_;

	# if there are any logged errors when we get here, they have nothing
	# to do with this.  So, push them to the backside error log for them to
	# get displayed later.
	flushErrorsToBackside();

	my $str = evalX(@_);

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
#		$CURRENTNODE - the node in which the code is coming from.  If you
#			are unable to pass this (you don't know it or are evaling code
#			that is not associated with a node), you must pass undef in its
#			place as the rest of @_ are the parameters that will be in scope
#			when the actual eval is done.
#
#	Returns
#		Whatever the code returns.
#
sub evalX
{
	my $EVALX_CODE = shift @_;
	my $CURRENTNODE = shift @_;
	my $EVALX_WARN;
	my $NODE = $GNODE;

	$CURRENTNODE ||= $NODE;

	local $SIG{__WARN__} = sub {
		$EVALX_WARN .= $_[0]
		 unless $_[0] =~ /^Use of uninitialized value/;
	};
	
	# If the code was ever edited on Windows, the newlines are carriage
	# return, line feed combos.  We only want \n.  We are removing the \r
	# (line feed) here.  This should probably be done on the database
	# insert/update routines so that this Windows crap never even gets
	# into the database.  Oh well, we will just scrub it clean here...
	$EVALX_CODE =~ s/\015//gs;

	# If we define any subroutines in our code, this will prevent
    # us from getting the "subroutine * redefined" warning.
	local $^W = 0;
		
	my $result = eval($EVALX_CODE);


	# Log any errors that we get so that we may display them later.
	logErrors($EVALX_WARN, $@, $EVALX_CODE, $CURRENTNODE);

	return $result;
}


#############################################################################
#	Sub
#		AUTOLOAD
#
#	Purpose
#		This is to allow htmlcode to be called just like normal functions
#		If an htmlcode of the given name does not exist, this will throw
#		an error.
#
#	Parameters
#		Whatever the htmlcode expects
#
#	Returns
#		Whatever the htmlcode returns
#
sub AUTOLOAD
{
	# @_ contains the parameters for the htmlcode so we don't need to
	# extract them.
	my $subname = $Everything::HTML::AUTOLOAD;

	$subname =~ s/.*:://;

	my $CODE = $DB->getNode($subname, 'htmlcode');
	my $user = $USER;

	$user ||= -1;

	# The reason we "die" here rather than just logging an error and
	# returning is to simulate the fact that the function does not exist.
	# In normal perl, if you try to call a function that does not exist,
	# you get a fatal runtime error.  If this is being called inside
	# another eval, this will cause the eval to get an error which it
	# can then handle.
	die ("No function or htmlcode named '$subname' exists.") unless($CODE);
	
	# We can only execute this if the logged in user has execute permissions.
	return undef unless($CODE->hasAccess($user, 'x'));

	my $result;

	# this htmlcode may have been Compil-O-Cached
	# check if we can execute the cached sub and try to do it
	unless ((exists($HTMLVARS{noCompile}) and $HTMLVARS{noCompile}) or
		exists($CODE->{DB}->{workspace})) {
 		$result = executeCachedCode('code', $CODE, \@_);
		return $result if (defined($result));

		# otherwise, run it through Compil-O-Cache
		if ($$CODE{code}) {
			my $code = createAnonSub($$CODE{code});
			$result = compileCache($code, $CODE, 'code', \@_);
			return $result if defined $result;
		}
	}

    # The reason we do not call evalXTrapErrors is because we want
    # htmlcode that is called like normal functions to fail like
    # normal function and not return some kind of bogus string that
    # they were not expecting.
    return evalX($$CODE{code}, $CODE, @_);
}


###############################################################################
#	Sub
#		htmlcode
#
#	Purpose
#		THIS IS A DEPRECATED FUNCTION!  DO NOT USE!  This is here to
#		maintain some compatibility with some older code.  The AUTOLOAD
#		method has replaced this for a more direct implementation.
#		This basically allows the calling of htmlcode with dynamic parameters
#
sub htmlcode
{
	my ($function, $args) = @_;
	my $code;
	my @args;

	if(defined($args) && $args ne "")
	{
		@args = split(/\s*,\s*/, $args);
	}

	$code = "$function(\@_);";

	return evalX($code, undef, @args);
}


###############################################################################
#	Sub
#		do_args
#
#	Purpose
#		This is a supporting function for compileCache().  It turns a
#		comma-delimited list of arguments into an array, performing variable
#		interpolation on them.  It's probably not necessary once things move
#		over to the new AUTOLOAD htmlcode scheme.
#
#	Takes
#		$args, a comma-delimited list of arguments
#
#	Returns
#		an array of manipulated arguments
#
sub do_args {
	my $args = shift;

	my @args = split(/\s*,\s*/, $args) or ();
	foreach my $arg (@args) {
		unless($arg =~ /^\$/)
		{
			$arg = "'" . $arg . "'";
		}
	}

	return @args;
}


###############################################################################
#	Sub
#		executeCachedCode
#
#	Purpose
#		This is a supporting function for Compile-O-Cache.  It attempts to
#		execute a compiled subroutine.  It does support arguments, via the
#		third parameter.  This exists to make it easier for nodes with embedded
#		code that don't go through the new parseCode.
#
#		Note that it doesn't check if $HTMLVARS{noCompile} is set, or if the
#		user is in a workspace.  If this is important to you, check them!
#
#	Takes
#		$field, the name of the field of the node that contains embedded code
#		$CURRENTNODE, the node object to check for compiled code
#		$args, an optional array reference of arguments for the	subroutine
#
#	Returns
#		The return value of the compiled code on success, undef on failure.
#		Note that if the compiled code returns undef, this function returns an
#		empty string instead.  This is the expected behavior of htmlcode and
#		other page components.
#
sub executeCachedCode {
	my ($field, $CURRENTNODE, $args) = @_;
	$args ||= [];

	my $code_ref;
	
	if ($code_ref = $CURRENTNODE->{"_cached_$field"}) {
		if (ref($code_ref) eq 'CODE' and defined &$code_ref) {
			my $warn;
			my $NODE = $GNODE;
			local $SIG{__WARN__} = sub {
				$warn .= $_[0] unless $_[0] =~ /^Use of uninitialized value/;
			};

			flushErrorsToBackside();
			
			my $result = eval { $code_ref->($CURRENTNODE, @$args) } || '';
			
			local $SIG{__WARN__} = sub {};

			logErrors($warn, $@, $$CURRENTNODE{$field},	$CURRENTNODE)
				if $warn or $@;
	
    		my $errors = getFrontsideErrors();

	    	if (int(@$errors) > 0) {
		 		$result .= htmlFormatErr($errors, $CURRENTNODE);
			}
			clearFrontside();

			return $result;
		}
	}
}


##############################################################################
#Sub
#	createAnonSub
#
#	Purpose
#		for creating compiled code references, we need to create a sub
#		ref and establish a consistent context (exactly the same as evalX
#		however, symbols must be rendered at runtime
#
#	Arguments
#		code to be compiled
#
sub createAnonSub {
	my ($code) = @_;

	"sub {
		my \$CURRENTNODE=shift;
		my \$NODE=\$GNODE; 
		$code 
	}\n";
}

###############################################################################
# Sub
#	compileCache
#
#	Purpose
#		Common compilation and caching and initial calling of htmlcode and
#		nodemethod functions.  Hopefully it keeps common code in one spot.  For
#		internal use only!
#
#	Arguments
#		$code, the text to eval() into an anonymous subroutine
#		$NODE, the node object from which the code came
#		$field, the field of the node that holds the code for that nodetype
#		$args, a reference to a list of arguments to pass
#
#	Returns
#		A string containing results of the code or a blank string.  Undef if
#		the compilation fails -- in case we need to default to old behavior.
#
sub compileCache
{
	my ($code, $NODE, $field, $args) = @_;

	my $code_ref = evalX $code, $NODE;

	return unless $code_ref;

	$NODE->{DB}->{cache}->cacheMethod($NODE, $field, $code_ref);
	return executeCachedCode($field, $NODE, $args);
}


###############################################################################
# Sub
#	nodemethod
#
#	Purpose
#		Allow compil-o-caching and calling of nodemethods.  Internal use only.
#
#	Arguments
#		$CURRENTNODE, the nodemethod node in question
#		@_, further arguments for the nodemethod code
#
#	Returns
#		The text results of the nodemethod code, if it succeeded.  Undef
#		otherwise.  See Everything::Node::AUTOLOAD for the emergency backup
#		plan.
#
sub nodemethod
{
	# args for the nodemethod may be passed here
	my ($CURRENTNODE) = shift;
	
	unless ((exists($HTMLVARS{noCompile}) and $HTMLVARS{noCompile}) or
		exists($CURRENTNODE->{DB}->{workspace})) {
		my $result = executeCachedCode('code', $CURRENTNODE, \@_);
		return $result if (defined($result));

		my $code = "sub {\n$$CURRENTNODE{code}\n}";
		return compileCache($code, $CURRENTNODE, 'code', \@_);
	}
}


################################################################################
#	Sub
#		htmlsnippet
#
#	Purpose
#		allow for easy use of htmlsnippet functions in embedded perl
#		[<BacksideErrors>] would become: htmlsnippet('BacksideErrors');
#
#	Parameters
#		$snippet -- the htmlsnippet name
#
#	Returns
#		The HTML from the snippet
#
sub htmlsnippet
{
	my ($snippet) = @_;
	my $node = getNode($snippet, 'htmlsnippet');
	my $html = '';
	# User must have execute permissions for this to be embedded.
	if((defined $node) && $node->hasAccess($USER, "x")) {
		$html = parseCode('code', $node); 
	}
	return $html;
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
		$block = evalXTrapErrors($block . ';', $CURRENTNODE);	
	}
	elsif ($block =~ /^\{(.*)\}$/s)
	{
		# This is an htmlcode.  We need to construct a function call, and
		# eval it.  AUTOLOAD will do the rest.

		my ($func, $args) = split /\s*:\s*/, $1;
		my @args;
		$args ||= "";

		@args = split(/\s*,\s*/, $args) if($args);

		foreach (@args)
		{
			# Wrap each argument in quotes, except those that start with
			# a '$'.  This way, global vars can be used in calling htmlcode
			# ie [{mycode: hello, $USER}]
			$_ = "'" . $_ . "'" unless($_ =~ /^\$/);
		}

		$args = join(", ", @args);

		my $code = $func . "(" . $args . ");";
		$block = evalXTrapErrors($code, $CURRENTNODE);
	}
	elsif ($block =~ /^\%(.*)\%$/s)
	{
		$block = evalXTrapErrors($1, $CURRENTNODE);	
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
#		parseCode (new)
#
#	Purpose
#		Given the text from a node that is to be displayed, parse out the
#		code blocks, compile the whole thing into an anonymous subroutine,
#		cache it, and call it.  Or call it if it's already compiled.  WHOOSH!
#
#		NOTE!!! This is a full parse and eval.  You do NOT NOT NOT want to
#		call this on text that an untrusted user can modify.  You don't
#		want users creating nodes with [% `rm -rf /*` %] in their code.
#		Calling this on untrusted user text is a security breach.
#
#	Parameters
#		$field - the field to be parsed for the code blocks
#		$CURRENTNODE - the node which this text is coming from.  
#
#	Returns
#		The parsed HTML with the embedded code parsed and replaced with its
#		generated result.  Given:
#			<p>Hello ["$$USER{title}"]
#
#		Will return:
#			<p>Hello Bob
#
sub parseCode
{
	my ($field, $CURRENTNODE) = @_;

	if ((exists($HTMLVARS{noCompile}) and $HTMLVARS{noCompile}) or
		exists($CURRENTNODE->{DB}->{workspace})) {
		return oldparseCode($field, $CURRENTNODE);
	}

	my $result = executeCachedCode($field, $CURRENTNODE);
	return $result if (defined($result));

	my $args = [];

	my $sub_text =' my $result; ';

	# the /s modifier makes . match newlines.  VERY important.
	for my $chunk (split(/(\[(?:\{.*?\}|\".*?\"|%.*?%|<.*?>)\])/s,
		$$CURRENTNODE{$field})) {
		next unless $chunk =~ /\S/;

		$sub_text .= "\n\t";
		my ($start, $code, $end);
		if (($start, $code, $end) = $chunk =~ /^\[([%"<{])(.+?)([%">}])\]$/s) { 
		# embedded code
			$code =~ s!"!\"!g;

			# htmlcode turns into a function call:
			#	( $htmlcode('arg1', 'arg2') || '')
			if ($start eq '{') {
				my ($func, $args) = split(/\s*:\s*/, $code);
				$sub_text .= "\$result .= ( eval { $func(";
				if (defined $args) {
					my @args = do_args($args);
					$sub_text .= join(", ", @args) if (@args);
				}
				$sub_text .= ") } || '' );";

			# htmlsnippets turn into simpler function calls:
			#	htmlsnippet('snippetname')
			} elsif ($start eq '<') {
				$sub_text .= "\$result .= eval {htmlsnippet('$code')} || '';\n";

			# embedded code needs a dedicated block to work unmodified:
			#	( eval { return 'foo'; } || '' )
			} elsif ($start eq '"' or $start eq '%') {
				$sub_text .= "\$result .= ( eval {\n$code\n} || '' );\n";
			}
			$sub_text .= qq|\nlogErrors('', \$\@, '', { title => 
				'$$CURRENTNODE{title}', node_id => '$$CURRENTNODE{node_id}' }) 
				if (\$\@);\n|;

		# raw text, needs to be quoted -- the quoting should work correctly
		# as there's no need to escape quotes in raw HTML sections anyway
		} else {
			next unless ($chunk =~ /\S/);

			# Use single quotes!!!  We need to wrap this chunk of text in
			# single quotes because we do not want perl to be evaluating
			# anything outside our embedded code.  If this is wrapped in
			# double quotes, things like \n, \t, $hello, and anything the
			# raw text contained that perl would recognize would be evaled
			# and we don't want that.  Raw text is raw text and should
			# be left alone.
			$chunk =~ s!\'!\\'!g;
			$sub_text .= qq|\$result .= '$chunk';\n|;
		}
	}

	# add newlines so trailing comments don't cause eval() errors
	$sub_text .= qq|\nreturn \$result;\n|;
	
	$sub_text = createAnonSub($sub_text);

	$result = compileCache($sub_text, $CURRENTNODE, $field, $args);
	return $result if defined $result;

    # on failure, use old behavior
	return oldparseCode($field, $CURRENTNODE);
}


#############################################################################
#	Sub
#		oldparseCode
#
#	Purpose
#		Given the text from a node that is to be displayed, parse out the
#		code blocks and eval them.  No caching here, plod plod.
#
#	Parameters
#		$field - the field to be parsed for the code blocks
#		$CURRENTNODE - the node which this text is coming from.  
#
sub oldparseCode
{
	my ($field, $CURRENTNODE) = @_;

    my $text = $$CURRENTNODE{$field};

	# the embedding styles are:  
	$text=~s/
	 \[
	 (
	 \{.*?\} # [{ }]s -- calls to the code database
	 |".*?"  # [" "]s -- embedded code strings
	 |%.*?%  # [% %]s -- full embedded perl
	 |<.*?>  # [< >]s -- embedded HTML
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
	$NODELET = shift @_;
	my $type = shift @_;
	
	$type ||= 'nodelet';
	$NODELET = $DB->getNode($NODELET, $type);

	# If the user can't "execute" this nodelet, we don't let them see it!
	return undef unless(defined $NODELET && $NODELET->hasAccess($USER, "x"));
	
	my $html;
	$html = genContainer($$NODELET{parent_container}) 
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
#	Sub
#		genContainer
#
#	Purpose
#		Creates the HTML for a container, recursively generating its parents if
#		necessary.
#
#	Parameters
#		$CONTAINER - a container node or the node_id of a container
#		$noClear - for internal use only.  Pass undef when calling this
#
#	Returns
#		The generated HTML
#
sub genContainer
{
	my ($CONTAINER, $noClear) = @_;
	getRef $CONTAINER;
	my $replacetext;
	my $containers;

	$GLOBAL{containerTrap} = { } unless($noClear);
	if(exists $GLOBAL{containerTrap}{$$CONTAINER{node_id}})
	{
		logErrors("Error! Infinite loop in container hierarchy!");
		return "Container Error!";
	}
	
	# Mark this container as being "visted";
	$GLOBAL{containerTrap}{$$CONTAINER{node_id}} = 1;

	$replacetext = parseCode ('context', $CONTAINER);
	$containers = $query->param('containers') || '';

	# SECURITY!  Right now, only gods can see the containers.  When we get
	# a full featured security model in place, this will change...
	if($USER->isGod() && ($containers eq "show"))
	{
		my $start = "";
		my $middle = $replacetext;
		my $end = "";
		my $debugcontainer = $DB->getNode('show container', 'container');
		
		# If this container contains the body tag, we do not want to wrap
		# the entire thing in the debugcontainer.  Rather, we want to wrap
		# the contents inside the body tag.  If we don't do this, we end up
		# wrapping the <head> and <body> in a table, which makes the page
		# not display right.
		if($replacetext =~ /<body/i)
		{
			$replacetext =~ /(.*<body.*>)(.*)(<\/body>.*)/is;
			$start = $1;
			$middle = $2;
			$end = $3;
		}

		if($debugcontainer)
		{
			$GLOBAL{debugContainer} = $CONTAINER;
			my $debugtext = parseCode('context', $debugcontainer);
			$debugtext =~ s/CONTAINED_STUFF/$middle/s;
			$replacetext = $start . $debugtext . $end;
		}
	}
	
	if ($$CONTAINER{parent_container}) {
		my $parenttext = genContainer($$CONTAINER{parent_container}, 1);	
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
	
	# Fill out the THEME hash
	getTheme($NODE);
	
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
	my $errors = '';
	if($USER->isGod())
	{
		$errors = formatGodsBacksideErrors();
	}
	else
	{
		printBacksideToLogFile();
	}
	$page =~ s/<BacksideErrors>/$errors/;
	
	# Print the appropriate MIME type header so that browser knows what
	# kind of data is coming down the pipe.
	printHeader($$PAGE{MIMEtype});
	
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
#
sub printHeader
{
	my ($datatype) = @_;

	# default to plain html
	$datatype ||= "text/html";
	
	if($ENV{SCRIPT_NAME})
	{
		if ($$USER{cookie})
		{
			print $query->header(-type=> $datatype, 
		 		-cookie=>$$USER{cookie});
		}
		else
		{
			print $query->header(-type=> $datatype);
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
	undef %INCJS;

	$GNODE = {};
	$USER = {};
	$VARS = {};
	$NODELET = {};
	$THEME = {};

	$query = "";

	# Initialize our connection to the database
	Everything::initEverything($db, 1);


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

	if($$NODE{node_id} == 0)
	{
		$query->param('node_id', $HTMLVARS{nodedeleted_node});
		$GLOBAL{nodedeleted} = $NODE;
	}
}


#############################################################################
sub opLogin
{
	my $user = $query->param("user");
	my $passwd = $query->param("passwd");
	my $cookie;

	my $U = getNode($user,'user');
	$user = $$U{title} if $U;
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
sub opLock
{
	my $LOCKEDNODE = getNode($query->param('node_id'));
	$LOCKEDNODE->lock($USER);
}


#############################################################################
#	Sub
#		opUpdate
#
#	Purpose
#		This is the operation that handles the automated upates to the
#		node data in the Everything system.  This looks for CGI parameters
#		of the form 'formbind_FormObjectName_FormItemName', where
#		'FormObjectName', is the name of the FormObject (nodetype) that
#		generated the HTML for this, and 'FormItemName' is the name of
#		the HTML form item (ie <input name='FormItemName'...>).
#
#		If it finds any parameters that matches that pattern, it constructs
#		a node of that form object type (ie textfield, checkbox, etc) and
#		passes the name of the form object to it.  This allows the object
#		to reconstruct itself based on the fact that it knows what it
#		generated.  The object can then determine what node and field it
#		is bound to, and the form object handles the update of the node.
#
#		If any of the fields fail the verification, the system will go
#		to the node specified by the node_id parameter (in most cases,
#		this should be back to the page that contained the form that
#		was doing the update).
#
#		If all of the fields that need to be updated verify that the
#		user has access to update and that the data entered by the user
#		is valid, then we proceed to update the fields of the node(s).
#		None of the nodes are actually updated until all fields have
#		been updated.  This is to allow us to make 1 update() call per
#		node rather than calling update once per field update.
#
#		Once all of the nodes have been updated, this will look for
#		two more optional parameters: 'opupdate_redirect', and
#		'opupdate_displaytype'.  If 'opupdate_redirect' is specified,
#		it should contain the numeric node id of the node to go to.
#		opupdate_display type should contain the type of display for
#		that node.  For example, this way you could update a node,
#		can automatically redirect to another node's edit page.
#
sub opUpdate
{
	my @params = $query->param();
	my %UPDATENODES;
	my %UPDATEOBJECT;
	my $CGIVERIFY = 1;  # Assume that we succeed until we fail
	my @formbind;
	my @sort;
	
	my $preprocess = $query->param('opupdate_preprocess');
	my $postprocess = $query->param('opupdate_postprocess');

	foreach my $param (@params)
	{
		push @formbind, $param if($param =~ /^formbind_(.+?)_(.+)$/);
	}

	# Nothing to update
	return 1 if(int(@formbind) == 0);

	# We want to execute them in the order of the first two digits.
	# This way, form objects that do deletion stuff can go last or
	# objects that need to do some kind of setup can go first
	@sort = sort { $query->param($a) cmp $query->param($b) } @formbind;

	if($preprocess)
	{
		# turn the htmlcode name into a function call
		evalX($preprocess."();") if getNode($preprocess, 'htmlcode');
	}
	
	# First, we need to verify that all fields in this update are
	# what we expect.
	foreach my $param (@sort)
	{
		$param =~ /formbind_(.+?)_(.+)$/;
		my $objectType = $1;
		my $objectName = $2;
		my $formObject = newFormObject($objectType);

		next unless($formObject);

		my $verify = $formObject->cgiVerify($query, $objectName, $USER);
		if($$verify{failed})
		{
			$GLOBAL{VERIFYFAILED} ||= {};
			$GLOBAL{VERIFYFAILED}{$objectName} = $$verify{failed};

			$CGIVERIFY = 0;
		}
		elsif($$verify{node})
		{
			$UPDATEOBJECT{$param} = $$verify{node};
			$UPDATENODES{$$verify{node}} ||= getNode($$verify{node})
		}
	}

	# If anything failed a verify, abort the update
	return unless($CGIVERIFY);

	# Ok, all form objects that were bound to something verified that they
	# can be updated.  So, lets do it!  This just modifies the hash objects
	# as needed.  We wait until all updates are finished before actually
	# committing the changes to the database via update().  This way we
	# avoid doing an update() for each change.
	my $god = $USER->isGod();
	foreach my $param (@sort)
	{
		$param =~ /formbind_(.*?)_(.*)$/;
		my $objectType = $1;
		my $objectName = $2;
		my $formObject = newFormObject($objectType);

		next unless($formObject);

		if(exists $UPDATEOBJECT{$param})
		{
			$formObject->cgiUpdate($query, $objectName,
				$UPDATENODES{$UPDATEOBJECT{$param}}, $god)
		}
	}

	# Now that we have all of the nodes updated as needed, we can commit
	# them to the database.
	foreach my $node (keys %UPDATENODES)
	{
		# Log a revision (for undo/redo) on each of the updated nodes.
		$UPDATENODES{$node}->logRevision($USER);
		$UPDATENODES{$node}->update($USER);
			
		# This is the case where the user is modifying their own user
		# node.  If we want the user node to take effect in one page
		# load, we need to set it here.
		$USER = $UPDATENODES{$node}
			if ($$USER{node_id} == $UPDATENODES{$node}{node_id});
	}

	# Lastly, we need to determine if we have any kind of redirection
	# upon succeeding with the update.
	my $goto_node = $query->param('opupdate_redirect');
	my $goto_displaytype = $query->param('opupdate_displaytype');

	$query->param('node_id', $goto_node) if($goto_node);
	$query->param('displaytype', $goto_displaytype) if($goto_displaytype);
	
	if($postprocess)
	{
		# turn the htmlcode name into a function call.  This will end
		# up calling HTML::AUTOLOAD()
		evalX($postprocess."();") if getNode($postprocess, 'htmlcode');
	}

	return 1;
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
#		$user - the user that is going to execute this operation.  For
#			authentication
#
#	Returns
#		the opcode Node if found and the user has the ability to execute it.
#		undef otherwise.
#
sub getOpCode
{
	my ($opname, $user) = @_;
	my $OPNODE = getNode($opname, "opcode");
	
	# If a user cannot execute this, don't do it.
	return undef unless($OPNODE && $OPNODE->hasAccess($user, "x"));

	return $OPNODE;
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
	my $handled;
	my $OPCODE;
	
	# The CGI parameter for 'op' can be an array of several operations
	# we want to do, so we need to execute each of them.
	foreach my $op ($query->param('op'))
	{
		$handled = 0;

		$OPCODE = getOpCode($op, $USER);
		$handled = evalX($$OPCODE{code}, $OPCODE) if(defined $OPCODE);

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
			elsif($op eq 'update')
			{
				opUpdate();
			}
			elsif($op eq 'unlock')
			{
				opUnlock();
			}
			elsif($op eq 'lock')
			{
				opLock();
			}
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
#		updateNodeData  DEPRECATED!!!  DO NOT USE!
#
#	Purpose
#		If we have a node_id, we may be getting some params that indicate
#		that we should be updating the node.  This checks for those
#		parameters and updates the node if necessary.
#
sub updateNodeData
{
	#warn("Using updateNodeData() (deprecated!).  Stop that!");
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
			$NODE->logRevision($USER) unless exists $DB->{workspace};
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

	#join a workspace (if applicable)
	$DB->joinWorkspace($$USER{inside_workspace});

	# Execute any operations that we may have
	execOpCode();

	#an opcode might have changed our workspace.  Join again.
	$DB->joinWorkspace($$USER{inside_workspace});

	# DEPRECATED!  DO NOT USE!
	updateNodeData();
	

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
