package EcoreApache;

use lib 't/lib';
use base 'Exporter';

use Apache::Test '-withtestmore';
use Apache::TestRequest qw(GET);
use Apache::TestUtil;
use Test::WWW::Mechanize;
use File::Temp;
use File::Copy;
use List::Util qw/max/;
use Apache2::Const ':common';
use IO::File;
use DBTestUtil qw(config_file nodebase skip_cond);
use Proc::ProcessTable;
use utf8;

use strict;
use warnings;

our @EXPORT_OK = ('apache_tests');

sub apache_tests {

### write t/conf/extra.conf.in

    my $config_file = '../' . config_file();

    if (  my $skip = skip_cond ) {

	plan skip_all => $skip;
	return;

    }

### test for apache extension tool

    my $apxs = 'apxs2';

    if ( ! `which $apxs` ) {
	plan skip_all => "Apache Extenstion Tool, $apxs, must be installed. Skipping all tests.";
	return;
    }

    my $nb = nodebase();

    mkdir('t/conf') unless -e 't/conf';
    my $fh = IO::File->new( 't/conf/extra.conf.in', 'w' )
      or die "Can't open file for writing, $!";

    print $fh <<APACHECONF;
LoadModule perl_module /usr/lib/apache2/modules/mod_perl.so
<Perl>
use lib '\@SERVERROOT\@/../lib';
</Perl>

SetHandler perl-script
PerlSetVar everything-config-file $config_file
PerlResponseHandler +Everything::HTTP::Apache

<Location /images>
        SetHandler default-handler
</Location>

APACHECONF

    $fh->close;

### start apache server

    # my $status = system( 't/TEST', '-clean' );
    diag `t/TEST -clean 2>&1`;

    if ( ($? >> 8) != 0 ) {
        plan skip_all => "Failed to clean apache setup directory.  Skipping all tests.";
	return;
    }

    #$status = system( 't/TEST', '-start-httpd' );
    diag `t/TEST -start-httpd 2>&1`;

    if ( ($? >> 8) != 0 ) {
        plan skip_all => "Failed to start apache.  Skipping all tests.";
	return;
    }


### grab a copy of the same nodebase apache is using

    my $table     = Proc::ProcessTable->new;
    my $conf_file = Apache::Test::vars->{t_conf};
    my $flag =
      grep { /.*apache.*$conf_file/ } map { $_->cmndline } @{ $table->table };

    plan
      tests => 47,
      need {
        "Correct apache process must be running." => sub { $flag }
      };

    my $mech = Test::WWW::Mechanize->new;

    my $base =
        'http://'
      . Apache::Test::vars->{remote_addr} . ':'
      . Apache::Test::vars->{port};

    my $response = GET '/';

    $mech->get_ok( $base . '/', 'Root directory should return OK.' );
    $response = $mech->response;
    is( $response->header('Cache-Control'),
        'public', '...with Cache-Control set to "public"' );

    $response = GET '/nonsense/url';
    ok( $response->code == NOT_FOUND, "We can't go to a non-existing url." );

    $response = GET '/?node_id=1';
    ok( $response->is_success, '...if we ask for node 1, get OK response.' );

    my $ids = $nb->get_storage->selectNodeWhere();
    my $top_id = max @$ids;
    $top_id++;

    $mech->get_ok(  "/?node_id=$top_id", "Even a node that doesn't exist returns OK." );
    $mech->title_is ( 'Not found', "...and sends us to the 'Not found' node.");

## XXX: Hmmm, should return NOT AUTHORISED
    $response = GET '/node/1';
    ok( $response->is_success,
        '...if we ask for node 1 with url schema, get OK response.' );

    $mech->get_ok( "$base/node/2/", '.... node 2 is OK' );
    $mech->title_is( 'Permission Denied',
        '...redirected to not allowed node.' );

## try to login as root

    $mech->get_ok( "$base?node=login", '.... login node OK.' );
    $mech->title_is( "login", '...not redirected.' );
    $mech->submit_form_ok(
        { form_number => 3, fields => { user => 'root' }, button => 'submit' },
        '...submits form.'
    );
    $mech->content_contains( "Hey.  Glad you're back",
        '... reports we are logged in.' )
      || diag $mech->content;

    $response = $mech->response;
    is( $response->header('Cache-Control'),
        'private', '...and that Cache-Control is set to "private"' );

### Now we're root let's go to a forbidden node

    $mech->get_ok( "$base/node/1", 'Now, we go to node 1.' );
    $mech->title_is( 'nodetype', '...which reports the correct title. ' );

    $mech->follow_link_ok( { text => "Edit root's settings" },
        "Go to our setting's page." );
    $mech->submit_form_ok(
        {
            form_number => 5,
            fields      => { passwd => 'root', passwd_confirm => 'root' },
            button      => 'button'
        },
        "...and change root password."
    );

    $mech->get_ok( "$base?node=login", 'We go back to the login page.' );
    $mech->submit_form_ok(
        {
            form_number => 3,
            fields      => { user => 'root', passwd => 'root' },
            button      => 'submit'
        },
        '...login with our new password.'
    );
    $mech->content_contains( "Hey.  Glad you're back",
        '...and are presented with the welcome message.' )
      || diag $mech->content;

## If we have nodes with UTF8 titles and contents should come out properly
    my $utf8_title = "Český název";
    my $utf8_contents = "Něco v češtině";

    my $utf8_node = $nb->getNode( $utf8_title, 'document', 'create force' );

    $utf8_node->set_doctext( $utf8_contents );

    my $utf8_node_id = $nb->store_new_node( $utf8_node, -1 );

    $mech->get_ok( "$base?node_id=$utf8_node_id", 'Can get utf8 node.' );

    like( $mech->response->header('Content-Type'), qr/charset=utf-8/, '...charset is set to utf8');

    ## mech doesn't decode pages properly, grrrr
    #    So this doesn't work:
    #    $mech->title_is( $utf8_title, '...title is correct.' );
    #
    #    HTML::HeadParser is pulled in by Mech anyway so it is here to use

    my $p = HTML::HeadParser->new;
    $p->parse(  $mech->response->decoded_content );
    use Carp; local $SIG{__DIE__} = \&Carp::confess;
    is ($p->header('Title'), $utf8_title, '...utf8 title is correct.');

    like ( $mech->response->decoded_content, qr/$utf8_contents/, '...with correct utf8 encoded contents.') || diag $mech->content;

    $nb->delete_stored_node( $utf8_node, -1 );

## Now let's create a document node with a utf8 title
    $mech->get_ok( "$base?node=create node", 'Go to create a new node page.' );
    $mech->title_is( "create node", '...check the title is corrent.');
  SKIP: {
	my $v = $HTTP::Message::VERSION;

	skip "Incorrect HTTP::Message installed", 10 if $v < 6.02 ;

	$utf8_title = "ščříéùâîèôîïâûùàêëüçě£";
	$mech->submit_form_ok( {  with_fields => { node => $utf8_title, type => 'document' } }, '...submit create new node form.' );

	$p = HTML::HeadParser->new;
	$p->parse(  $mech->response->decoded_content );

	is ($p->header('Title'), $utf8_title, '...and redirects to the newly created node with utf8 title.');


	$mech->follow_link_ok( { text => 'edit' }, 'Go to the edit page for this node.' );

	like( $mech->response->decoded_content, qr/value="$utf8_title"/, '...default form values set properly.');

	my $utf8_content='£êéèôîïâûùàëçüěščřžýáíéůúßöääÜÖ';

	$mech->submit_form_ok( { with_fields => { title => $utf8_title, author_user => 'root', doctext => $utf8_content } }, '...adds content to the document.' );

	like ($mech->response->decoded_content, qr/>$utf8_content<\/textarea>/, '...with the text area displayed properly.' );

	$mech->follow_link_ok( { text => 'display' }, '...go back to the display page.' );

	like ($mech->response->decoded_content, qr/$utf8_content/, '...with the utf8 text displayed properly.' );

      SKIP: {
	    # This we should test by following the 'delete' link, but that
	    # link uses javascript that Mech doesn't understand :(

	    eval 'use URI';

	    skip "These tests require URI module, which isn't installed, $@", 2 if $@;

	    my $uri = $mech->response->request->uri;
	    my $u = URI->new( $uri );

	    my $n = $nb->getNode($utf8_title, 'document');

	    $u->query_form( op => 'nuke', node_id => $n->get_node_id );

	    $mech->get_ok( $u->as_string, '...now try to delete it.');

	    like ($mech->response->decoded_content, qr/$utf8_title.+was successfully delete/, '...and we go to the node deleted page.');

	}
    }
## Now let's create another user
    my $user_type = $nb->getNode( 'user', 'nodetype' );
    $mech->follow_link_ok(
        { text => "Create new node" },
        "Let's go to the create ne node page."
    );
    $mech->submit_form_ok(
        {
            form_number => 5,
            fields      => { node => 'a user', type => $user_type->getId },
            button      => 'createit'
        },
        '...create a new user.'
    );

    $mech->follow_link_ok( { text => 'edit' }, '...and go to the edit page.' );
    $mech->submit_form_ok(
        {
            form_number => 5,
            fields => { passwd => 'password', passwd_confirm => 'password' },
            button => 'button'
        },
        "...and change the user's password."
    );
    $mech->follow_link_ok( { text => "Log root out" },
        "...and logout root out." );

### Now log in as 'a user' and do access tests

    $mech->get_ok( "$base?node=login", 'We go back to the login page.' );
    $mech->submit_form_ok(
        {
            form_number => 3,
            fields      => { user => 'a user', passwd => 'password' },
            button      => 'submit'
        },
        '...login with our new password.'
    );
    $mech->content_contains( "Hey.  Glad you're back",
        '...and are presented with the welcome message.' )
      || diag $mech->content;

    $mech->get_ok( "$base/node/2", 'A user goes to the node nodetype.' );
    $mech->title_is( 'Permission Denied',
        '...and is redirected to not allowed node.' );

### reset root password to blank so we can rerun the tests

    my $root = $nb->getNode( 'root', 'user' );
    $root->set_passwd('');
    $root->update(-1);

    system( 't/TEST', '-stop-httpd' );
}

1;
