package Everything::Util;

#############################################################################
#	Everything perl module.  
#	Copyright 2000 Everything Development
#	http://www.everydevel.com
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
sub escape
{
	my ($esc) = @_;

	$esc =~ s/(\W)/sprintf("%%%02x",ord($1))/ge;
	
	return $esc;
}


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
sub unescape
{
	foreach my $arg (@_)
	{
		tr/+/ /;
		$arg =~ s/\%(..)/chr(hex($1))/ge;
	}
	
	return $_[0];
}


#############################################################################
# end of package
#############################################################################

1;
