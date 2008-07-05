
=head1 Everything::HTML.pm

A module which handles html rendering.


=cut

package Everything::HTML;

use strict;
use Everything ':all';
use Everything::Mail qw/node2mail mail2node/;
use Everything::Auth;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use URI;

use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/htmlpage request theme node_locators link_node_sub current_node/);


# This is used for nodes to pass vars back-n-forth

sub get_requested_node { $_[0]->get_request->get_node }
sub get_node           { $_[0]->get_requested_node }
sub get_vars           { $_[0]->get_request->get_user_vars }
sub get_user           { $_[0]->get_request->get_user }
sub get_htmlvars       { $_[0]->get_request->get_system_vars }
sub get_query          { $_[0]->get_request->get_cgi }
sub get_nodebase       { $_[0]->get_request->get_nodebase }
sub DESTROY {} # because of AUTOLOAD

=cut


deprecate( $level )

For internal use only.

Warns about calling a deprecated function so we can identify and remove the
callers.

=cut

sub deprecate {
    my $level = shift || 1;
    my ( $package, $filename, $line, $sub ) = caller($level);
    $sub ||= 'main program';

    my $warning = "Deprecated function '$sub' called";
    $warning .= " from $filename" if defined $filename;
    $warning .= " line #$line"    if defined $line;

    Everything::logErrors($warning);
}

=cut

=head2 C<create_form_object>

A generic form object creation function.  Takes two arguments, a
nodebase object and a string represnting teh type of form object to be
created.  Returns the form object on success undef otherwise.

=cut

sub create_form_object {

    my ($nodebase, $objName ) = @_;
    my $module = "Everything::HTML::FormObject::$objName";
    ( my $modulepath = $module . '.pm' ) =~ s!::!/!g;

    # We eval so that if the requested nodetype doesn't exist, we don't die
    my $object = eval {
        require $modulepath;
        $module->new($nodebase);
    };

    Everything::logErrors($@) if $@;

    return $object;


}


=head2 C<newFormObject>

A little wrapper to make getting form object references easier.

=over 4

=item * $objName

The name of a form object (ie 'TextField').  Note!!!  This name must be of the
same capitalization as the actual .pm implementation of the desired form
object.

=back

Returns the form object ref if successful, undef otherwise.

=cut

sub newFormObject {
    my ($objName) = @_;
    return unless $objName;
    return create_form_object( $DB, $objName );

}

=cut
=cut

sub new_form_object {
    my $self      = shift;
    my $DB        = $self->get_nodebase;
    my ($objName) = @_;
    return unless $objName;

    return create_form_object ( $DB, $objName );
}

=head2 C<tagApprove>

Determines whether or not a tag (and its specified attributes) are approved or
not.  Returns the cleaned tag.  Used by htmlScreen

=over 4

=item * $close

either '/' or '' (nothing).  Determines if the tag is the opening or closing
tag.

=item * $tag

the name of the tag (ie "font")

=item * $attr

the attributes of the tag (ie "size=1 color=red")

=item * $APPROVED

a hash of approved tags, where the keys are the names of the tags and the
values are a comma delimited string of allowed attributes.  ie:

  { "font" =E<gt> "size,color" }

=back

Returns the tag with any unapproved attributes removed.  If the tag itself is
not approved, "" (nothing) will be returned.

=cut

sub tagApprove {
    my ( $close, $tag, $attr, $APPROVED ) = @_;

    $tag = uc($tag) if ( exists $$APPROVED{ uc($tag) } );
    $tag = lc($tag) if ( exists $$APPROVED{ lc($tag) } );

    if ( exists $$APPROVED{$tag} ) {
        my @aprattr = split ",", $$APPROVED{$tag};
        my $cleanattr = '';
        foreach (@aprattr) {
            if (
                ( $attr =~ /\b$_\b\='([\w\:\/\.\;\&\?\,\-]+?)'/ )
                or (
                    $attr =~ /\b$_\b\="([\w\:\/\.\;\&\?\,\-\s]+
?)"/
                )
                or (
                    $attr =~ /\b$_\b\="?'?([\w\:\/\.\;\&\?\,\-\
s\=\+\#]*)\b/
                )
              )
            {
                $cleanattr .= " " . $_ . '="' . $1 . '"';
            }
        }
        return "<" . $close . $tag . $cleanattr . ">";
    }
    else { return ""; }
}

=cut


=head2 C<htmlScreen>

screen out html tags from a chunk of text
returns the text, sans any tags that aren't "APPROVED"		

=over 4

=item * text

the text/html to filter

=item * APPROVED 

ref to hash where approved tags are keys.  Null means all HTML will be taken
out.

=back

Returns the text stripped of any HTML tags that are not approved.

=cut

sub htmlScreen {
    my ( $text, $APPROVED ) = @_;
    $APPROVED ||= {};

    if ( $text =~ /\<[^>]+$/ ) { $text .= ">"; }

    #this is required in case someone doesn't close a tag
    $text =~ s/\<\s*(\/?)(\w+)(.*?)\>/tagApprove($1,$2,$3, $APPROVED)/gse;
    $text;
}

=cut


=head2 C<encodeHTML>

Convert the HTML markup characters (E<gt>, E<lt>, ", etc...) into encoded
characters (&gt;, &lt;, &quot;, etc...).  This causes the HTML to be displayed
as raw text in the browser.  This is useful for debugging and displaying the
HTML.

=over 4

=item * $html

the HTML text that needs to be encoded.

=item * $adv

Advanced encoding.  Pass 1 if some non-HTML, but Everything-specific characters
should be encoded.

=back

Returns the encoded string

=cut

sub encodeHTML {
    my ( $html, $adv ) = @_;

    # Note that '&amp;' must be done first.  Otherwise, it would convert
    # the '&' of the other encodings.
    $html =~ s/\&/\&amp\;/g;
    $html =~ s/\</\&lt\;/g;
    $html =~ s/\>/\&gt\;/g;
    $html =~ s/\"/\&quot\;/g;

    if ($adv) {
        $html =~ s/\[/\&\#91\;/g;
        $html =~ s/\]/\&\#93\;/g;
    }

    return $html;
}

sub encode_html {
    my $self = shift;
    encodeHTML(@_);

}

=cut


=head2 C<decodeHTML>

This takes a string that contains encoded HTML (&gt;, &lt;, etc..) and decodes
them into their respective ascii characters (E<gt>, E<lt>, etc).

Also see encodeHTML().

=over 4

=item * $html

the string that contains the encoded HTML

=item * $adv

Advanced decoding.  Pass 1 if you would also like to decode non-HTML,
Everything-specific characters.

=back

Returns the decoded HTML

=cut

sub decodeHTML {
    my ( $html, $adv ) = @_;

    $html =~ s/\&lt\;/\</g;
    $html =~ s/\&gt\;/\>/g;
    $html =~ s/\&quot\;/\"/g;

    if ($adv) {
        $html =~ s/\&\#91\;/\[/g;
        $html =~ s/\&\#93\;/\]/g;
    }

    $html =~ s/\&amp\;/\&/g;
    return $html;
}

=cut


=head2 C<htmlFormatErr>

An error has occured and we need to print or log it.  This will do the
appropriate action based on who the user is.

=over 4

=item * $err

a list ref of error messages returned from the system

=item * $CONTEXT

the node in which this code is coming from.  This is optional, however you
should try to pass this in all cases since it will help a lot when trying to
find which node contains the offending code.

=back

Returns an html/text string that will be displayed to the browser.

=cut

sub htmlFormatErr {
    my ( $self, $err, $CONTEXT ) = @_;
    my $str;

    if ( $self->get_user->isGod() ) {
        $str = $self->htmlErrorGods( $err, $CONTEXT );
    }
    else {
        $str = $self->htmlErrorUsers( $err, $CONTEXT );
    }

    return $str;
}

=cut


=head2 C<htmlErrorUsers>

Format an error for the general user.  In this case we do not want them to see
the error or the perl code.  So we will log the error and give them a simple
one.

You can define a custom error text by creating an htmlcode node that formats a
string error.  The code is passed a single numeric value that can be used to
reference the error that is written to the log file.  However, be very careful
that your htmlcode for your custom message doesn't have an error, or you may
cause a user to get stuck in an infinite loop.  Since, an error in that code
would cause the system to call itself to handle the error.

=over 4

=item * $errors

a list ref of error messages returned from the system

=item * $CONTEXT

the node in which this code is coming from.  This is optional, however you
should try to pass this in all cases since it will help a lot when trying to
find which node contains the offending code.

=back

Returns an html/text string that will be displayed to the browser.

=cut

sub htmlErrorUsers {
    my ( $self, $errors, $CONTEXT ) = @_;
    my $USER = $self->get_user;
    my $query = $self->get_query;
    my $errorId = int( rand(9999999) );    # just generate a random error id.
    my $str;                               #= htmlError($errorId);

    # If the site does not have a piece of htmlcode to format this error
    # for the users, we will provide a default.
    if ( ( not defined $str ) || $str eq "" ) {
        $str = "Server Error (Error Id $errorId)!";
        $str = "<font color=\"#CC0000\"><b>$str</b></font>";

        $str .= "<p>An error has occured.  Please contact the site";
        $str .= " administrator with the Error Id.  Thank you.";
    }

    # Print the error to the log instead of the browser.  That way users
    # don't see all the messy perl code.
    my $error = "Server Error (#" . $errorId . ")\n";
    $error .= "User: ";
    $error .= "$$USER{title}\n" if ( ref $USER );
    $error .= "User agent: " . $query->user_agent() . "\n" if defined $query;

    $error .= "Node: $$CONTEXT{title} ($$CONTEXT{node_id})\n"
      if ( defined $CONTEXT );

    foreach my $err (@$errors) {
        $error .= "--- Start Error --------\n";
        $error .= "Code:\n$$err{code}\n";
        $error .= "Error:\n$$err{error}\n";
        $error .= "Warning:\n$$err{warning}\n";

        if ( defined $$err{context} ) {
            my $N = $$err{context};
            $error .= "From node: $$N{title} ($$N{node_id})\n";
        }
    }

    $error .= "-=-=- End Error -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
    Everything::printLog($error);

    $str;
}

=cut


=head2 C<htmlErrorGods>

Print an error for a god user.  This will dump the code, the call stack and any
other error information.  You probably don't want the average user of a site to
see this stuff.

=over 4

=item * $errors

a list ref of error messages returned from the system

=item * $CONTEXT

the node from which the error came (optional)

=back

Returns an html/text string that will be displayed to the browser.

=cut

sub htmlErrorGods {
    my ( $self, $errors, $CONTEXT ) = @_;
    my $str;
    my $VARS = $self->get_vars;
    foreach my $err (@$errors) {
        my $error = $$err{error} . $$err{warning};
        my $linenum;
        my $code = $$err{code};

        $code = encodeHTML($code);

        my @mycode = split /\n/, $code;
        while ( $error =~ /line (\d+)/sg ) {

            # If the error line is within the range of the offending code
            # snipit, make it red.  The line number may actually be from
            # a perl module that the evaled code is calling.  If thats the
            # case, we don't want some bogus number to add lines.
            if ( $1 < ( scalar @mycode ) ) {

                # This highlights the offending line in red.
                $mycode[ $1 - 1 ] =
                  "<FONT color=cc0000><b>" . $mycode[ $1 - 1 ] . "</b></font>";
            }
        }

        $str .= "<p><b>$error</b><br>\n";

        my $count = 1;
        $str .= "<PRE>";
        foreach my $line (@mycode) {
            $str .= sprintf( "%4d: %s\n", $count++, $line );
        }

        # Print the callstack to the browser too, so we can see where this
        # is coming from.
        if ( exists $$VARS{showCallStack} and $$VARS{showCallStack} ) {
            $str .= "\n\n<b>Call Stack</b>:\n";
            $str .= join( "\n", reverse( getCallStack() ) );
            $str .= "<b>End Call Stack</b>\n";
        }
        $str .= "</PRE>";
    }
    return $str;
}

=cut


=head2 C<urlGen>

This creates a URL to the current installation

=over 4

=item * $REF

a hashref of parameters and values used to create a query string

=item * $noquotes

an optional flag.  If true, it suppreses quotes around the URL.

=back

Returns a string containing the generated URL.

=cut

sub urlGen {
    my ( $REF, $noquotes ) = @_;

    my $new_query = CGI->new($REF);

    my $str = $new_query->url( -query => 1, -absolute => 1 );

    $str = '"' . $str . '"' unless $noquotes;

    return $str;


}

sub url_gen {

        my ( $self, $REF, $noquotes, $location ) = @_;

        my $url = URI->new( $location, 'http' );
        $url->query_form_newstyle($REF) if $REF && %$REF;
        my $url_string = $url->as_string;
        return $url_string if $noquotes;
        return '"' . $url_string . '"';

}

=cut
=cut


=head2 C<linkNode>

This creates a E<lt>a hrefE<gt> link to the specified node.

=over 4

=item * $NODE

the node to create a link to

=item * $title

the title of the link (E<lt>a href="..."E<gt>titleE<lt>/aE<gt>)

=item * $PARAMS

a hashref that contains any CGI parameters to add to the URL.  (ie { 'op'
=E<gt> 'logout' })

=item * $SCRIPTS

a hashref of stuff that goes on the E<lt>aE<gt> tag itself.  This can be other
parameters for the E<lt>aE<gt> tag or javascript like stuff.  ie

  { 'onMouseOver' =E<gt> 'showStatus("hey!")' }

=back

Returns an 'E<lt>a href="..."E<gt>titleE<lt>/aE<gt>' HTML link to the given
node.

=cut

sub linkNode {
    my ( $NODE, $title, $PARAMS, $SCRIPTS ) = @_;
    my $link;

    return "" unless defined($NODE);

    # We do this instead of calling getRef, because we only need the node
    # table data to create the link.
    $NODE = $DB->getNode( $NODE, 'light' ) unless ( ref $NODE );

    return "" unless ref $NODE;

    $title ||= $$NODE{title};

    my $tags = "";

    separate_params( $PARAMS, \$tags );

    my $scripts = handle_scripts($SCRIPTS);

    $$PARAMS{node_id} = $NODE->{node_id};

    $link = "<a href=" . urlGen($PARAMS) . $tags;
    $link .= " " . $scripts if ( $scripts ne "" );
    $link .= ">$title</a>";

    return $link;
}

sub link_node {
    my $self = shift;
    my ( $NODE, $title, $PARAMS, $SCRIPTS ) = @_;
    my $link;

    return "" unless defined($NODE);

    $NODE = $self->get_nodebase->getNode( $NODE, 'light' ) unless ( ref $NODE );

    return "" unless ref $NODE;

    my $linker = $self->get_link_node_sub;

    return $linker->($self, $NODE, $title, $PARAMS, $SCRIPTS ) if $linker;

    $title ||= $$NODE{title};

    my $tags = "";

    separate_params( $PARAMS, \$tags );

    my $scripts = handle_scripts($SCRIPTS);

    my $node_location = $self->node_location( $NODE );
 
    if ( ! $node_location ) {
	$$PARAMS{node_id} = $NODE->{node_id};
	$node_location = '/';
    }

    $link = "<a href=" . $self->url_gen($PARAMS, undef, $node_location) . $tags;
    $link .= " " . $scripts if ( $scripts ne "" );
    $link .= ">$title</a>";

    return $link;

}

sub node_location {
    my ( $self, $node ) = @_;
    my @subs = @{ $self->get_node_locators || [] };
    return unless @subs;
    foreach ( @subs ) {
	 my $location = $_->( $node );
	 return $location if $location;
    }
    return;
}

sub separate_params {
    my ( $PARAMS, $tags_ref ) = @_;
    foreach my $key ( keys %$PARAMS ) {
        next unless ( $key =~ /^-/ );
        my $pr = substr $key, 1;
        $$tags_ref .= " $pr=\"$$PARAMS{$key}\"";
        delete $$PARAMS{$key};
    }

}

sub handle_scripts {
    my ($SCRIPTS) = @_;
    return '' unless $SCRIPTS && %$SCRIPTS;
    my @scripts;
    foreach my $key ( keys %$SCRIPTS ) {
        push @scripts, $key . "=" . '"' . $$SCRIPTS{$key} . '"';
    }
    return '' unless @scripts;
    return join ' ', @scripts;

}

=cut


=head2 C<linkNodeTitle>

Given a node title, create an HTML link to that node.

This creates a link pointing a node with a specific title.  If there exists
more than one node in the system, the result of following the link will result
in a "duplicates found".  If you know the exact node you want to go to, you
should use linkNode() instead.

=over 4

=item * $nodename

the name of the node to go to.

=item * $lastnode

id of the node that you are currently on (used for building links)

=item * $title

the title of the link as seen from the browser.

=back

=cut

sub linkNodeTitle {
    my ( $nodename, $lastnode, $title ) = @_;
    my ( $name, $linktitle ) = split /\|/, $nodename;

    if ( $title && $linktitle ) {
        logErrors( "Node '$nodename' has both title and linktitle", '', '',
            '' );
    }

    $title ||= $linktitle || $name;
    $name =~ s/\s+/ /gs;

    my %params = ( node => $name );

    if ( ref $lastnode ) {
        $params{lastnode_id} = $lastnode->{node_id};
    }
    elsif ( $lastnode && $lastnode !~ /\D/ ) {
        $params{lastnode_id} = $lastnode;
    }

    my $str = '';
    ## xxxxxx
    ## Following must be factored out with code from linkNode
    $str .= '<a href=' . urlGen( \%params ) . ">$title</a>";

    return $str;
}

sub link_node_title {
    my $self = shift;
    my ( $nodename, $lastnode, $title ) = @_;
    my ( $name, $linktitle ) = split /\|/, $nodename;

    if ( $title && $linktitle ) {
        logErrors( "Node '$nodename' has both title and linktitle", '', '',
            '' );
    }

    $title ||= $linktitle || $name;
    $name =~ s/\s+/ /gs;

    my %params = ( node => $name );

    if ( ref $lastnode ) {
        $params{lastnode_id} = $lastnode->{node_id};
    }
    elsif ( $lastnode && $lastnode !~ /\D/ ) {
        $params{lastnode_id} = $lastnode;
    }

    my $str = '';
    ## xxxxxx
    ## Following must be factored out with code from linkNode
    $str .= '<a href=' . $self->url_gen( \%params ) . ">$title</a>";

    return $str;
}

=cut


=head2 C<evalXTrapErrors>

This is a wrapper for the standard eval.  This way we can trap eval errors and
warnings and do something appropriate with them.  The difference between this
and evalX is that this function assumes that you want to report all eval errors
right now.  If you wish to do multiple evals, then report all the errors, call
evalX for each code and grab the errors yourself.

=over 4

=item * $code

the code to be evaled

=item * $CURRENTNODE

the context in which this code is being evaled.  For example, if this code is
coming from a nodelet, CURRENTNODE would be the nodelet.  This helps if we
encounter an error.  That way we know which node the code is coming from. If
you do not pass $CURRENTNODE, you *must* pass an undef in its place

=item * @_

the remaining items in @_ will be in context for the evaled code.

=back

Returns the result of the evaled code.  If there were any errors, the return
string will be the error nicely HTML formatted for easy display.

=cut

sub evalXTrapErrors {
    my ( $code, $CURRENTNODE ) = @_;

    # if there are any logged errors when we get here, they have nothing
    # to do with this.  So, push them to the backside error log for them to
    # get displayed later.
    flushErrorsToBackside();

    my $str = evalX(@_);

    my $errors = getFrontsideErrors();

    if ( int(@$errors) > 0 ) {
        $str .= htmlFormatErr( $errors, $CURRENTNODE );
    }

    clearFrontside();

    return $str;
}

=cut


=head2 C<AUTOLOAD>

This is to allow htmlcode to be called just like normal functions If an
htmlcode of the given name does not exist, this will throw an error.

Returns whatever the htmlcode returns

=cut

sub AUTOLOAD {

    my $self = shift;

    my $HTMLVARS = $self->get_htmlvars;
    # @_ contains the parameters for the htmlcode so we don't need to
    # extract them.
    my $subname = $Everything::HTML::AUTOLOAD;

    $subname =~ s/.*:://;

    my $CODE = $self->get_nodebase->getNode( $subname, 'htmlcode' );
    my $user = $self->get_user;

    $user ||= -1;

    # The reason we "die" here rather than just logging an error and
    # returning is to simulate the fact that the function does not exist.
    # In normal perl, if you try to call a function that does not exist,
    # you get a fatal runtime error.  If this is being called inside
    # another eval, this will cause the eval to get an error which it
    # can then handle.
    die("No function or htmlcode named '$subname' exists.") unless ($CODE);

    # We can only execute this if the logged in user has execute permissions.
    return undef unless ( $CODE->hasAccess( $user, 'x' ) );

    return $CODE->run(
        { no_cache => $$HTMLVARS{noCompile}, args => \@_, ehtml => $self } );

}

=cut


C<htmlcode>

THIS IS A DEPRECATED FUNCTION!  DO NOT USE!  This is here to maintain some
compatibility with some older code.  The AUTOLOAD method has replaced this for
a more direct implementation.  This basically allows the calling of htmlcode
with dynamic parameters

=cut

sub htmlcode {
    my ( $self, $function, $args ) = @_;
    my $code;
    my @args;

    if ( defined($args) && $args ne "" ) {
        @args = split( /\s*,\s*/, $args );
    }

    $code = "$function(\@_);";
    return $self->$function(@args);
}

=cut


=head2 C<do_args>

This is a supporting function for compileCache().  It turns a comma-delimited
list of arguments into an array, performing variable interpolation on them.
It's probably not necessary once things move over to the new AUTOLOAD htmlcode
scheme.

=over 4

=item * $args

a comma-delimited list of arguments

=back

Returns an array of manipulated arguments.

=cut

sub do_args {
    my $args = shift;

    my @args = split( /\s*,\s*/, $args ) or ();
    foreach my $arg (@args) {
        unless ( $arg =~ /^\$/ ) {
            $arg = "'" . $arg . "'";
        }
    }

    return @args;
}

=cut



=head2 C<execute_coderef>

This, as the name implies executes a code ref.


=cut 

sub execute_coderef {

    my ( $code_ref, $field, $CURRENTNODE, $args ) = @_;
    my $warn;

    local $SIG{__WARN__} = sub {
        $warn .= $_[0] unless $_[0] =~ /^Use of uninitialized value/;
    };

    Everything::flushErrorsToBackside();

    my ($ehtml) = @$args; #E::H object should be first one on array
    $ehtml->set_current_node( $CURRENTNODE ) if $ehtml;
    my $result = eval { $code_ref->( @$args ) } || '';

    local $SIG{__WARN__} = sub { };

    Everything::logErrors( $warn, $@, $$CURRENTNODE{$field}, $CURRENTNODE )
      if $warn or $@;

    my $errors = Everything::getFrontsideErrors();

    if ( int(@$errors) > 0 ) {
        $result .= $ehtml->htmlFormatErr( $errors, $CURRENTNODE );
    }
    Everything::clearFrontside();

    return $result;

}

=head2 C<executeCachedCode>

This is a supporting function for Compile-O-Cache.  It attempts to execute a
compiled subroutine.  It does support arguments, via the third parameter.  This
exists to make it easier for nodes with embedded code that don't go through the
new parseCode.

Note that it doesn't check if $HTMLVARS{noCompile} is set, or if the user is in
a workspace.  If this is important to you, check them!

=over 4

=item * $field

the name of the field of the node that contains embedded code

=item * $CURRENTNODE

the node object to check for compiled code

=item * $args

an optional array reference of arguments for the subroutine

=back

Returns the return value of the compiled code on success, undef on failure.
Note that if the compiled code returns undef, this function returns an empty
string instead.  This is the expected behavior of htmlcode and other page
components.

=cut

sub executeCachedCode {
    my ( $field, $CURRENTNODE, $args ) = @_;
    $args ||= [];

    my $code_ref;

    if ( $code_ref = $CURRENTNODE->{"_cached_$field"} ) {
        if ( ref($code_ref) eq 'CODE' and defined &$code_ref ) {
            execute_coderef( $code_ref, $field, $CURRENTNODE, $args );
        }
    }
}

=cut


=head2 C<createAnonSub>

For creating compiled code references, we need to create a sub ref and
establish a consistent context (exactly the same as evalX however, symbols must
be rendered at runtime.

=over 4

=item * $code

The code to be compiled.

=back

=cut

sub createAnonSub {
    my ($code) = @_;

    "sub {
                my \$this = shift;
		$code 
	}\n";
}

=cut


=head2 C<evalX>

This function is a wrapper for the normal eval so that we can trap errors and
log them.  This is intended to be called only from within this package
(HTML.pm) as all the globals to this package will be accessable to any code
that gets evaled.

However, this does not mean that it can't be called from other packages.  Just
be aware that HTML.pm globals will be in scope.

Note all variables in scope when the eval() is called should be namespaced with
$EVALX_ -- avoiding  "accidents" involving the same variable names in the
evalled code.

=over 4

=item * $EVALX_CODE

the string of code that is to be evaled.

=item * $CURRENTNODE

the node in which the code is coming from.  If you are unable to pass this (you
don't know it or are evaling code that is not associated with a node), you must
pass undef in its place as the rest of @_ are the parameters that will be in
scope when the actual eval is done.

=back

Returns whatever the code returns.

=cut

sub evalX {
    my $EVALX_CODE  = shift @_;
    my $CURRENTNODE = shift @_;
    my $EVALX_WARN;

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
    logErrors( $EVALX_WARN, $@, $EVALX_CODE, $CURRENTNODE ) if $@;

    return $result;
}

=cut

=head2 C<make_coderef>

Takes some text. Returns a code ref.

=cut

sub make_coderef {
    my ( $code, $NODE ) = @_;
    return evalX $code, $NODE;

}

=head2 C<compileCache>

Common compilation and caching and initial calling of htmlcode and
nodemethod functions.  Hopefully it keeps common code in one spot.  For
internal use only!

=over 4

=item * $code

the text to eval() into an anonymous subroutine

=item * $NODE

the node object from which the code came

=item * $field

the field of the node that holds the code for that nodetype

=item * $args

a reference to a list of arguments to pass

=back

Returns a string containing results of the code or a blank string.  Undef if
the compilation fails -- in case we need to default to old behavior.

=cut

sub compileCache {
    my ( $code, $NODE, $field, $args ) = @_;

    my $code_ref = make_coderef( $code, $NODE );

    return unless $code_ref;

    $NODE->{DB}->{cache}->cacheMethod( $NODE, $field, $code_ref );
    return executeCachedCode( $field, $NODE, $args );
}


=cut


=head2 C<htmlsnippet>

allow for easy use of htmlsnippet functions in embedded Perl
[E<lt>BacksideErrorsE<gt>] would become: htmlsnippet('BacksideErrors');

Returns the HTML from the snippet

=cut

sub htmlsnippet {
    my ( $self, $snippet, @args ) = @_;
    my $USER = $self->get_user;
    my $node = $self->get_nodebase->getNode( $snippet, 'htmlsnippet' );
    my $html = '';

    # User must have execute permissions for this to be embedded.
    if ( ( defined $node ) && $node->hasAccess( $USER, "x" ) ) {
        $html = $node->run( { field => 'code', ehtml => $self, args => \@args } );
    }
    return $html;
}

=cut



=head2 C<listCode>

To list code so that it will not be parsed by Everything or the browser

=over 4

=item * $code

the block of code to display

=item * $numbering

set to true if linenumbers are desired

=back

=cut

sub listCode {
    my ( $code, $numbering ) = @_;
    return unless ($code);

    $code = encodeHTML( $code, 1 );

    my @lines = split /\n/, $code;
    my $count = 1;

    if ($numbering) {
        foreach my $ln (@lines) {
            $ln = sprintf( "%4d: %s", $count++, $ln );
        }
    }

    my $text = "<pre>" . join( "\n", @lines ) . "</pre>";
    my $TYPE = $DB->getType("htmlsnippet");
    $text =~ s/(&#91;\&lt;)(.*?)(\&gt;&#93;)/$1 . linkCode($2, $TYPE) . $3/egs;

    $TYPE = $DB->getType("htmlcode");
    $text =~ s/(&#91;\{)(.*?)(\}&#93;)/$1 . linkCode($2, $TYPE) . $3/egs;

    return $text;
}

sub list_code {
    my $self = shift;
    my $DB   = $self->get_nodebase;
    my ( $code, $numbering ) = @_;
    return unless ($code);

    $code = encodeHTML( $code, 1 );

    my @lines = split /\n/, $code;
    my $count = 1;

    if ($numbering) {
        foreach my $ln (@lines) {
            $ln = sprintf( "%4d: %s", $count++, $ln );
        }
    }

#    my $text = "<pre>" . join( "\n", @lines ) . "</pre>";
    my $text = join( "<br />\n", @lines );
    my $TYPE = $DB->getType("htmlsnippet");
    $text =~
      s/(&#91;\&lt;)(.*?)(\&gt;&#93;)/$1 . $self->link_code($2, $TYPE) . $3/egs;

    $TYPE = $DB->getType("htmlcode");
    $text =~
      s/(&#91;\{)(.*?)(\}&#93;)/$1 . $self->link_code($2, $TYPE) . $3/egs;

    return $text;
}

=cut


=head2 C<linkCode>

Used in listCode() to create links to the embedded htmlcode and htmlsnippets.
Just a usability thing.  This function should not be used by anybody else.
This is considered a "private" function.

=over 4

=item * $func

the name of the htmlcode/htmlsnippet.  Basically, this is the string between
the delimiting brackets.

=item * $NODE

the nodetype of the destination link (optional ?)

=back

Returns a HTML link to the appropriate node, or the function name.

=cut

sub linkCode {
    my ( $func, $TYPE ) = @_;
    my $name;

    # First we need to figger out the name of the htmlsnippet or htmlcode.
    # If this is an htmlcode, it may have parameters.  We need to extract
    # the name.
    ( $name, undef ) = split( /:/, $func, 2 );

    my $NODE = $DB->getNode( $name, $TYPE );

    return linkNode( $NODE, $func ) if ($NODE);
    return $func;
}

sub link_code {
    my $self = shift;

    my ( $func, $TYPE ) = @_;
    my $name;

    # First we need to figger out the name of the htmlsnippet or htmlcode.
    # If this is an htmlcode, it may have parameters.  We need to extract
    # the name.
    ( $name, undef ) = split( /:/, $func, 2 );

    my $NODE = $self->get_nodebase->getNode( $name, $TYPE );

    return $self->link_node( $NODE, $func ) if ($NODE);
    return $func;
}

=cut


=head2 C<quote>

Not sure.  It seems that nothing uses this.  Nate?

=over 4

=item * $text

the text to encode

=back

=cut

sub quote {
    my ($text) = @_;

    $text =~ s/([\W])/sprintf("&#%03u", ord $1)/egs;
    $text;
}


=cut


=head2 C<updateNodelet>

Nodelets store their code in the nlcode (nodelet code) field.  This code is not
eval-ed every time the nodelet is displayed.  Call this function every time you
display a nodelet.  This will eval the code if the specified interval has
passed.

The updateinterval field dictates how often we eval the nlcode.  If it is -1,
we eval the code the first time and never do it again.

=over 4

=item * $NODELET

the nodelet to update

=back

=cut

sub updateNodelet {
    my ( $self, $NODELET ) = @_;
    my $interval;
    my $lastupdate;
    my $currTime = time;

    $interval = $$NODELET{updateinterval} || 0;
    $lastupdate = $$NODELET{lastupdate};

    # Return if we have generated it, and never want to update again (-1)
    return if ( $interval == -1 && $lastupdate != 0 );

    # If we are beyond the update interval, or this thing has never
    # been generated before, generate it.
    if (   ( not $currTime or not $interval )
        or ( $currTime > $lastupdate + $interval ) || ( $lastupdate == 0 ) )
    {
        $$NODELET{nltext} = $NODELET->run( { ehtml => $self } );
        $$NODELET{lastupdate} = $currTime;

        if ( not $NODELET->{DB}->{workspace} ) {

# Only update if we are not in a workspace, else we enter nodelet info in the WS
            $NODELET->update(-1) unless $interval == 0;
        }

        #if interval is zero then it should only be updated in cache
    }

    "";    # don't return anything
}




=head2 C<formatGodsBacksideErrors>

This formats any errors that we may have in our "cache" so that gods can see
them and correct them if necessary.

Returns a nicely formatted HTML table suitable for display somewhere, or a
blank string if there aren't any errors.

=cut

sub formatGodsBacksideErrors {
    my $self = shift;
    Everything::flushErrorsToBackside();

    my $errors = Everything::getBacksideErrors();

    return "" unless ( @$errors > 0 );

    my $str = "<table border=1>\n";
    $str .= "<tr><td bgcolor='black'><font color='red'>Backside Errors!"
      . "</font></td></tr>\n";

    foreach my $error (@$errors) {
        $str .= "<tr><td bgcolor='yellow'>";
        $str .= "<font color='black'>Warning: $$error{warning}</font>";
        $str .= "</td></tr>\n";

        $str .= "<tr><td bgcolor='#ff3333'>";
        $str .= "<font color='black'>Error: $$error{error}</font></td></tr>\n";
        $str .= "<tr><td>From: " . $self->link_node( $$error{context} ) . "</td></tr>\n"
          if ( $$error{context} );
        $str .= "<tr><td><pre>$$error{code}</pre></td></tr>\n";
    }

    $str .= "</table>\n";

    return $str;
}

=cut


=head2 C<printBacksideToLogFile>

This formats any errors that we may have in our "cache" so that they'll appear
nicely in the log.  Normal users can't see them.

Returns nothing of value.

=cut

sub printBacksideToLogFile {
    my $self = shift;
    Everything::flushErrorsToBackside();

    my $errors = Everything::getBacksideErrors();
    my $str;

    return "" unless ( @$errors > 0 );

    $str = "\n>>> Backside Errors!\n";
    foreach my $error (@$errors) {
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

=cut


=head2 C<parseLinks>

This finds any [...] blocks in the text and creates a link to the node named in
the brackets.

NOTE - we should add some setting to only allow links to certain types of
nodes.  Obviously, if a user puts [node] in their text, you don't want it to
link to the "node" nodetype.

=over 4

=item * $text

the text in which to search for [...] links

=item * $NODE

the node that contains this link.  Used for "lastnode".

=back

Returns the text with the [...] replaced with the appropriate links.

=cut

sub parseLinks {
    my ( $text, $NODE ) = @_;

    $text =~ s/\[(.*?)\]/linkNodeTitle ($1, $NODE)/egs;
    return $text;
}

=cut


=head2 C<cleanNodeName>

We limit names of nodes so that they cannot contain certain characters.  This
is so users can't play games with the names of their nodes.  For example, we
don't want "hello there" and "hello      there" to be different nodes.

=over 4

=item * $nodename

the raw name that the user has given

=back

Returns the name after we have cleaned it up a bit.

=cut

sub cleanNodeName {
    my ($nodename) = @_;

    $nodename =~ tr/[]|<>//d;
    $nodename =~ s/^\s*|\s*$//g;
    $nodename =~ s/\s+/ /g;
    $nodename = "" if $nodename =~ /^\W$/;

    #$nodename = substr ($nodename, 0, 80);

    return $nodename;
}


#############################################################################
sub opNuke {
    my $request  = shift;
    my $query    = $request->get_cgi;
    my $USER     = $request->get_user;
    my %HTMLVARS = %{ $request->get_system_vars };
    my $NODE     = $request->get_nodebase->getNode( $query->param("node_id") );

    $NODE->nuke($USER) if ($NODE);

    if ( $$NODE{node_id} == 0 ) {
        $query->param( 'node_id', $HTMLVARS{nodedeleted_node} );
        $request->set_message( $NODE );
    }
}

#############################################################################
sub opLogin {
    my $request = shift;
    my $query   = $request->get_cgi;
    my $AUTH    = $request->get_authorisation;
    my ( $USER, $VARS ) =
      $AUTH->loginUser( $query->param('user'), $query->param('passwd') );
    $request->set_user($USER);
    $request->set_user_vars($VARS);
}

#############################################################################
sub opLogout {
    my $request = shift;
    my $AUTH    = $request->get_authorisation;
    my ( $USER, $VARS ) = $AUTH->logoutUser();
    $request->set_user($USER);
    $request->set_user_vars($VARS);
}

#############################################################################
sub opNew {
    my $request  = shift;
    my $query    = $request->get_cgi;
    my $USER     = $request->get_user;
    my %HTMLVARS = %{ $request->get_system_vars };
    my $nodebase = $request->get_nodebase;

    my $node_id  = 0;
    my $user_id  = $$USER{node_id};
    my $type     = $query->param('type');
    my $TYPE     = $nodebase->getType($type);
    my $nodename = cleanNodeName( $query->param('node') );

    # Depending on whether the TYPE allows for duplicate names or not,
    # we need to create them with different create ops.
    my $create;
    $create = "create" if ( $$TYPE{restrictdupes} );
    $create ||= "create force";

    my $NEWNODE = $nodebase->getNode( $nodename, $TYPE, $create );
    $NEWNODE->insert($USER);

    $query->param( "node_id", $$NEWNODE{node_id} );
    $query->param( "node",    "" );

    if ( $NEWNODE->getId() < 1 ) {
        $request->set_message("You do not have permission to create "
          . "a node of type '$$NEWNODE{type}{title}'.");
	my $node = $nodebase->get_node(  $HTMLVARS{permissionDenied_node} );
	$request->set_node( $node );
    }
}

#############################################################################
sub opUnlock {
    my $request = shift;
    my $query   = $request->get_cgi;
    my $USER    = $request->get_user;

    my $LOCKEDNODE = $request->get_nodebase->getNode( $query->param('node_id') );
    $LOCKEDNODE->unlock($USER);
}

#############################################################################
sub opLock {
    my $request = shift;
    my $query   = $request->get_cgi;
    my $USER    = $request->get_user;

    my $LOCKEDNODE = $request->get_nodebase->getNode( $query->param('node_id') );
    $LOCKEDNODE->lock($USER);
}

=cut


=head2 C<opUpdate>

This is the operation that handles the automated upates to the node data in the
Everything system.  This looks for CGI parameters of the form
'formbind_FormObjectName_FormItemName', where 'FormObjectName', is the name of
the FormObject (nodetype) that generated the HTML for this, and 'FormItemName'
is the name of the HTML form item (ie E<lt>input name='FormItemName'...E<gt>).

If it finds any parameters that matches that pattern, it constructs a node of
that form object type (ie textfield, checkbox, etc) and passes the name of the
form object to it.  This allows the object to reconstruct itself based on the
fact that it knows what it generated.  The object can then determine what node
and field it is bound to, and the form object handles the update of the node.

If any of the fields fail the verification, the system will go to the node
specified by the node_id parameter (in most cases, this should be back to the
page that contained the form that was doing the update).

If all of the fields that need to be updated verify that the user has access to
update and that the data entered by the user is valid, then we proceed to
update the fields of the node(s).  None of the nodes are actually updated until
all fields have been updated.  This is to allow us to make 1 update() call per
node rather than calling update once per field update.

Once all of the nodes have been updated, this will look for two more optional
parameters: 'opupdate_redirect', and 'opupdate_displaytype'.  If
'opupdate_redirect' is specified, it should contain the numeric node id of the
node to go to.  opupdate_display type should contain the type of display for
that node.  For example, this way you could update a node, can automatically
redirect to another node's edit page.

=cut

sub opUpdate {
    my $request  = shift;
    my $query    = $request->get_cgi;
    my $USER     = $request->get_user;
    my %HTMLVARS = %{ $request->get_system_vars };
    my $nodebase = $request->get_nodebase;

    my @params = $query->param();
    my %UPDATENODES;
    my %UPDATEOBJECT;
    my %verify_failed = ();
    my $CGIVERIFY = 1;    # Assume that we succeed until we fail
    my @formbind;
    my @sort;

    my $preprocess  = $query->param('opupdate_preprocess');
    my $postprocess = $query->param('opupdate_postprocess');

    foreach my $param (@params) {
        push @formbind, $param if ( $param =~ /^formbind_(.+?)_(.+)$/ );
    }

    # Nothing to update
    return 1 if ( int(@formbind) == 0 );

    # We want to execute them in the order of the first two digits.
    # This way, form objects that do deletion stuff can go last or
    # objects that need to do some kind of setup can go first
    @sort = sort { $query->param($a) cmp $query->param($b) } @formbind;

    if ($preprocess) {

        # preprocess is a function call because the ehtml object does
        # not yet exist
	my $preproc = $nodebase->getNode( $preprocess, 'opcode');
	$preproc->run( { args => [ $request ] } );
    }

    # First, we need to verify that all fields in this update are
    # what we expect.
    foreach my $param (@sort) {
        $param =~ /formbind_(.+?)_(.+)$/;
        my $objectType = $1;
        my $objectName = $2;
        my $formObject = create_form_object($nodebase, $objectType);

        next unless ($formObject);

        my $verify = $formObject->cgiVerify( $query, $objectName, $USER );
        if ( $$verify{failed} ) {
            $verify_failed{$objectName} = $$verify{failed};

            $CGIVERIFY = 0;
        }
        elsif ( $$verify{node} ) {
            $UPDATEOBJECT{$param} = $$verify{node};
            $UPDATENODES{ $$verify{node} } ||= $nodebase->getNode( $$verify{node} );
        }
    }

    # If anything failed a verify, abort the update
    unless ($CGIVERIFY) {
	$request->set_message( \%verify_failed );
	return;
    }

    # Ok, all form objects that were bound to something verified that they
    # can be updated.  So, lets do it!  This just modifies the hash objects
    # as needed.  We wait until all updates are finished before actually
    # committing the changes to the database via update().  This way we
    # avoid doing an update() for each change.
    my $god = $USER->isGod();
    foreach my $param (@sort) {
        $param =~ /formbind_(.*?)_(.*)$/;
        my $objectType = $1;
        my $objectName = $2;
        my $formObject = create_form_object($nodebase, $objectType);

        next unless ($formObject);

        if ( exists $UPDATEOBJECT{$param} ) {
            $formObject->cgiUpdate( $query, $objectName,
                $UPDATENODES{ $UPDATEOBJECT{$param} }, $god );
        }
    }

    # Now that we have all of the nodes updated as needed, we can commit
    # them to the database.
    foreach my $node ( keys %UPDATENODES ) {

        # Log a revision (for undo/redo) on each of the updated nodes.
        $UPDATENODES{$node}->logRevision($USER);
        $UPDATENODES{$node}->update($USER);

        # This is the case where the user is modifying their own user
        # node.  If we want the user node to take effect in one page
        # load, we need to set it here.
        $USER = $UPDATENODES{$node}
          if ( $$USER{node_id} == $UPDATENODES{$node}{node_id} );
    }

    # Lastly, we need to determine if we have any kind of redirection
    # upon succeeding with the update.
    my $goto_node        = $query->param('opupdate_redirect');
    my $goto_displaytype = $query->param('opupdate_displaytype');

    $query->param( 'node_id',     $goto_node )        if ($goto_node);
    $query->param( 'displaytype', $goto_displaytype ) if ($goto_displaytype);

    if ($postprocess) {
        # preprocess is a function call because the ehtml object does
        # not yet exist
	my $postproc = $nodebase->getNode( $preprocess, 'opcode');
	$postproc->run( { args => [ $request ] } );

    }

    return 1;
}

# XXXXXXXXXX: temporary and until URI.pm is fixed.

sub URI::_query::query_form_newstyle {
    my $self = shift;
    my $old = $self->query;
    if (@_) {
        # Try to set query string
        my @new = @_;
        if (@new == 1) {
            my $n = $new[0];
            if (ref($n) eq "ARRAY") {
                @new = @$n;
            }
            elsif (ref($n) eq "HASH") {
                @new = %$n;
            }
        }
        my @query;
        while (my($key,$vals) = splice(@new, 0, 2)) {
            $key = '' unless defined $key;
            $key =~ s/([;\/?:@&=+,\$\[\]%])/$URI::Escape::escapes{$1}/g;
            $key =~ s/ /+/g;
            $vals = [ref($vals) eq "ARRAY" ? @$vals : $vals];
            for my $val (@$vals) {
                $val = '' unless defined $val;
                $val =~ s/([;\/?:@&=+,\$\[\]%])/$URI::Escape::escapes{$1}/g;
                $val =~ s/ /+/g;
                push(@query, "$key=$val");
            }
        }
        $self->query(@query ? join(';', @query) : undef);
    }
    return if !defined($old) || !length($old) || !defined(wantarray);
    return unless $old =~ /=/; # not a form
    map { s/\+/ /g; uri_unescape($_) }
         map { /=/ ? split(/=/, $_, 2) : ($_ => '')} split(/;/, $old);
}



1;
