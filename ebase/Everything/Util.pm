package Everything::Util;

#############################################################################
#	Everything perl module.  
#	Copyright 2000 - 2002 Everything Development Company
#	http://www.everydevel.com/
#
#	Format: tabs = 4 spaces
#
#############################################################################

use strict;

sub BEGIN
{
	use Exporter ();
	use vars	   qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		escape
		unescape
        );
}

use URI::Escape ();

#############################################################################
#	Sub
#		escape
#
#	Purpose
#		This encodes characters that may interfere with HTML/perl/sql
#		into a hex number preceeded by a '%'.  This is the standard HTML
#		thing to do when uncoding URLs.
#
#	Parameters
#		$esc - the string to encode.
#
#	Returns
#		Then escaped string
#
*escape		= *URI::Escape::uri_escape;


#############################################################################
#	Sub
#		unescape
#
#	Purpose
#		Convert the escaped characters back to normal ascii.  See escape().
#
#	Parameters
#		An array of strings to convert
#
#	Returns
#		The first item in the array.  Basically good for doing:
#			$url = unescape($url);
#
*unescape	= *URI::Escape::uri_unescape;


#############################################################################
# end of package
#############################################################################

1;
