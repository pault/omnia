package Everything::Test::Mail;

use base 'Everything::Test::Abstract';
use Test::More;
use Test::MockObject;
use File::Spec;
use File::Temp;
use IO::File;
use SUPER;
use strict;
use warnings;

sub startup : Test(startup => +0) {
    my $self = shift;

    # We'll need a few MockObjects here

    my $mock     = Test::MockObject->new();
    my $MS       = Test::MockObject->new();
    my $SETTINGS = Test::MockObject->new();

    # A few different variables to hold parameters being passed in and out

    # For now, we are going to start off so that a call
    # to getNode("mail settings", "setting") will fail

    $mock->set_always( "SETTINGS", undef );

    # Begin the faking process with Everything.pm

    $self->{warnings}   = [];
    $self->{errors}     = [];
    $self->{recipients} = [];

    $mock->fake_module(
        "Everything",

        logErrors =>

          sub {
            my ( $le_wrn, $le_err ) = @_;
            push @{ $self->{warnings} }, $le_wrn if $le_wrn;
            push @{ $self->{errors} },   $le_err if $le_err;
          },

    );

    my $fh = Test::MockObject->new();

    # Because we can't actually call $MS->new directly for our
    # aggrigated "mock" method, register another handler for
    # the new method for Mail::Sender

    $mock->fake_module(
        'Mail::Sender',

        new => sub { $MS->newMethod(@_); },

    );

    # This strips off the extra creation parameters and returns
    # the blessed object.

    $MS->mock( "newMethod", sub { return $MS } );

    # Because most of the inner workings of our MailMsg will
    # remain mostly the same, we'll create a mocked object to
    # pick through a series of results.

    $MS->mock( "MailMsg_return", sub { $MS } );
    $MS->mock(
        "MailMsg",
        sub {

            my ( $this, $par_in ) = @_;
            push @{ $self->{recipients} }, $par_in->{to};
            $MS->MailMsg_return();
        }
    );

    # We want to test whether or not someone closes this object
    # like they should. This just trips a flag for it.

    $MS->mock( "Close", sub { 1 } );

    # Also, $SETTINGS is going to start by failing all calls to
    # getVars. This will get overidden lower in the code

    $SETTINGS->set_always( "getVars", undef );

    $self->{MS}       = $MS;
    $self->{mock}     = $mock;
    $self->{SETTINGS} = $SETTINGS;
    $self->SUPER;

}

sub test_node2mail : Test(29) {
    my $self     = shift;
    my $MS       = $self->{MS};
    my $SETTINGS = $self->{SETTINGS};
    my $mock     = $self->{mock};

    $mock->fake_module(
        "Everything",

        getNode =>

          sub {
            my ( $nparam, $tparam ) = @_;

            return unless $nparam;

            if ( $nparam eq "mail settings" and $tparam eq "setting" ) {

                return $mock->SETTINGS;
            }

            if ( ( ref $nparam ) eq "HASH" ) {

            }

            my $results = {
                1 => undef,
                2 => { title => "", doctext => "test body" },
                3 => { title => "   ", doctext => "test body" },
                4 => { title => "test title", doctext => "" },
                5 => { title => "test title", doctext => "  " },
                6 => { title => "test title", doctext => "test body" },
                7 => { title => "test title", from_address => 'me' },
            };

            return $results->{$nparam};
          },

        logErrors =>

          sub {
            my ( $le_wrn, $le_err ) = @_;
            push @{ $self->{warnings} }, $le_wrn if $le_wrn;
            push @{ $self->{errors} },   $le_err if $le_err;
          },

    );

    no strict 'refs';
    local *{ __PACKAGE__ . '::node2mail' };
    *{ __PACKAGE__ . '::node2mail' } = \&{ $self->{class} . '::node2mail' };
    use strict 'refs';

    ## Unfortunately, Everything.pm exports getNode to
    ## everything::mail. This has to be fixed.  At the moment, we can
    ## fake it like this.
    local *Everything::Mail::getNode;
    *Everything::Mail::getNode = sub { Everything::getNode(@_) };

    ## Ditto
    local *Everything::Mail::getType;
    *Everything::Mail::getType = sub { return uc( $_[0] ); };

    # This is just test fodder, and nothing in particular
    my $email = "root\@nowhereinparticular.com";

    # Various combinatorics of missing arguments.

    ok( !node2mail(), 'node2mail() should return given no arguments' );
    ok( !node2mail($email), '... or if $node is null' );
    ok( !node2mail( $email, 1 ), '... or if getNode returns undef' );

    # Warnings that would most likely be helpful for debugging

    $self->{warnings} = [];
    node2mail( $email, 2 );
    like(
        join( "", @{ $self->{warnings} } ),
        qr/empty subject/,
'node2mail should log a warning if sending an email with an empty subject'
    );

    $self->{warnings} = [];
    node2mail( $email, 3 );
    like(
        join( "", @{ $self->{warnings} } ),
        qr/empty subject/,
'node2mail should log a warning if sending an email with a subject with all spaces'
    );

    $self->{warnings} = [];
    node2mail( $email, 4 );
    like(
        join( "", @{ $self->{warnings} } ),
        qr/empty body/,
        'node2mail should log a warning if sending an email with an empty body'
    );

    $self->{warnings} = [];
    node2mail( $email, 5 );
    like(
        join( "", @{ $self->{warnings} } ),
        qr/empty body/,
'node2mail should log a warning if sending an email with a body with all spaces'
    );

    # If you forget to clear the variables, you get false positives!

    $MS->clear;
    node2mail( $email, 6 );

    like(
        join( "", @{ $self->{warnings} } ),
        qr/Can\'t find the mail settings/,
        'node2mail should log a warning if it can\'t find the mail settings'
    );

    my ( $method, $args ) = $MS->next_call;
    ok( $args->[2]->{smtp} eq "localhost",
        'node2mail should default to send via localhost if none is specified' );
    ok(
        $args->[2]->{from} eq "root\@localhost",
'node2mail should default to send from root@localhost if none is specified'
    );

    ### Test parameters passed to Mail::Sender's 'new' method
    $MS->clear;
    node2mail( $email, 7 );
    ( $method, $args ) = $MS->next_call;
    is( $args->[2]->{from}, 'me', '... or the from_address in the mail node' );

    # From here on out getVars will return valid psuedo-hashes.

    $SETTINGS->remove("getVars");
    $SETTINGS->set_series(
        "getVars",
        undef,
        { mailserver     => "mymailserver" },
        { systemMailFrom => $email },
        ( { mailserver => "mymailserver", systemMailFrom => $email } ) x 5,
    );
    $mock->remove("SETTINGS");
    $mock->set_always( "SETTINGS", $SETTINGS );

    # Test if getVars fails

    $MS->clear;

    node2mail( $email, 6 );

    ( $method, $args ) = $MS->next_call;
    ok( $args->[2]->{smtp} eq "localhost",
        'node2mail should default to send via localhost if getVars fails' );
    ok(
        $args->[2]->{from} eq "root\@localhost",
        'node2mail should default to send from root@localhost if getVars fails'
    );

    $MS->clear;
    node2mail( $email, 6 );
    ( $method, $args ) = $MS->next_call;
    ok(
        $args->[2]->{smtp} eq "mymailserver",
'node2mail should use $SETTINGS->{mailserver} if in partial mail settings'
    );
    ok(
        $args->[2]->{from} eq "root\@localhost",
'node2mail should default to send from root@localhost if not in partial mail settings'
    );

    # Tests if "mail settings" have trouble with not having one or more
    # settings

    $MS->clear;
    node2mail( $email, 6 );
    ( $method, $args ) = $MS->next_call;
    ok(
        $args->[2]->{smtp} eq "localhost",
'node2mail should default to send via localhost if not in partial mail settings'
    );
    ok(
        $args->[2]->{from} eq $email,
'node2mail should use $SETTINGS->{systemMailFrom} if in partial mail settings'
    );

    $self->{recipients} = [];

    # The normal case: $SETTINGS is populated correctly

    $MS->clear;
    node2mail( $email, 6 );
    ( $method, $args ) = $MS->next_call;
    ok(
        $args->[2]->{smtp} eq "mymailserver",
        'node2mail should send via $SETTINGS->{mailserver} if in mail settings'
    );
    ok(
        $args->[2]->{from} eq $email,
        'node2mail should use $SETTINGS->{systemMailFrom} if in mail settings'
    );

    # Check MailMsg

    ( $method, $args ) = $MS->next_call;
    is( $method, 'MailMsg', 'node2mail should call MailMsg next' );

    is( $args->[1]->{msg},
        "test body", 'node2mail calls MailMsg with the correct $body' );
    is( $args->[1]->{subject},
        "test title", 'node2mail calls MailMsg with the correct $subject' );
    is( $args->[1]->{to},
        $email, 'node2mail calls MailMsg with the correct $addr' );

    ( $method, $args ) = $MS->next_call;
    ( $method, $args ) = $MS->next_call;
    is( $method, 'Close', 'node2mail closes Mail::Sender when done' );

    $self->{recipients} = [];

    # Make sure that we can pass in an arrayref of addresses

    my $arraymembers =
      [ "john\@foo.com", "perl\@lovesyou.org", "dave\@matthews.za" ];

    node2mail( $arraymembers, 6 );
    ok(
        ( join "", @$arraymembers ) eq ( join "", @{ $self->{recipients} } ),
'node2mail should accept and process an arrayref of addresses without missing one'
    );

    # MailMsg fails 100% from here

    $self->{warnings}   = [];
    $self->{recipients} = [];
    $self->{errors}     = [];
    $MS->remove("MailMsg_return");
    $MS->mock( "MailMsg_return", sub { -250 } );

    ok( node2mail( $email, 6 ),
        'node2mail should still succeed if mail sending is unsuccessful' );
    like(
        join( "", @{ $self->{warnings} } ),
        qr/MailMsg failed/,
        'node2mail should log a warning if MailMsg failed'
    );

    # Mail::Sender->new() fails from here 100%

    $MS->remove("newMethod");
    $MS->mock( "newMethod", sub { undef } );

    ok( !node2mail( $email, 6 ),
        'node2mail should return undef if Mail::Sender object creation fails' );
    like(
        join( "", @{ $self->{errors} } ),
        qr/Mail\:\:Sender creation failed/,
        'node2mail should log the Mail::Sender error message if it fails'
    );

}

sub test_mail2node : Test(20) {

    my $self    = shift;
    my $mock    = $self->{mock};
    my $package = $self->{class};

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
    *Everything::Mail::getId = sub { Everything::getId(@_) };

    can_ok( $package, 'mail2node' ) || return 'Can\'t mail2node';

    no strict 'refs';
    local *{ __PACKAGE__ . '::mail2node' };
    *{ __PACKAGE__ . '::mail2node' } = \&{ $self->{class} . '::mail2node' };
    use strict 'refs';

    local *Everything::Mail::getType;
    *Everything::Mail::getType = sub { return uc( $_[0] ); };

    use_ok("Mail::Address");

    ok( !mail2node(), 'mail2node() should fail without files' );
    ok( ( join "", @{ $self->{warnings} } ) =~ /No input files for mail2node/,
        '...and should throw a warning saying so' );

    $self->{warnings} = [];

    ok( mail2node('/dummy/file'),
        'mail2node should return gracefully if it can\'t open up a file' );
    ok( ( join "", @{ $self->{warnings} } ) =~ /mail2node could not open/,
        '...throwing a warning saying so' );

    #Set up tests for invalid reading

    my $tmpdir = File::Spec->tmpdir;
    my $fh     = File::Temp->new(
        TEMPLATE => $$ . 'XXXXXXX',
        DIR      => $tmpdir,
        UNLINK   => 0
    );
    my $fname = $fh->filename;
    $self->{warnings} = [];

    $fh->close;
    ok( mail2node($fname),
'mail2node should return gracefully if it doesn\'t have enough to make a mail node'
    );
    ok(
        ( join "", @{ $self->{warnings} } ) =~
          /doesn\'t appear to be a valid mail file/,
        '...and should throw a warning saying so'
    );

    $self->{warnings} = [];
    $self->{errors}   = [];

    my $m2n_node = Test::MockObject->new( {} );
    my $m2n_user = Test::MockObject->new( {} );
    my $got_root = 0;

    $mock->fake_module(
        "Everything",
        getNode => sub {

            my ( $param, $nparam ) = @_;

            #if we're getting the user
            return $m2n_user->getMe() if ( ref($param) eq "HASH" );

            #if we're getting the node itself
            return $m2n_node->getMe() if ( $nparam eq "mail" );

            #if we're getting the root user
            if ( $param eq "root" and $nparam eq "user" ) {
                $got_root = 1;
                return { node_id => 5 };
            }
        },

        getId => sub {

            my ($node) = @_;
            return $node->{node_id};
        },
    );

    no strict 'refs';
    local *{ $self->{class} . '::getNode' };
    *{ $self->{class} . '::getNode' } = *{Everything::getNode}{CODE};
    use strict 'refs';

    $m2n_user->set_always( "getMe", undef );
    $m2n_node->set_always( "getMe", undef );

    $m2n_node->set_always( "insert", 1 );

    $self->{errors}   = [];
    $self->{warnings} = [];

    #No "To:" parameter
    $fh = IO::File->new( $fname, 'w' ) || return "Can't complete tests, $!";
    print $fh
      "From: testing\@test.com\nSubject: this is a test email!\n\nTesting!\n";
    $fh->close;

    mail2node($fname);
    ok(
        join( "", @{ $self->{warnings} } ) =~
/mail2node\: No \'To\:\' parameter specified\. Defaulting to user \'root\'/,
        'mail2node should default to root and warn if it doesn\'t find a To: '
    );
    ok( $got_root, '...and actually gets the root user' );

    $self->{errors}   = [];
    $self->{warnings} = [];

    $fh = IO::File->new( $fname, 'w' ) || return "Can't complete tests, $!";
    print $fh
      "From: testing\@test.com\nSubject: this is a test email!\n\nTesting!\n";
    $fh->close;

    mail2node($fname);
    ok(
        join( "", @{ $self->{errors} } ) =~
          /mail2node\: Node creation of type mail failed\!/,
        "Throw an error if mail2node creation directive fails"
    );

    $m2n_node->set_always( "getMe", $m2n_node );

    $m2n_node->{type_nodetype} = 5;    #fake mail nodetype

    $self->{errors}   = [];
    $self->{warnings} = [];

    $m2n_node->clear();
    $fh = IO::File->new( $fname, 'w' ) || return "Can't complete tests, $!";
    print $fh
"To: foo\@bar.com\nFrom: testing\@test.com\nSubject: this is a test email!\n\nTesting!\nHello\n";

    $fh->close;

    mail2node($fname);
    $m2n_node->called_ok( "insert", "mail2node calls insert" );
    is( $m2n_node->call_pos(2),
        "insert", "insert gets called in the right spot" );
    is( $m2n_node->call_args_pos( 2, 2 ),
        "-1", "insert gets called without permissions (-1)" );
    is(
        $m2n_node->{title},
        "this is a test email!",
        "...and the subject gets set correctly"
    );
    is( $m2n_node->{from_address},
        "testing\@test.com", "...and the from_address gets set correctly" );
    is( $m2n_node->{doctext}, "\nTesting!\nHello\n",
        "...and the doctext gets set correctly" );
    is( $m2n_node->{author_user},
        "5", "...and gets the (faked) root_id correctly!" );

    $m2n_user->set_always( "getMe", $m2n_user );

    $m2n_user->{node_id} = 24;
    $m2n_user->{title}   = "not root";

    $self->{errors}   = [];
    $self->{warnings} = [];

    $m2n_node->clear();

    $fh = IO::File->new( $fname, 'w' ) || return "Can't complete tests, $!";
    print $fh
"To: foo\@bar.com\nFrom: testing\@test.com\nSubject: this is a test email!\n\nTesting!\nHello\n";
    $fh->close;

    mail2node($fname);
    $m2n_node->called_ok( "insert",
        "mail2node calls insert when it can get the user" );
    is( $m2n_node->{author_user}, "24", "...and has the correct (faked) id" );

###############################
    #	Tests left:
###############################
    #	See what happens if Mail::Address returns null
    #	Badly formed email addresses
    #	Have hard limit of size of email (size of doctext)
    #	Make sure multiple files works
    unlink $fname;
}

1;
