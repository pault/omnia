package EcoreApache;

use lib 't/lib';
use base 'Exporter';

use Apache::Test '-withtestmore';
use Apache::TestRequest qw(GET);
use Apache::TestUtil;
use Test::WWW::Mechanize;
use File::Temp;
use File::Copy;
use Apache2::Const ':common';
use IO::File;
use DBTestUtil qw(config_file nodebase skip_cond);
use Proc::ProcessTable;

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

    my $nb = nodebase();

    mkdir('t/conf') unless -e 't/conf';
    my $fh = IO::File->new( 't/conf/extra.conf.in', 'w' )
      or die "Can't open file for writing, $!";

    print $fh <<APACHECONF;
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

    system( 't/TEST', '-clean' );
    system( 't/TEST', '-start-httpd' );

### grab a copy of the same nodebase apache is using

    my $table     = Proc::ProcessTable->new;
    my $conf_file = Apache::Test::vars->{t_conf};
    my $flag =
      grep { /.*apache.*$conf_file/ } map { $_->cmndline } @{ $table->table };

    plan
      tests => 27,
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

    $response = GET '/nonsense/url';
    ok( $response->code == NOT_FOUND, "We can't go to a non-existing url." );

    $response = GET '/?node_id=1';
    ok( $response->is_success, '...if we ask for node 1, get OK response.' );

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

### Now we're roont let's go to a forbidden

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
