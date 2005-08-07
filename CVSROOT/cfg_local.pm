####################################################################
####################################################################
# This file contains local configuration for the CVSROOT perl
# scripts.  It is loaded by cfg.pm and overrides the default
# configuration in that file.
#
# It is advised that you test it with
#     'env CVSROOT=/path/to/cvsroot perl -cw cfg.pm'
# before you commit any changes.  The check is to cfg.pm which
# loads this file.
####################################################################
####################################################################

%TEMPLATE_HEADERS = (
	"Reviewed by"		=> '.*',
	"Submitted by"		=> '.*',
	"Obtained from"		=> '.*',
	"Approved by"		=> '.*',
);

$MAILCMD = "/usr/sbin/sendmail";
$MAILADDRS='everydevel-cvs@lists.sourceforge.net';
$MAX_DIFF_SIZE = 1024;

@LOG_FILE_MAP = (
	'generallog'	=> '.*'
);

1; # Perl requires all modules to return true.  Don't delete!!!!
#end
