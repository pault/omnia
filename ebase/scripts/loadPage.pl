#!/usr/bin/perl -w

use strict;
use Everything;
use Everything::HTML;
use CGI;

my $cgiParams = { 
	test => 1
	};

#blow away the globals
Everything::HTML::clearGlobals();

# Initialize our connection to the database
Everything::initEverything('everything', 1);

my $vars = eval(getCode('set_htmlvars'));
if($vars ne "")
{
	%HTMLVARS = %{ eval (getCode('set_htmlvars')) };
}

# Set up the CGI to fake a web access request
$query = new CGI();
foreach my $param (keys %$cgiParams)
{
	$query->param($param, $$cgiParams{$param});
}

$USER = loginUser();

# Execute any operations that we may have
execOpCode();

# Fill out the THEME hash
getTheme();

# Do the work.
handleUserRequest();
