#!/usr/bin/perl -w

use Test::More tests => 51;
use Test::MockObject;

my $package = "Everything::Mail";

################################################################
#
#	t/email.t 
#
#		Test Everything::Mail
#
#


#Load in the blib paths
BEGIN
{
	chdir 't' if -d 't';
	use lib '../blib/lib', 'lib', '..';
}

# We'll need a few MockObjects here

my $mock     = Test::MockObject->new();
my $MS       = Test::MockObject->new();
my $SETTINGS = Test::MockObject->new();

# A few different variables to hold parameters being passed in and out

my ($le_wrn,$le_err,$ms_isclosed, $ms_params, $ms_gotsettings, $ms_addr,
$ms_subject, $ms_body);

my (@WARNINGS, @ERRORS, @RECIPIENTS);

# For now, we are going to start off so that a call
# to getNode("mail settings", "setting") will fail

$mock->set_always("SETTINGS", undef);

# Begin the faking process with Everything.pm

$mock->fake_module( "Everything", 

getNode => 

    sub { 
		my ($nparam, $tparam) = @_;

		return unless $nparam;
		
		if($nparam eq "mail settings" and $tparam eq "setting")
		{
			$ms_gotsettings = 1;
			return $mock->SETTINGS;
		}

		if((ref $nparam) eq "HASH")
		{
			
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

my $fh = Test::MockObject->new();

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
		$ms_addr    = $par_in->{to};
		$ms_body    = $par_in->{msg};
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
# for Everything::Mail. My thanks goes to chromatic for this
# smart little hack.

local *Everything::Mail::getNode;
*Everything::Mail::getNode = sub { Everything::getNode( @_ ) };

local *Everything::Mail::getType;
*Everything::Mail::getType = sub { return uc($_[0]); };

local *Everything::Mail::FILE;
tie *Everything::Mail::FILE, 'MockHandle', "This will never be read", 1;
use MockHandle;

my $MockHandle_closed;

local *MockHandle::CLOSE;
*MockHandle::CLOSE = sub { $MockHandle_closed = 1 };

# Does use Everything::Mail still return 1? This will tell us:

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
  @WARNINGS   = ();
  @ERRORS     = ();
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
#               set author, from_address, and body
#               insert node

local *Everything::Mail::getId;
*Everything::Mail::getId = sub { Everything::getId( @_ ) };

can_ok($package, 'mail2node');

use_ok("Mail::Address");

ok(!mail2node(), 'mail2node() should fail without files');
ok((join "", @WARNINGS) =~ /No input files for mail2node/, '...and should throw a warning saying so');

@WARNINGS = ();

ok(mail2node('/dummy/file'), 'mail2node should return gracefully if it can\'t open up a file');
ok((join "",@WARNINGS) =~ /mail2node could not open/,
	'...throwing a warning saying so');

#Set up tests for invalid reading
untie *Everything::Mail::FILE;
tie *Everything::Mail::FILE, 'MockHandle', "THIS IS INVALID TEXT";

@WARNINGS = ();
$MockHandle_closed = 0;
ok(mail2node('/dummy/file'), 'mail2node should return gracefully if it doesn\'t have enough to make a mail node');
ok((join "",@WARNINGS) =~ /doesn\'t appear to be a valid mail file/, '...and should throw a warning saying so');
ok($MockHandle_closed, '...and should close the file handle');


#No "To:" parameter
untie *Everything::Mail::FILE;
tie *Everything::Mail::FILE, 'MockHandle', 
"From: testing\@test.com\nSubject: this is a test email!\n\nTesting!\n";

@WARNINGS = ();
@ERRORS = ();
$MockHandle_closed = 0;


my $m2n_node = Test::MockObject->new({});
my $m2n_user = Test::MockObject->new({});
my $got_root = 0;

$mock->fake_module("Everything",
	getNode => sub{

			my ($param, $nparam) = @_;

			#if we're getting the user
			return $m2n_user->getMe() if(ref($param) eq "HASH");

			#if we're getting the node itself
			return $m2n_node->getMe() if($nparam eq "mail");
			
			#if we're getting the root user			
			if($param eq "root" and $nparam eq "user"){
				$got_root = 1;
				return {node_id => 5};
			}
		},

	getId => sub{

			my ($node) = @_;
			return $node->{node_id};
		},
	);

$m2n_user->set_always("getMe", undef);
$m2n_node->set_always("getMe", undef);

$m2n_node->set_always("insert", 1);

@ERRORS = (); @WARNINGS = ();
mail2node('/dummy/file');
ok(join("", @WARNINGS) =~ /mail2node\: No \'To\:\' parameter specified\. Defaulting to user \'root\'/, 'mail2node should default to root and warn if it doesn\'t find a To: ');
ok($got_root, '...and actually gets the root user');

untie *Everything::Mail::FILE;
tie *Everything::Mail::FILE, 'MockHandle', 
"From: testing\@test.com\nSubject: this is a test email!\n\nTesting!\n";

@ERRORS = (); @WARNINGS = ();

mail2node('/dummy/file');
ok(join("", @ERRORS) =~ /mail2node\: Node creation of type mail failed\!/, "Throw an error if mail2node creation directive fails");

$m2n_node->set_always("getMe", $m2n_node);

$m2n_node->{type_nodetype} = 5; #fake mail nodetype

untie *Everything::Mail::FILE;
tie *Everything::Mail::FILE, 'MockHandle', "To: foo\@bar.com\nFrom: testing\@test.com\nSubject: this is a test email!\n\nTesting!\nHello\n";
@ERRORS = (); @WARNINGS = ();
$m2n_node->clear();
mail2node('/dummy/file');
$m2n_node->called_ok("insert", "mail2node calls insert");
is($m2n_node->call_pos(2), "insert", "insert gets called in the right spot");
is($m2n_node->call_args_pos(2, 2),"-1", "insert gets called without permissions (-1)");
is($m2n_node->{title}, "this is a test email!", "...and the subject gets set correctly");
is($m2n_node->{from_address}, "testing\@test.com", "...and the from_address gets set correctly");
is($m2n_node->{doctext}, "\nTesting!\nHello\n", "...and the doctext gets set correctly");
is($m2n_node->{author_user}, "5", "...and gets the (faked) root_id correctly!");

$m2n_user->set_always("getMe", $m2n_user);

$m2n_user->{node_id} = 24;
$m2n_user->{title} = "not root";

untie *Everything::Mail::FILE;
tie *Everything::Mail::FILE, 'MockHandle', "To: foo\@bar.com\nFrom: testing\@test.com\nSubject: this is a test email!\n\nTesting!\nHello\n";
@ERRORS = (); @WARNINGS = ();
$m2n_node->clear();

mail2node('/dummy/file');
$m2n_node->called_ok("insert", "mail2node calls insert when it can get the user");
is($m2n_node->{author_user}, "24", "...and has the correct (faked) id");


###############################
#	Tests left:
###############################
#	See what happens if Mail::Address returns null
#	Badly formed email addresses
#	Have hard limit of size of email (size of doctext)
#	Make sure multiple files works
