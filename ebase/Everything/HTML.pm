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
require CGI;
use CGI::Carp qw(fatalsToBrowser);


sub BEGIN {
	use Exporter ();
	use vars qw($DB $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		$DB
		%HTMLVARS
		$query
		jsWindow
		createNodeLinks
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
		nodeName
		evalCode
		htmlcode
		embedCode
		displayPage
		gotoNode
		confirmUser
		urlDecode
		encodeHTML
		decodeHTML
		mod_perlInit);
}

use vars qw($query);
use vars qw(%HTMLVARS);
use vars qw($GNODE);
use vars qw($USER);
use vars qw($VARS);
use vars qw($THEME);
use vars qw($NODELET);



######################################################################
#	sub
#		tagApprove
#
#	purpose
#		determines whether or not a tag (and it's specified attributes)
#		are approved or not.  Returns the cleaned tag.  Used by htmlScreen
#
sub tagApprove {
	my ($close, $tag, $attr, $APPROVED) = @_;

	$tag = uc($tag) if (exists $$APPROVED{uc($tag)});
	$tag = lc($tag) if (exists $$APPROVED{lc($tag)});

	if (exists $$APPROVED{$tag}) {
		my @aprattr = split ",", $$APPROVED{$tag};
		my $cleanattr;
		foreach (@aprattr) {
			if (($attr =~ /\b$_\b(\='.*?')/) or
				($attr =~ /\b$_\b(\=".*?")/) or
				($attr =~ /\b$_\b(\=\S*)?/)) {
				$cleanattr.=" ".$_.$1;
			}
		}
		"<".$close.$tag.$cleanattr.">";
	} else { ""; }
}

#############################################################################
#	sub
#		htmlScreen
#
#	purpose
#		screen out html tags from a chunk of text
#		returns the text, sans any tags that aren't "APPROVED"		
#
#	params
#		text -- the text to filter
#		APPROVED -- ref to hash where approved tags are keys.  Null means
#			all HTML will be taken out.
#
sub htmlScreen {
	my ($text, $APPROVED) = @_;
	$APPROVED ||= {};

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
	$html =~ tr/\&/\&amp\;/;
	$html =~ tr/\</\&lt\;/;
	$html =~ tr/\>/\&gt\;/;
	$html =~ tr/\"/\&quot\;/;

	if($adv)
	{
		$html =~ tr/\[/\&\#91\;/;
		$html =~ tr/\]/\&\#93\;/;
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

	$html =~ tr/\&amp\;/\&/;
	$html =~ tr/\&lt\;/\</;
	$html =~ tr/\&gt\;/\>/;
	$html =~ tr/\&quot\;/\"/;

	if($adv)
	{
		$html =~ tr/\&\#91\;/\[/;
		$html =~ tr/\&\#93\;/\]/;
	}

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
#		$code - the code snipit that is causing the error
#		$err - the error message returned from the system
#		$warn - the warning message returned from the system
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlFormatErr
{
	my ($code, $err, $warn) = @_;
	my $str;

	if(isGod($USER))
	{
		$str = htmlErrorGods($code, $err, $warn);
	}
	else
	{
		$str = htmlErrorUsers($code, $err, $warn);
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
#		$code - the code snipit that is causing the error
#		$err - the error message returned from the system
#		$warn - the warning message returned from the system
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlErrorUsers
{
	my ($code, $err, $warn) = @_;
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
	# do see all the messy perl code.
	Everything::printLog("Server Error (#" . $errorId .
		"):\nCode:\n$code\nError:\n$err\nWarning:\n$warn");

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
	my ($code, $err, $warn) = @_;
	my $error = $err . $warn;
	my $linenum;

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
			# This highlights the offendling line in red.
			$mycode[$1-1] = "<FONT color=cc0000><b>" . $mycode[$1-1] .
				"</b></font>";
		}
	}

	my $str = "<B>$@ $warn</B><BR>";

	my $count = 1;
	$str.= "<PRE>";
	foreach my $line (@mycode)
	{
		$str .= sprintf("%4d: $line\n", $count++, $str);
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
	$str;
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

	foreach my $key (keys %$REF) {
		$str .= $query->escape($key) .'='. $query->escape($$REF{$key}) .'&';
	}
	chop $str;
	$str .= '"' unless $noquotes;
	$str;
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
sub getCode
{
	my ($funcname, $args) = @_;

	my $CODE = getNode($funcname, getType("htmlcode"));
	
	return '"";' unless (defined $CODE);

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

	$TYPE = $NODE if (isNodetype($NODE) && $$NODE{extends_nodetype});
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

		($PAGE) = getNodeWhere(\%WHEREHASH, $PAGETYPE);

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
				($PAGE) = getNodeWhere (
						{pagetype_nodetype => getId(getType("node")),
						displaytype => $displaytype}, 
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

	$PAGE;
}


#############################################################################
sub linkNode {
	my ($NODE, $title, $PARAMS) = @_;
	#getRef $NODE;	

	return unless $NODE;
	unless (ref $NODE) {
		$NODE = getNodeById($NODE, 'light');
	}
	return unless ref $NODE;	
	
	if ($NODE == -1) {return "<a>$title</a>";}
	$title ||= $$NODE{title};
	$$PARAMS{node_id} = getId $NODE;
	my $tags = "";

	$$PARAMS{lastnode_id} = getId ($GNODE) unless exists $$PARAMS{lastnode_id};
	#any params that have a "-" preceding 
	#get added to the anchor tag rather than the URL
	foreach my $key (keys %$PARAMS) {
		next unless ($key =~ /^-/); 
		my $pr = substr $key, 1;
		$tags .= " $pr=\"$$PARAMS{$key}\""; 
		delete $$PARAMS{$key};
	}
	
	"<A HREF=" . urlGen ($PARAMS) . $tags . ">$title</a>";
}


#############################################################################
sub linkNodeTitle {
	my ($nodename, $lastnode, $title) = @_;

	($nodename, $title) = split /\|/, $nodename;
	$title ||= $nodename;
	$nodename =~ s/\s+/ /gs;
	
	my $urlnode = $query->escape($nodename);
	my $str = "";
	$str .= "<a href=\"$ENV{SCRIPT_NAME}?node=$urlnode";
	if ($lastnode) { $str .= "&lastnode_id=" . getId($lastnode);}
	$str .= "\">$title</a>";

	$str;
}


#############################################################################
#	Sub
#		nodeName
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
sub nodeName
{
	my ($node, $user_id) = @_;

	if (my $KW = getNode ('keyword settings', 'setting')) {
		my $WORDS = getVars $KW;	
		my $title = lc($node) ."_node";
		#please note -- this means that keywords must be in lower case...

		if (exists $$WORDS{$title}) {
			gotoNode($$WORDS{$title}, $user_id);
			return;
		}
	}


	my @types = $query->param("type");
	foreach(@types) {
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
			$NODE = getNodeById($HTMLVARS{search_group});
			$$NODE{group} = $search_group;
		}
		else
		{
			$NODE = getNodeById($HTMLVARS{not_found});	
		}

		displayPage ($NODE, $user_id);
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
		my $NODE = getNodeById($HTMLVARS{duplicate_group});
		
		$$NODE{group} = $select_group;
		displayPage($NODE, $user_id);
	}
}


#############################################################################
#this function takes a bit of code to eval 
#and returns it return value.
#
#it also formats errors found in the code for HTML
sub evalCode {
	my ($code, $CURRENTNODE) = @_;
	#these are the vars that will be in context for the evals

	my $NODE = $GNODE;
	my $warnbuf = "";

	local $SIG{__WARN__} = sub { 
		$warnbuf .= $_[0] 
		 unless $_[0] =~ /^Use of uninitialized value/;
	};

	$code =~ s/\015//gs;
	my $str = eval $code;

 	local $SIG{__WARN__} = sub {};
	$str .= htmlFormatErr ($code, $@, $warnbuf) if ($@ or $warnbuf); 
	$str;
}

#########################################################################
#	sub htmlcode
#
#	purpose
#		allow for easy use of htmlcode functions in embedded perl
#		[{textfield:title,80}] would become:
#		htmlcode('textfield', 'title,80');
#
#	args
#		func -- the function name
#		args -- the arguments in a comma delimited list
#
#
sub htmlcode {
	my ($func, $args) = @_;
	my $code = getCode($func, $args);
	evalCode($code) if($code);
}

#############################################################################
#a wrapper function.
sub embedCode {
	my $block = shift @_;

	my $NODE = $GNODE;
	
	$block =~ /^(\W)/;
	my $char = $1;
	
	if ($char eq '"') {
		$block = evalCode ($block . ';', @_);	
	} elsif ($char eq '{') {
		#take the arguments out
		
		$block =~ s/^\{(.*)\}$/$1/s;
		my ($func, $args) = split /\s*:\s*/, $block;
		$args ||= "";
		my $pre_code = "\@\_ = split (/\\s*,\\s*/, \"$args\"); ";
		#this line puts the args in the default array
		
		$block = embedCode ('%'. $pre_code . getCode ($func) . '%', @_);
	} elsif ($char eq '%') {
		$block =~ s/^\%(.*)\%$/$1/s;
		$block = evalCode ($block, @_);	
	}
	
	# Block needs to be defined, otherwise the search/replace regex
	# stuff will break when it gets an undefined return from this.
	$block ||= "";

	return $block;
}


#############################################################################
sub parseCode {
	my ($text, $CURRENTNODE) = @_;

	# the order is:  
	# [% %]s -- full embedded perl
	# [{ }]s -- calls to the code database
	# [" "]s -- embedded code strings
	#
	# this is important to know when you are writing pages -- you 
	# always want to print user data through [" "] so that they
	# cannot embed arbitrary code...
	#
	# someday I'll come up with a better way to do that...

	$text =~ s/\[([\%\{\"].*?[\%\}\"])\]/embedCode($1, $CURRENTNODE)/egs;
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
#		code -- the block of code to display
#		numbering -- set to true if linenumbers are desired
#
sub listCode {
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

	"<PRE>" . join ("\n", @lines) . "</PRE>";
}


#############################################################################
sub quote {
	my ($text) = @_;

	$text =~ s/([\W])/sprintf("&#%03u", ord $1)/egs;
	$text; 
}


#############################################################################
sub insertNodelet
{
	($NODELET) = @_;
	getRef $NODELET;
	
	my $html = genContainer($$NODELET{parent_container}) 
		if $$NODELET{parent_container};

	# Make sure the nltext is up to date
	updateNodelet($NODELET);
	return unless ($$NODELET{nltext} =~ /\S/);
	
	# now that we are guaranteed that nltext is up to date, sub it in.
	if ($html) { $html =~ s/CONTAINED_STUFF/$$NODELET{nltext}/s; }
	else { $html = $$NODELET{nltext}; }
	$html;
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

	getRef $NODELET;

	$interval = $$NODELET{updateinterval};
	$lastupdate = $$NODELET{lastupdate};
	
	# Return if we have generated it, and never want to update again (-1) 
	return if($interval == -1 && $lastupdate != 0);
	
	# If we are beyond the update interal, or this thing has never
	# been generated before, generate it.
	if((not $currTime or not $interval) or
		($currTime > $lastupdate + $interval) || ($lastupdate == 0))
	{
		$$NODELET{nltext} = parseCode($$NODELET{nlcode}, $NODELET);
		$$NODELET{lastupdate} = $currTime; 

		updateNode($NODELET, -1);
	}
	
	""; # don't return anything
}


#############################################################################
sub genContainer {
	my ($CONTAINER) = @_;
	getRef $CONTAINER;
	my $replacetext;

	$replacetext = parseCode ($$CONTAINER{context}, $CONTAINER);

	if ($$CONTAINER{parent_container}) {
		my $parenttext = genContainer($$CONTAINER{parent_container});	
		$parenttext =~ s/CONTAINED_STUFF/$replacetext/s;
		$replacetext = $parenttext;
	} 
	
	$replacetext;	
}


############################################################################
#	Sub	containHtml
#
#	purpose
#		Wrap a given block of HTML in a container specified by title
#		hopefully this makes containers easier to use
#
#	params
#		container - title of container
#		html - html to insert
#
sub containHtml {
	my ($container, $html) =@_;
	my ($TAINER) = getNode($container, getType("container"));
	my $str = genContainer($TAINER);

	$str =~ s/CONTAINED_STUFF/$html/g;
	$str;
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
sub displayPage
{
	my ($NODE, $user_id) = @_;
	getRef $NODE, $USER;
	die "NO NODE!" unless $NODE;
	$GNODE = $NODE;

	my $PAGE = getPage($NODE, $query->param('displaytype')); 
	my $page = $$PAGE{page};

	die "NO PAGE!" unless $page;

	$page = parseCode($page, $NODE);
	if ($$PAGE{parent_container}) {
		my $container = genContainer($$PAGE{parent_container}); 
		$container =~ s/CONTAINED_STUFF/$page/s;
		$page = $container;
	}	
	
	setVars $USER, $VARS;
	
	printHeader($$NODE{datatype});
	
	# We are done.  Print the page to the browser.
	$query->print($page);
}


#############################################################################
#the function where we go when we actually know which $NODE we want to view
sub gotoNode
{
	my ($node_id, $user_id) = @_;

	my $NODE = {};
	unless (ref ($node_id) eq 'ARRAY') {
		# Is there a reason why we are "force"ing this node?
		# A 'force' causes us not to use the cache.
		$NODE = getNodeById($node_id, 'force');
	}
	else {
		$NODE = getNodeById($HTMLVARS{search_group});
		$$NODE{group} = $node_id;
	}

	unless ($NODE) { $NODE = getNodeById($HTMLVARS{not_found}); }	
	
	unless (canReadNode($user_id, $NODE)) {
		$NODE = getNodeById($HTMLVARS{permission_denied});
	}
	#these are contingencies various things that could go wrong

	if (canUpdateNode($user_id, $NODE)) {
		if (my $groupadd = $query->param('add')) {
			insertIntoNodegroup($NODE, $user_id, $groupadd,
				$query->param('orderby'));
		}
		
		if ($query->param('group')) {
			my @newgroup;

			my $counter = 0;
			while (my $item = $query->param($counter++)) {
				push @newgroup, $item;
			}

			replaceNodegroup ($NODE, \@newgroup, $user_id);
		}

		my @updatefields = $query->param;
		my $updateflag;

		my $RESTRICTED = getVars(getNode('restricted fields', 'setting'));
		$RESTRICTED ||= {};
		foreach my $field (@updatefields) {
			if ($field =~ /^$$NODE{type}{title}\_(\w*)$/) {
				next if exists $$RESTRICTED{$1};	
				$$NODE{$1} = $query->param($field);
				$updateflag = 1;
			}	
		}
		if ($updateflag) {
			updateNode($NODE, $USER); 
			if (getId($USER) == getId($NODE)) { $USER = $NODE; }
		}
	}
	
	updateHits ($NODE);
	updateLinks ($NODE, $query->param('lastnode_id')) if $query->param('lastnode_id');

	my $displaytype = $query->param("displaytype");

	#if we are accessing an edit page, we want to make sure user
	#has rights -- also, lock the page
	#we unlock the page on command as well...
	if ($displaytype and $displaytype eq "edit") {
		if (canUpdateNode ($USER, $NODE)) {
			if (not lockNode($NODE, $USER)) {
				$NODE = getNodeById($HTMLVARS{node_locked});
				$query->param('displaytype', 'display');
			} 
		} else {
			$NODE = getNodeById($HTMLVARS{permission_denied});
			$query->param('displaytype', 'display');
		}
	} elsif ($query->param('op') eq "unlock") {
		unlockNode ($USER, $NODE);
	}

	displayPage($NODE, $user_id);
}


#############################################################################
sub confirmUser {
	my ($nick, $crpasswd) = @_;

	my $USER = getNode($nick, getType('user'));

	Everything::printLog("passwd: $$USER{passwd}, name: $$USER{title}");
	
	if (crypt ($$USER{passwd}, $$USER{title}) eq $crpasswd) {
		my $rows = $DB->getDatabaseHandle()->do("
			UPDATE user SET lasttime=now() WHERE
			user_id=$$USER{node_id}
			") or die;

		# 'Force' it to make sure we don't get a cached version
		return getNodeById($USER, 'force');
	} 
	return 0;
}


#############################################################################
sub parseLinks {
	my ($text, $NODE) = @_;

	Everything::printLog("parseLinks");
	$text =~ s/\[(.*?)\]/linkNodeTitle ($1, $NODE)/egs;
	$text;
}


#############################################################################
sub urlDecode {
	foreach my $arg (@_) {
		tr/+/ / if $_;
		$arg =~ s/\%(..)/chr(hex($1))/ge;
	}

	$_[0];
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
	
	if ($query->param("op") eq "login")
	{
		$user = $query->param("user");
		$passwd = $query->param("passwd");

		$user_id = confirmUser ($user, crypt ($passwd, $user));
		
		# If the user/passwd was correct, set a cookie on the users
		# browser.
		$cookie = $query->cookie(-name => "userpass", 
			-value => $query->escape($user . '|' . crypt ($passwd, $user)), 
			-expires => $query->param("expires")) if $user_id;
	}
	elsif ($query->param("op") eq "logout")
	{
		# The user is logging out.  Nuke their cookie.
		$cookie = $query->cookie(-name => 'userpass', -value => "");
		$user_id = $HTMLVARS{guest_user};	

	}
	elsif (my $oldcookie = $query->cookie("userpass"))
	{
		$user_id = confirmUser (split (/\|/, urlDecode ($oldcookie)));
	}
	
	# If all else fails, use the guest_user
	$user_id ||= $HTMLVARS{guest_user};				

	# Get the user node
	$USER_HASH = getNodeById($user_id);	

	die "Unable to get user!" unless ($USER_HASH);

	# Assign the user vars to the global.
	$VARS = getVars($USER_HASH);
	
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
#		this function references global variables, so no params are needed
#

sub getTheme {
	my $theme_id;
	$theme_id = $$VARS{preferred_theme} if $$VARS{preferred_theme};
	$theme_id ||= $HTMLVARS{default_theme};
	my $TS = getNodeById $theme_id;

	if ($$TS{type}{title} eq 'themesetting') {
		#we are referencing a theme setting.
		my $BASETHEME = getNodeById $$TS{parent_theme};
		$THEME = getVars $BASETHEME;
		my $REPLACEMENTVARS = getVars $TS;
		@$THEME{keys %$REPLACEMENTVARS} = values %$REPLACEMENTVARS;
	} else {
		#this whatchamacallit is a theme
		$THEME = getVars $TS;
	}

	#we must also check the user's settings for any replacements over the theme
	foreach (keys %$THEME) {
		if (exists $$VARS{"theme".$_}) {
			$$THEME{$_} = $$VARS{"theme".$_};
		}
	}
	#$THEME= {};
	1;
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
sub printHeader
{
	my ($datatype) = @_;

	# default to plain html
	$datatype ||= "text/html";
	
	if($ENV{SCRIPT_NAME}) {
		if ($$USER{cookie}) {
			$query->header(-type=> $datatype, 
		 		-cookie=>$$USER{cookie});
		} else {
			$query->header(-type=> $datatype);
		}
	}
}


#############################################################################
#	Sub
#		handleUserRequest
#
#	Purpose
#		This check the CGI information to find out what the user is trying
#		to do and executes their request.
#
#	Parameters
#		None.  Uses the global package variables.
#
sub handleUserRequest
{
	my $user_id = $$USER{node_id};
	my $node_id;
	my $nodename;
	
	if ($query->param("op") eq "nuke" && $query->param("node_id"))
	{
		$node_id = $query->param("node_id");
		
		nukeNode($node_id, $user_id);

		# This should now result in a "Not found" page
		gotoNode ($node_id, $user_id);

		return;
	}
	elsif ($query->param('node'))
	{
		# Searching for a node my string title
		my $type  = $query->param('type');
		my $TYPE = getType($type);
		
		$nodename = $query->param('node');
		$nodename =~ tr/[]|<>//d;
		$nodename =~ s/^\s*|\s*$//g;
		$nodename =~ s/\s+/ /g;
		$nodename ="" if $nodename=~/^\W$/;
		#$nodename = substr ($nodename, 0, 80);
		$query->param("node", $nodename);
		
		if ($query->param('op') ne 'new')
		{
			nodeName ($nodename, $user_id, $type); 
		}
		elsif (canCreateNode($user_id, $DB->getType($type)))
		{
			$node_id = insertNode($nodename,$TYPE, $user_id);

			if($node_id == 0)
			{
				# It appears that the node already exists.  Get its id.
				$node_id = sqlSelect("node_id", "node", "title=" .
					$DB->quote($nodename) . " && type_nodetype=" .
					$$TYPE{node_id});
			}

			gotoNode($node_id, $user_id);
		} 
		else
		{
			gotoNode($HTMLVARS{permission_denied}, $user_id);
		}
	}
	elsif ($node_id = $query->param('node_id'))
	{
		#searching by ID
		gotoNode($node_id, $user_id);
	}
	else
	{
		#no node was specified -> default
		gotoNode($HTMLVARS{default_node}, $user_id);
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


	#blow away the globals
	($GNODE, $USER, $VARS, $NODELET,$THEME) = ("", "", "", "","");

	$query = "";
	Everything::initEverything($db);

	# Get the HTML variables for the system.  These include what
	# pages to show when a node is not found (404-ish), when the
	# user is not allowed to view/edit a node, etc.  These are stored
	# in the dbase to make changing these values easy.	
	%HTMLVARS = %{ eval (getCode('set_htmlvars')) };

	$query = getCGI();

	$USER = loginUser();
	getTheme();


	# Do the work.
	handleUserRequest();
	if ($$USER{title} eq 'root') {
		open (BONESLOG, ">> /home/oostendo/boneslog/bones.log");
		my $log = localtime(time)
		 ."\t$$USER{title}\t$$GNODE{title} ($$GNODE{type}{title})\n";
		print BONESLOG $log;
		close BONESLOG;
	}

}


#############################################################################
# End of package
#############################################################################

1;
