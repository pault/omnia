#!/usr/bin/perl -w

use strict;
use Test::More tests => 31;
use Test::MockObject;

my $package = "Everything::MAIL";

################################################################
#
#	t/email.t 
#
#		Test Everything::MAIL
#
#


#Load in the blib paths
BEGIN
{
        chdir 't' if -d 't';
        use lib '../blib/lib', 'lib', '..';
}


# We'll need a few MockObjects here

my $mock = Test::MockObject->new();
my $MS = Test::MockObject->new();
my $SETTINGS = Test::MockObject->new();


# A few different variables to hold parameters being passed in and out

my ($le_wrn,$le_err,$ms_isclosed, $ms_params, $ms_gotsettings, $ms_addr, $ms_subject, $ms_body);
my (@WARNINGS, @ERRORS, @RECIPIENTS);


# For now, we are going to start off so that a call
# to getNode("mail settings", "setting") will fail

$mock->set_always("SETTINGS", undef);

# Begin the faking process with Everything.pm

$mock->fake_module( "Everything", 

getNode => 

    sub { 
		my ($nparam, $tparam) = @_;

		return undef unless $nparam;
		
		if($nparam eq "mail settings" and $tparam eq "setting")
		{
			$ms_gotsettings = 1;
			return $mock->SETTINGS;
		}

		my $results = 
		{
			1 => undef,
			2 => {title => "", doctext => "test body" }, 
			3 => {title => "   ", doctext => "test body" },
			4 => {title => "test title", doctext => "" },
			5 => {title => "test title", doctext => "  " },
			6 => {title => "test title", doctext => "test body"},
		};
		
		return $results->{$nparam};
	},

logErrors =>

      sub { 
		($le_wrn,$le_err) = @_;
		push @WARNINGS, $le_wrn if $le_wrn;
		push @ERRORS, $le_err if $le_err;
       },

);

# Because we can't actually call $MS->new directly for our
# aggrigated "mock" method, register another handler for
# the new method for Mail::Sender

$mock->fake_module('Mail::Sender',

	new =>
		sub {$MS->newMethod(@_);},

);

# This strips off the extra creation parameters and returns
# the blessed object.

$MS->mock("newMethod", sub {$ms_params = $_[2]; return $MS});

# Because most of the inner workings of our MailMsg will 
# remain mostly the same, we'll create a mocked object to 
# pick through a series of results.

$MS->mock("MailMsg_return", sub { $MS });
$MS->mock("MailMsg", 
     sub { 

		my($this, $par_in) = @_;
		$ms_addr = $par_in->{to};
		$ms_body = $par_in->{msg};
		$ms_subject = $par_in->{subject};
		push @RECIPIENTS, $ms_addr;
		$MS->MailMsg_return();
	});

# We want to test whether or not someone closes this object
# like they should. This just trips a flag for it.

$MS->mock("Close", sub { $ms_isclosed = 1});

# Also, $SETTINGS is going to start by failing all calls to 
# getVars. This will get overidden lower in the code

$SETTINGS->set_always("getVars", undef);

# Everything::getNode needs to be jumpstarted into the space
# for Everything::MAIL. My thanks goes to chromatic for this
# smart little hack.

local *Everything::MAIL::getNode;
*Everything::MAIL::getNode = sub { Everything::getNode( @_ ) };


# Does use Everything::MAIL still return 1? This will tell us:

use_ok($package) or exit;
{
  # This is just test fodder, and nothing in particular
  my $email = "root\@nowhereinparticular.com";

  # Various combinatorics of missing arguments.

  ok(!node2mail(), 'node2mail should return undef if no arguments are given');
  ok(!node2mail($email), 'node2mail should return undef if $node is null' );
  ok(!node2mail($email, 1), 'node2mail should return if getNode returns undef');

  # Warnings that would most likely be helpful for debugging

  @WARNINGS = ();
  node2mail($email, 2);
  like(join("", @WARNINGS), qr/empty subject/, 'node2mail should log a warning if sending an email with an empty subject');

  @WARNINGS = ();
  node2mail($email, 3);
  like(join("", @WARNINGS), qr/empty subject/, 'node2mail should log a warning if sending an email with a subject with all spaces');

  @WARNINGS = ();
  node2mail($email, 4);
  like(join("", @WARNINGS), qr/empty body/, 'node2mail should log a warning if sending an email with an empty body');

  @WARNINGS = ();
  node2mail($email, 5);
  like(join("", @WARNINGS), qr/empty body/, 'node2mail should log a warning if sending an email with a body with all spaces');

  # If you forget to clear the variables, you get false positives!

  $ms_params->{smtp} = "";
  $ms_params->{from} = "";
  $ms_gotsettings = 0;
  $le_wrn = "";

  node2mail($email, 6);
  ok($ms_gotsettings, 'node2mail should request getNode(\'mail settings\', \'setting\') on valid body and subject (no valid getVars)');
  like(join("",@WARNINGS), qr/Can\'t find the mail settings/, 'node2mail should log a warning if it can\'t find the mail settings');

  ok($ms_params->{smtp} eq "localhost", 'node2mail should default to send via localhost if none is specified');
  ok($ms_params->{from} eq "root\@localhost", 'node2mail should default to send from root@localhost if none is specified');

  $ms_gotsettings = 0;
  $ms_params->{smtp} = "";
  $ms_params->{from} = "";


  # From here on out getVars will return valid psuedo-hashes.

  $SETTINGS->remove("getVars");
  $SETTINGS->set_series("getVars", undef, {mailserver => "mymailserver"}, {systemMailFrom => $email},
	{mailserver => "mymailserver", systemMailFrom => $email},
	{mailserver => "mymailserver", systemMailFrom => $email},
	{mailserver => "mymailserver", systemMailFrom => $email},
	{mailserver => "mymailserver", systemMailFrom => $email},
	{mailserver => "mymailserver", systemMailFrom => $email},
	);
  $mock->remove("SETTINGS");
  $mock->set_always("SETTINGS", $SETTINGS);

  # Test if getVars fails

  node2mail($email, 6);
  ok($ms_gotsettings, 'node2mail should request getNode(\'mail settings\', \'setting\') on valid body and subject (valid getVars)');
  ok($ms_params->{smtp} eq "localhost", 'node2mail should default to send via localhost if getVars fails');
  ok($ms_params->{from} eq "root\@localhost", 'node2mail should default to send from root@localhost if getVars fails');

  node2mail($email, 6);
  ok($ms_params->{smtp} eq "mymailserver", 'node2mail should use $SETTINGS->{mailserver} if in partial mail settings');
  ok($ms_params->{from} eq "root\@localhost", 'node2mail should default to send from root@localhost if not in partial mail settings');

  # Tests if "mail settings" have trouble with not having one or more
  # settings
  
  node2mail($email, 6);
  ok($ms_params->{smtp} eq "localhost", 'node2mail should default to send via localhost if not in partial mail settings');
  ok($ms_params->{from} eq $email, 'node2mail should use $SETTINGS->{systemMailFrom} if in partial mail settings');

  $ms_body = $ms_subject = $ms_addr = "";
  $ms_isclosed = 0;
  @RECIPIENTS = ();

  # The normal case: $SETTINGS is populated correctly

  node2mail($email, 6);
  ok($ms_params->{smtp} eq "mymailserver", 'node2mail should send via $SETTINGS->{mailserver} if in mail settings');
  ok($ms_params->{from} eq $email, 'node2mail should use $SETTINGS->{systemMailFrom} if in mail settings');

  # Check MailMsg

  ok($ms_body eq "test body", 'node2mail calls MailMsg with the correct $body');
  ok($ms_subject eq "test title", 'node2mail calls MailMsg with the correct $subject');
  ok($ms_addr eq $email, 'node2mail calls MailMsg with the correct $addr');
  ok($ms_isclosed, 'node2mail closes Mail::Sender when done');

  @RECIPIENTS = ();

  # Make sure that we can pass in an arrayref of addresses

  my $arraymembers = ["john\@foo.com", "perl\@lovesyou.org","dave\@matthews.za"];

  node2mail($arraymembers, 6);
  ok((join "", @$arraymembers) eq (join "", @RECIPIENTS), 'node2mail should accept and process an arrayref of addresses without missing one');

  # MailMsg fails 100% from here

  @RECIPIENTS = ();
  @WARNINGS = ();
  @ERRORS = ();
  $MS->remove("MailMsg_return");
  $MS->mock("MailMsg_return", sub { -250 });

  ok(node2mail($email, 6), 'node2mail should still succeed if mail sending is unsuccessful');
  like(join("", @WARNINGS), qr/MailMsg failed/, 'node2mail should log a warning if MailMsg failed');  

  # Mail::Sender->new() fails from here 100%

  $MS->remove("newMethod");
  $MS->mock("newMethod", sub { undef });  

  ok(!node2mail($email, 6), 'node2mail should return undef if Mail::Sender object creation fails');
  like(join("", @ERRORS), qr/Mail\:\:Sender creation failed/, 'node2mail should log the Mail::Sender error message if it fails');


}

##########################
# Test plan:
##########################
# mail2node
# take file
#       get array of files (can be ref)
#       use Mail::Address
#       loop through files
#               open file
#               look for 'Subject:' line
#                       get 'From:' and make Mail::Address parse it, store in $from
#                       get 'To:' line, parse it, store in $to
#                       get 'Subject:' line, store in $subject
#               slurp rest of file into $body (potential bug)
#               getNode of 'user' type, given registered user email address
#               getNode for new blank 'mail' node
#               insert node
#               set author, from_address, and body
#               update node

can_ok($package, 'mail2node');

