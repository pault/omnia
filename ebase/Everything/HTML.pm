package Everything::HTML;

############################################################
#
#	Everything::HTML.pm
#		A module for the HTML stuff in Everything.  This
#		takes care of CGI, cookies, and the basic HTML
#		front end.
#
############################################################

use strict;
use Everything;
require CGI;
use CGI::Carp qw(fatalsToBrowser);


sub BEGIN {
	use Exporter ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		%NODETYPES
		%HTMLVARS
		$query
		jsWindow
		popup_node
		createNodeLinks
		parseLinks
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
		embedCode
		displayPage
		gotoNode
		confirmUser
		urlDecode
		createPopupMenu
		addSettingsToPopupMenu
		addGroupToPopupMenu
		addHashToPopupMenu
		writePopupMenuHTML
		mod_perlInit);
}

use vars qw($query);
use vars qw(%HTMLVARS);
use vars qw($GNODE);
use vars qw($USER);
use vars qw($VARS);
use vars qw($NODELET);


#############################################################################
#needs to be fleshed out... but it's more or less functional
sub htmlFormatErr {
	my ($code, $err, $warn) = @_;


	$code =~ s/\&/\&amp\;/g;
	$code =~ s/\</\&lt\;/g;
	$code =~ s/\>/\&gt\;/g;
	$code =~ s/\"/\&quot\;/g;

	my @mycode = split /\n/, $code;
	while($err =~ /line (\d+)/sg) {
		$mycode[$1-1] = "<FONT color=cc0000><b>" . $mycode[$1-1] .
			"</b></font>";
	}

	my $str = "<B>$@ . $warn</B><BR>";

	my $count = 1;
	$str.= "<PRE>";
	foreach my $line (@mycode) {
		if ($count < @mycode) {$str.= $count++." :".$line . "\n";}
	}
	
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
sub popup_node {
	my ($name, $NODELIST, $SELECT) = @_;
	getRef $SELECT;

	my (@titlelist, %items);
	foreach my $N (@$NODELIST) {
		$N = selectNode $N, 'light';
		push @titlelist, $$N{title};
		$items{getId ($N)} = $$N{title};
	}

	$query->popup_menu($name, \@titlelist, ($SELECT and $$SELECT{title}),
		\%items);
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
	$str
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

sub getCode
{
	my ($funcname, $args) = @_;

	my $CODELIST = selectNodeByName ($funcname, $NODETYPES{htmlcode});
	return '"";' unless ($CODELIST);
	my $CODE = selectNode($$CODELIST[0]);
	
	my $str = "\@\_ = split (/\s\*,\s\*/, '$args');\n" if $args;
	
	$str.$$CODE{code};
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
	my $TYPE;
	my @pages;

	$TYPE = $NODE if (isNodetype($NODE) && $$NODE{extends_nodetype});
	$TYPE ||= $NODETYPES{$$NODE{type_nodetype}};

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
#		$TYPE - the nodetype to get display pages for
#		$displaytype - the type of display (usually 'display' or 'edit')
#
#	Returns
#		A node hashref to the page that can display nodes of this nodetype.
#
sub getPageForType
{
	my ($TYPE, $displaytype) = @_; 
	my %WHEREHASH;
	my $REF;
	my $PAGE;
	

	getRef $TYPE;

	$NODETYPES{htmlpage} or die "HTML PAGES NOT LOADED!";

	# Starting with the nodetype of the given node, We run up the
	# nodetype inheritance hierarchy looking for some nodetype that
	# does have a display page.
	do
	{
		# Clear the hash for a new search
		undef %WHEREHASH;
		
		%WHEREHASH = (pagetype_nodetype => $$TYPE{node_id}, 
				displaytype => $displaytype);

		$REF = selectNodeWhere(\%WHEREHASH, $NODETYPES{htmlpage});

		if(not defined $REF)
		{
			if($$TYPE{extends_nodetype})
			{
				$TYPE = $NODETYPES{$$TYPE{extends_nodetype}};
			}
			else
			{
				# No pages for the specified nodetype were found.
				# Use the default node display.
				$REF = selectNodeWhere (
						{pagetype_nodetype => getId ($NODETYPES{node}),
						displaytype => $displaytype}, 
						$NODETYPES{htmlpage});

				$REF or die "No default pages loaded.  " .  
					"Failed on page request for $WHEREHASH{pagetype_nodetype}" .
					" $WHEREHASH{displaytype}\n";
			}
		}
	} until($REF);

	$PAGE = getNodeById($$REF[0]);
	
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
	$displaytype ||= 'display';

	$TYPE = $NODETYPES{$$NODE{type_nodetype}};

	return getPageForType($TYPE, $displaytype);
}


#############################################################################
sub linkNode {
	my ($NODE, $title, $PARAMS) = @_;
	getRef $NODE;	
	
	#unless (ref $NODE) {
	#	$NODE = selectNode $NODE, 'light';
	#}
	
	if ($NODE == -1) {return "<a>$title</a>";}
	$title ||= $$NODE{title};
	$$PARAMS{node_id} = getId $NODE;
	my $tags = "";

	$$PARAMS{lastnode_id} = getId ($GNODE); 

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

	my $type = $query->param("type");
	my $select_group = selectNodeByName($node, $NODETYPES{$type});
	my $search_group;
	my $NODE;


	$type ||= "";

	if (not $select_group or @$select_group == 0)
	{ 
		# We did not find an exact match, so do a search thats a little
		# more fuzzy.
		$search_group = searchNodeName($node, $NODETYPES{$type}); 
		
		if($search_group && @$search_group > 0)
		{
			$NODE = selectNode $HTMLVARS{search_group};
			$$NODE{group} = $search_group;
		}
		else
		{
			$NODE = selectNode $HTMLVARS{not_found};	
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
		my $NODE = selectNode $HTMLVARS{duplicate_group};
		
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
	
#		$block =~ s/\[([\%\{\"].*?[\%\}\"])\]/embedCode($1, @_)/egs;
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
sub listCode {
	my ($code, $numbering) = @_;
	return unless($code); 

	$code =~ s/\&/\&amp\;/g;
	$code =~ s/\</\&lt\;/g;
	$code =~ s/\>/\&gt\;/g;
	$code =~ s/\"/\&quot\;/g;
	$code =~ s/\[/\&\#91\;/g;
	$code =~ s/\]/\&\#93\;/g;

	my @lines = split /\n/, $code;
	my $count = 0;
	foreach my $ln (@lines) {
		$ln = $count++ . ": $ln" if $numbering;
	}

	"<PRE>" . join ("\n", @lines) . "</PRE>";
}




#############################################################################
#this is a function that you should call on user data 
sub createNodeLinks {
	my ($text, $NODE) = @_;
	$NODE ||= $GNODE;
	$text =~ s/\[(\w.*?)\]/linkNodeTitle($1, getId($NODE))/;

	$text;
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
	my $html;
	getRef $NODELET;
	
	$html = genContainer($$NODELET{parent_container});

	# Make sure the nltext is up to date
	updateNodelet($NODELET);
	
	# now that we are guaranteed that nltext is up to date, sub it in.
	$html =~ s/CONTAINED_STUFF/$$NODELET{nltext}/s;

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
	my $currTime = `date +%s`;
	#this should be re-written to use internal perl functions
	#sometimes it fails

	getRef $NODELET;

	$interval = $$NODELET{updateinterval};
	$lastupdate = $$NODELET{lastupdate};
	
	# Return if we have generated it, and never want to update again (-1) 
	return if($interval == -1 && $lastupdate != 0);
	
	# If we are beyond the update interal, or this thing has never
	# been generated before, generate it.
	if((not $currTime or not $interval) or ($currTime > $lastupdate + $interval) || ($lastupdate == 0))
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
#
#	container - title of container
#	html - html to insert

sub containHtml {
	my ($container, $html) =@_;
	my ($TAINER) = getNodeWhere({title=>$container}, $NODETYPES{container});
	my $str = genContainer($TAINER);

	$str =~ s/CONTAINED_STUFF/$html/g;
	$str;
}


#############################################################################
sub displayPage		#this is the big function 
{
	my ($NODE, $user_id) = @_;
	getRef $NODE, $USER;
	die "NO NODE!" unless $NODE;
	$GNODE = $NODE;

	my $PAGE = getPage($NODE, $query->param('displaytype')); 
	my $page = $$PAGE{page};

	die "NO PAGE!" unless $page;

	if ($$PAGE{parent_container}) {
		my $container = genContainer($$PAGE{parent_container}); 
		$container =~ s/CONTAINED_STUFF/$page/s;
		$page = $container;
	}	
	
	#the order is:  
	# [% %]s -- full embedded perl
	# [{ }]s -- calls to the code database
	# [" "]s -- embedded code strings
	#
	# this is important to know when you are writing pages -- you 
	# always want to print user data through [" "] so that they
	# cannot embed arbitrary code...
	#
	# someday I'll come up with a better way to do that...
	#must filter out things that are in a te

	$page = parseCode $page;
	#$page =~ s/\[([\%\{\"].*?[\%\}\"])\]/embedCode($NODE, $USER, $VARS, $1)/egs;

	setVars $USER, $VARS;
	
	$query->print($page);
		#print the whole page
}


#############################################################################
#the function where we go when we actually know which $NODE we want to view
sub gotoNode
{
	my ($node_id, $user_id) = @_;

	my $NODE = {};
	unless (ref ($node_id) eq 'ARRAY') {
		$NODE = selectNode($node_id, 'force');
	}
	else {
		$NODE = selectNode($HTMLVARS{search_group});
		$$NODE{group} = $node_id;
	}

	unless ($NODE) { $NODE = selectNode($HTMLVARS{not_found}); }	
	
	unless (canReadNode($user_id, $NODE)) {
		$NODE = selectNode($HTMLVARS{permission_denied});
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

		foreach my $field (@updatefields) {
			if ($field =~ /$$NODE{type}{title}\_(\w*)$/) {
				$$NODE{$1} = $query->param($field);
				$updateflag = 1;
			}	
		}
		updateNode ($NODE, $user_id) if $updateflag; 
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
				$NODE = selectNode $HTMLVARS{node_locked};
				$query->param('displaytype', 'display');
			} 
		} else {
			$NODE = selectNode $HTMLVARS{permission_denied};
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

	my $USERLIST = selectNodeWhere ({title => $nick}, $NODETYPES{'user'});
	
	my $USER = selectNode ($$USERLIST[0]);	

	if (crypt ($$USER{passwd}, $$USER{title}) eq $crpasswd) {
		my $rows = $Everything::dbh->do("
			UPDATE user SET lasttime=now() WHERE
			user_id=$$USER{node_id}
			") or die;
		return selectNode($USER, 'force');
	} 
	return 0;
}


#############################################################################
sub parseLinks {
	my ($text, $NODE) = @_;

	$text =~ s/\[(.*?)\]/linkNodeTitle ($1, $NODE)/egs;
	$text;
}


#############################################################################
sub urlDecode {
	foreach my $arg (@_)
	{
		tr/+/ /;
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

		#print "$user, $passwd";
		
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
	elsif ($cookie = $query->cookie("userpass"))
	{
		$user_id = confirmUser (split (/\|/, urlDecode ($cookie)));
	}
	
	# If all else fails, use the guest_user
	$user_id ||= $HTMLVARS{guest_user};				

	# Get the user node
	$USER_HASH = getNodeById($user_id);	

	die "Unable to get user!" unless ($USER_HASH);

	# Assign the user vars to the global.
	$VARS = getVars($USER_HASH);
	
	# Store this user's cookie!
	$$USER_HASH{cookie} = $cookie;

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
sub printHeader
{
	if($ENV{SCRIPT_NAME})
	{
		print "HTTP/1.1 200 OK\n Server: Apache/1.3b3 mod_perl/1.08\n ";
		print $query->header(-type=>"text/html", -cookie=>$$USER{cookie});	
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
		
		nukeNode $node_id, $user_id;

		# This should now result in a "Not found" page
		gotoNode ($node_id, $user_id);

		return;
	}
	elsif ($nodename = $query->param('node'))
	{
		# Searching for a node my string title
		my $type  = $query->param('type');
	
		$nodename =~ s/^\s*|\s*$//g;
		$nodename =~ s/\s+/ /g;
		
		if ($query->param('op') ne 'new')
		{
			nodeName ($nodename, $user_id, $type); 
		}
		elsif ($user_id != $HTMLVARS{guest_user} and
			canCreateNode($user_id, $NODETYPES{$type}))
		{
			#guests can't create nodes -- otherwise
			#they are like normal users

			$node_id = insertNode($nodename,
				$NODETYPES{$query->param('type')}, $user_id);
			
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
	my ($db) = @_;


	#blow away the globals
	($GNODE, $USER, $VARS, $NODELET) = ("", "", "", "");

	$query = "";
	Everything::mod_perlInit $db;

	# Get the HTML variables for the system.  These include what
	# pages to show when a node is not found (404-ish), when the
	# user is not allowed to view/edit a node, etc.  These are stored
	# in the dbase to make changing these values easy.	
	%HTMLVARS = %{ eval (getCode('set_htmlvars')) };

	$query = getCGI();

	$USER = loginUser();

	# Print the standard HTML transfer header.  Without this, the browser
	# will not know how to display the page.
	printHeader();
		
	# Do the work.
	handleUserRequest();
}


#############################################################################
# End of package
#############################################################################

1;
