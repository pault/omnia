#!/usr/bin/perl -w

use strict;

my @unknown;
my @modified;
my @added;
my $file;
my $output;
my $doit;
my $added = 0;

print "**** WARNING ****\n";
print "You are about to check in changes to cvs.\n";
print "CVSROOT = $ENV{CVSROOT}\n";

print "Do you wish to proceed [n]: ";

unless(getYes())
{
	print("Aborting checkin.\n");
	exit;
}

$output = `cvs update`;
push(@unknown, getUnknowns($output));
push(@modified, getModified($output));

if(@unknown > 0)
{
	print "CVS has detected files that you have locally, but are\n";
	print "not in the repository.\n";
	print "Do you wish to add these files? [n]: ";

	if(getYes())
	{
		while(($file = pop(@unknown)))
		{
			if(-d $file)
			{
				# Always do directories without asking.  We are looking
				# for new files within them.
				$doit = 1;
			}
			else
			{
				# This is a file, see if we want to add it.
				print "Add '$file'? [n]: ";
				$doit = getYes();
			}
			
			if($doit)
			{
				# If $file is a directory, and there is new stuff
				# inside it, it will return text indicating that.
				# Parse that apart and add any new unknows to our
				# list.  This will work recursively. 
				$file =~ s/\$/\\\$/g;
				
				$output = `cvs add "$file"`;
				push(@unknown, getUnknowns($output));

				push(@added, $file);  # keep track of what we added.
			}
		}
	}
}

if(@modified > 0)
{
	my $modified;
	
	print "\nFiles modified that will be committed:\n";
	foreach $modified (@modified)
	{
		print "$modified\n";
	}
}

if(@added > 0)
{
	my $add;
	
	print "\nFiles added that will be committed:\n";
	foreach $add (@added)
	{
		print "$add\n";
	}
}

if((@modified > 0) || (@added > 0))
{
	print("\n\nEnter comment for cvs commit (<enter> for nothing, ctrl-c to cancel):\n");
	chomp($output = <STDIN>);
	`cvs commit -m "$output"`;
}
else
{
	print "*** Nothing modified or added.  No commit performed\n";
}

exit;


#############################################################################
# Subroutines
#############################################################################
sub getUnknowns
{
	my ($output) = @_;
	my @files;
	my @lines;
	my $line;

	@lines = split "\n", $output;

	foreach $line (@lines)
	{
		if($line =~ /^\?/)
		{
			$line =~ s/^\? //;
			push(@files, $line);
		}
	}

	return @files;
}

sub getModified
{
	my ($output) = @_;
	my @files;
	my @lines;
	my $line;

	@lines = split "\n", $output;

	foreach $line (@lines)
	{
		if($line =~ /^\M/)
		{
			$line =~ s/^\M //;
			push(@files, $line);
		}
	}

	return @files;
}

sub getYes
{
	my $response;

	chomp($response = <STDIN>);
	$response =~ s/Y/y/g;

	return ($response eq "y");
}
