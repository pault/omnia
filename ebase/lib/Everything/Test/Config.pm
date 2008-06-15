package Everything::Test::Config;

use base 'Everything::Test::Abstract';
use SUPER;
use Test::More;
use Test::MockObject;
use File::Temp qw/:seekable/;
#use Everything::Config;
use strict;
use warnings;

my @args;

sub startup :Test(startup => +0) {
    my $self = shift;
    my $mock = Test::MockObject->new;
    $mock->fake_module('Everything::NodeBase', new => sub { @args = @_ } );
    $self->{mock}=$mock;
    $self->SUPER;

}

sub test_interface : Test(4) {
    my $self = shift;
    my $class = $self->module_class;


    foreach (qw/nodebase htmlvars request_modifiers node_locations/) {
	can_ok( $class, $_ );
    }
}

sub test_htmlvars : Test(5) {
    my $self = shift;

    my $inst = $self->{instance};
    my $mock = $self->{mock};

    $mock->set_always( getNode => $mock );
    $mock->set_always( getVars => { key => 'value' } );
    local *Everything::initEverything;
    *Everything::initEverything = sub { $mock };

    my $rv = $inst->htmlvars;
    my ($method, $args) = $mock->next_call;
    is ($method, 'getNode', '...calls on nodebase.');
    is ("@$args", "$mock system settings setting", '...uses "system settings" as name of setting node.');
    is_deeply( $rv, { key => 'value' }, '...returns hash from system settings.' );

    ### set up file for testing htmlvars

    my $fh = File::Temp->new();
    print $fh <<HERE;
htmlvars firstkey = firstvalue
htmlvars secondkey = secondvalue
HERE

    my $filename = "$fh";
    $fh->seek( 0, SEEK_SET );
    $inst = $self->{class}->new( file => $filename );
    $rv = $inst->htmlvars;

    is_deeply ( $rv, { firstkey => 'firstvalue', secondkey => 'secondvalue', key => 'value' }, '...retrieves data from file and settings node.');

    $fh->truncate( 0 );

    print $fh <<HERE;
htmlvars firstkey = firstvalue
htmlvars key = eulav
htmlvars secondkey = secondvalue
HERE

    $fh->seek( 0, SEEK_SET );
    $mock->set_always( getVars => { key => 'better value' } );
    $inst = $self->{class}->new( file => $filename );
    $rv = $inst->htmlvars;

    is_deeply ( $rv, { firstkey => 'firstvalue', secondkey => 'secondvalue', key => 'better value' }, '...values in settings node override values in file.');

}

sub test_nodebase : Test(3) {
    my $self  = shift;
    my $inst = $self->{instance};
    $inst->database_name('aname');
    $inst->database_user('auser');
    $inst->database_password('apass');
    $inst->database_host('ahost');
    $inst->database_type('atype');

    my @args;
    local *Everything::initEverything;
    *Everything::initEverything = sub { @args = @_ };
    ok( my $nb = $self->{instance}->nodebase, '...calls nodebase.');
    is( $args[0], "aname:auser:apass:ahost", '...with db string argument.');
    is_deeply( $args[1], { dbtype => 'atype', staticNodetypes => undef }, '...with option arguments.');
}
sub fixture : Test(setup) {
    my $self = shift;
    my $instance = $self->{class}->new();
    $self->{instance} = $instance;
}

sub test_handle_location_schemas :Test(2) {
   my $self = shift;

    my $fh = File::Temp->new();
    print $fh <<HERE;
location_schema_nodetype = /node/:node_id node
HERE

    $fh->seek( 0, SEEK_SET );
    my $inst = $self->{class}->new( file => "$fh" );

   my $rv = $inst->get_deconstruct_locations;
   my $mock = Test::MockObject->new;
   $mock->set_true ( qw/isa/ );
   $mock->set_always( get_node_id => 777 );
   $mock->{node_id} = 777;
   is ( $$rv[0]->( $mock ), '/node/777', '...creates location properly.');

   $fh->truncate(0);
    print $fh <<HERE;
location_schema_nodetype = /article/:node_id node
location_schema_nodetype = /paper/:node_id node
HERE

   $fh->seek( 0, SEEK_SET );
   $inst = $self->{class}->new( file => "$fh" );

   $rv = $inst->get_deconstruct_locations;

   is ( $$rv[1]->( $mock ), '/paper/777', '...can handle several location creators.');
}

sub test_request_modifiers :Test(4) {
    my $self = shift;

    my $inst = $self->{instance};

    is_deeply( $inst->request_modifiers, [], '...returns an empty array ref when nothing defined.');

    my $fh = File::Temp->new();
    print $fh <<HERE;
request_modifier_standard = css
HERE

    $fh->seek( 0, SEEK_SET );
    $inst = $self->{class}->new( file => "$fh" );
    is_deeply( $inst->request_modifiers, [ $inst->get_standard_modifier( 'css' )], '...returns css modifier.');

    $fh->truncate( 0 );
    print $fh <<HERE;
request_modifier_code = sub { 'a random string' }
HERE

    $fh->seek( 0, SEEK_SET );
    $inst = $self->{class}->new( file => "$fh" );
    my $rv = $inst->request_modifiers;

    is ( ref $$rv[0], 'CODE', '...a code block should return a code ref.');
    is ( $$rv[0]->(), 'a random string', '...code executes properly.');
}

sub test_node_locations : Test(3) {
    my $self = shift;


    my $fh = File::Temp->new();
    print $fh <<HERE;
location_code = sub { \$_[0]->title }
HERE

    $fh->seek( 0, SEEK_SET );
    my $inst = $self->{class}->new( file => "$fh" );

    my $rv = $inst->node_locations;
    is ( @$rv, 1, '...if one location_code returns one subroutine.');

    my $mock = Test::MockObject->new;
    $mock->set_always( title => 'node title');
    is( $$rv[0]->( $mock ), 'node title', '...code returns expected value.');

    $fh->truncate( 0 );
    print $fh <<HERE;
location_schema_nodetype = /node/:title thingy
location_code = sub { \$_[0]->title }
HERE

    $fh->seek( 0, SEEK_SET );
    $inst = $self->{class}->new( file => "$fh" );

   $rv = $inst->node_locations;
    is ( @$rv, 2, '...one location_code one schema returns two subroutines.');

}

sub test_initial_values : Test(5) {
    my $self = shift;
    my $inst = $self->{instance};
    is ( $inst->database_name, '', '...database name defaults to empty string.');
    is ( $inst->database_user, '', '...database user defaults to empty string.');
    is ( $inst->database_password, '', '...database password defaults to empty string.');
    is ( $inst->database_host, '', '...database host defaults to empty string.');
    is ( $inst->database_type, '', '...database type defaults to empty string.');
}

1;
