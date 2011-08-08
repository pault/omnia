
package Everything::Test::Ecore::Compile;

use base 'Test::Class';
use Everything::HTML ();
use Everything ();
use HTML::Lint;
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Scalar::Util qw/blessed/;
use Carp;
use strict;
use warnings;

eval 'use HTML::Tidy 1.54'; ## no critic

my $html_tidy_error;
$html_tidy_error = $@ if $@;

## error handling - until error handling is made more flexible

my $err;

sub report_error {

    diag join( "\n", map { join "\n", $_->{context}->get_title, $_->{context}->get_node_id, $_->{error}  } @{ Everything::getFrontsideErrors() });

}


sub test_node_error {
    my ( $node, $parsetype ) =  @_;

    my $error = join "\n", map { $_->{error} } @{ Everything::getFrontsideErrors() };
    is( $error, '',
"...execute $parsetype for node $$node{title}, type" . $node->type_title .", id, $$node{node_id}"
	     ) || report_error();

}

sub clear_errors {
   $err = [];
}

sub SKIP_CLASS {
    my $self = shift;
    my $class = ref $self ? ref $self : $self;
    $class->SUPER( @_ );
}

sub startup : Test( startup ) {
    my $self = shift;

    my $nb = $self->{nodebase} || croak "No nodebase. Need a nodebase to run tests.";

    my @nodes_under_test = ();
    foreach (
        qw/htmlpage htmlsnippet htmlcode container nodelet superdoc opcode/)
    {
        my $nodes = $nb->getNodeWhere( '', $_ );
        push @nodes_under_test, @$nodes;
    }

    $self->{nodes_under_test} = \@nodes_under_test;

    my $mock = Test::MockObject->new;
    $mock->fake_module( 'Everything::XML::Node', new => sub { $mock } );

    $self->{mock} = $mock;

}
 
sub pretest_setup : Test(setup) {

    my $self = shift;
    my $mock = $self->{mock};
    $mock->set_always( get_cgi => $mock );
    $mock->set_true(qw/submit end_form/);

    ## mocks for ehtml
    $mock->set_always( get_user_vars => { key => 'value' } );
    $mock->set_always( get_user        => $mock );
    $mock->set_always( get_system_vars => { systemkey => 'systemvalue' } );
    $mock->set_always( get_nodebase    => $mock );
    $mock->set_always( get_node        => $mock );
    $mock->set_always( get_node_id     => 111 );
    $mock->set_always( link_node_title => 'a url' );
    $mock->set_always( get_message  => 'a message' );

    # mocks for $query
    $mock->set_always( hidden               => '<input type="hidden" value="a sting of html" />' );
    $mock->set_always( popup_menu           => 'a string of html' );
    $mock->set_always( radio_group          => 'a string of html' );
    $mock->set_always( password_field       => 'a string of html' );
    $mock->set_always( textarea             => 'a string of html' );
    $mock->set_always( textfield            => 'a string of html' );
    $mock->set_always( start_form           => '<form action="/">' );
    $mock->set_always( end_form             => '</form>' );
    $mock->set_always( script_name          => 'a script name' );
    $mock->set_always( scrolling_list       => 'a string of html' );
    $mock->set_always( checkbox             => 'a string of html' );
    $mock->set_always( button               => 'a string of html' );
    $mock->set_always( checkbox_group       => 'a string of html' );
    $mock->set_always( start_multipart_form => '<form action="/">' );
    $mock->set_always( h2                   => 'a string of html' );
    $mock->set_always( p                    => 'a string of html' );
    $mock->set_true('param');
    $mock->set_always( user_agent => 'Ecore Test Suite' );

    # mocks for $DB
    $mock->set_always( getNodeWhere => [ $mock, $mock ] );
    $mock->set_always( getType      => $mock );
    $mock->set_always( getNode      => $mock );
    $mock->set_true(qw/getRef addFieldToTable hasTypeAccess/);
    $mock->set_always( now      => 'db now command' );
    $mock->set_always( timediff => 'db command to calculate time differences' );
    $mock->set_list( getFields => [qw/field1 field2/] );
    $mock->set_list(
        getFieldsHash => { Field => 'field1' },
        { Field => 'field2' }
    );
    $mock->set_list( getAllTypes => $mock, $mock );
    $mock->set_always( getNodeById       => $mock );
    $mock->set_always( getNodetypeTables => [qw/table1 table2/] );
    $mock->set_always( sqlSelectMany => undef );    # make workspace info pass
    $mock->set_list( fetchrow => undef );
    $mock->set_series( fetchrow_hashref => { title => 1}, {title => 2 } );
    $mock->set_always( getDatabaseHandle => $mock );
    $mock->set_always( sqlSelect         => undef );
    $mock->mock( getRef => sub { $_[1] = $mock } );
    $mock->set_always( get_storage => $mock );
    $mock->set_always( retrieve_nodetype_tables => [ qw/table1 table2/ ] );

    # mocks for $dbh
    $mock->set_always( quote => 'a quoted string' );
    $mock->set_true(qw/execute/);
    $mock->set_always( prepare => $mock );

    # mocks for $NODE
    $mock->set_always( run           => 'a string of text' );
    $mock->set_always( get_title     => 'a node title' );
    $mock->set_always( getTableArray => [qw/table1 table2/] );
    $mock->set_true(qw/undo setVars update/);
    $mock->set_true(
        'cacheMethod',  'isOfType',
        'toXML',        'addType',
        'sortMenu',     'getDefaultTypePermissions',
        'genPopupMenu', 'addHash', 'isGuest', 'insert', 'insertIntoGroup'
    );
    $mock->set_always( 'getId', 111 );
    $mock->set_false(qw/isGod isOfType/);
    $mock->set_always( selectLinks => [ { to_node => 1, from_node => 2 } ] );
    $mock->set_always( listNodes   => [$mock] );
    $mock->set_always( getNodelets => [$mock] );
    $mock->set_always( 'getVars', { a => 'var' } );

    $mock->set_false( 'hasAccess', 'isGroup' );
    $mock->set_always( 'getHash', {} );
    $mock->set_always( 'genObject', $mock );
    $mock->set_always( 'get_doctext', 'text' );
    $mock->set_always( 'get_from_address', 'from@address' );
    $mock->set_always( 'type', $mock );
    $mock->set_always( get_code => 'print' );
    $mock->{group} = [1, 2, 3 ];
    $mock->{src}= "/images/source/";
    $mock->{defaultauthoraccess} = 'default author access';
    $mock->{derived_defaultauthoraccess} = 'derived default author access';
    $mock->{defaultgroupaccess} = 'default group access';
    $mock->{derived_defaultgroupaccess} = 'derived default group access';
    $mock->{defaultotheraccess} = 'default other access';
    $mock->{derived_defaultotheraccess} = 'derived default other access';
    $mock->{defaultguestaccess} = 'default guest access';
    $mock->{derived_defaultguestaccess} = 'derived default guest access';
    $mock->set_always( get_supports_nodetype => 1 );
    $mock->{doctext}='some text';

    # others
    $mock->set_always( toXML => 'some xml' );
}

sub test_compile_nodes : Tests {
    my $self = shift;

    my @nodes = @{ $self->{nodes_under_test} };
    $self->num_tests( scalar @nodes );

    my %successful_nodes;

    foreach (@nodes) {

        $err = '';
        my $rv = $_->compile( $_->{ $_->get_compilable_field } );
        (
            ok( !$err,
"...'$$_{title}' of type '" . $_->type->get_title."', $$_{node_id} compiles without error."
              )
              && ( $successful_nodes{ $$_{node_id} } = 1 )

        ) || diag $err;

    }

    $self->{test_execute_nodes} = \%successful_nodes;
}

sub test_execute_htmlcode_nodes : Tests {
    my $self = shift;

    my $mock = $self->{mock};

    $mock->{DB}    = $mock;
    $mock->{cache} = $mock;

    my $test_nodes    = $self->{nodebase}->getNodeWhere( '', 'htmlcode' );
    my $compilable    = $self->{test_execute_nodes};
    my @nodes_to_test = grep { $$compilable{ $_->{node_id} } } @$test_nodes;

    # one test for execution, one test for html validity less two for
    # openform and closeform and themeselectorwhich deliberately have mangled html
    $self->num_tests( scalar(@nodes_to_test) * 2 - 3);

    $mock->{node_id} = 123;
    $mock->{to_node} = 456;
    my @args;

    foreach (@nodes_to_test) {

        my $node = $self->{nodebase}->getNode($_);

	$err =  [];

        my @args = ();

        if ( $$node{title} eq 'formatCols' ) {
            @args = ( [ 1, 2, 3 ] );
        }

        my $ehtml = Everything::HTML->new( { request => $mock } );
        my $rv = $node->run( { args => \@args, ehtml => $ehtml } );

	test_node_error( $node, 'PERL' );

	# these have mangled html and should probably be ditched.
	next if $$node{title} eq 'openform' || $$node{title} eq 'closeform' || $$node{title} eq 'themeselector';

	return "Skipping test, install correct HTML::Tidy" if $html_tidy_error;

        my $tidy = HTML::Tidy->new;

       $tidy->parse( $$node{title}, $rv );

	my @filtered_messages = filter_tidy_messages( $tidy );

        is(
            scalar @filtered_messages,
            0,
"...the HTML produced for node '$$node{title}' of type '".$node->type_title."' has no errors."
          )
          || do {
            diag $_->as_string . "\n" . $rv foreach @filtered_messages;
          };

    }

}

sub test_execute_opcode_nodes : Tests {
    my $self = shift;

    my $mock = $self->{mock};

    my $test_nodes    = $self->{nodebase}->getNodeWhere( '', 'opcode' );
    my $compilable    = $self->{test_execute_nodes};
    my @nodes_to_test = grep { $$compilable{ $_->{node_id} } } @$test_nodes;
    $self->num_tests( scalar(@nodes_to_test) );

    $mock->{group} = [];

    foreach (@nodes_to_test) {
        $err                     = '';
        $Everything::HTML::GNODE = $mock;
        my $node = $self->{nodebase}->getNode($_);

        my @args = ();

        # opcodes are only passed the request object as the only argument
        my $rv = $node->run( { args => [$mock] } );

	test_node_error( $node, 'PERL' );

    }
}

sub test_execute_htmlpage_nodes : Tests {
    my $self = shift;

    $self->test_parse_eval_nodes('htmlpage');

}

sub test_execute_htmlsnippet_nodes : Tests {

    my $self = shift;

    my $mock = $self->{mock};

    $self->test_parse_eval_nodes(
        'htmlsnippet',
    );

}

sub test_execute_container_nodes : Tests {

    my $self = shift;

    $self->test_parse_eval_nodes('container');
    return;
    $self->test_parse_eval_nodes(
        'container'
				);

}

sub test_execute_nodelet_nodes : Tests {

    my $self = shift;

    $self->test_parse_eval_nodes('nodelet');
}

sub test_execute_superdoc_nodes : Tests {

    my $self = shift;

    $self->test_parse_eval_nodes('superdoc');
}

sub setup_parser {

    my %parse_types = map { $_ => 1 } qw/TEXT PERL HTMLCODE HTMLSNIPPET ALL/;

    return sub {
        my ( $keep, $node ) = @_;
        $node->set_default_handlers;
        return if $keep eq 'ALL';
        my %types = %parse_types;
        delete $types{$keep};

        foreach ( keys %types ) {
            $node->set_handler( $_ => sub { return '' } );
        }
      }
}

sub test_parse_eval_nodes {

    my ( $self, $nodetype, $filternode_cb, $setupargs_cb, $filterlinter_cb ) =
      @_;

    my $mock          = $self->{mock};
    my $test_nodes    = $self->{nodebase}->getNodeWhere( '', $nodetype );
    my $compilable    = $self->{test_execute_nodes};
    my @nodes_to_test = grep { $$compilable{ $_->{node_id} } } @$test_nodes;
    $self->num_tests( scalar(@nodes_to_test) * 6 );

    my $setup_parser = setup_parser();

    foreach (@nodes_to_test) {

        my $node = $self->{nodebase}->getNode($_);

#	next if $$node{title} eq 'editDefaultPermissions';
#	next if $$node{title} eq 'editNodePermissions';

        foreach my $parsetype (qw/TEXT PERL HTMLCODE HTMLSNIPPET ALL/) {

	    $err = [];

            $setup_parser->( $parsetype, $node );

            my @args = ();

            my $ehtml = Everything::HTML->new( { request => $mock } );
	    $ehtml->set_request_node( $mock );

            my $rv = $node->run( { args => \@args, ehtml => $ehtml} );

	    test_node_error( $node, $parsetype );

	    next unless $parsetype eq 'ALL'; #only do HTML tests when we have it all
	    return "Skipping test, install correct HTML::Tidy" if $html_tidy_error;

            $ehtml->get_request->set_always( get_query => CGI->new );

	    ## rerun tests with valid html

            $rv = $node->run( { args => \@args, ehtml => $ehtml, no_cache => 1} );

            my $tidy = HTML::Tidy->new;
            $filterlinter_cb->( $tidy, $node ) if $filterlinter_cb;
            $tidy->parse($$node{title}, $rv);

	    my @filtered_messages = filter_tidy_messages( $tidy );

            is(
                scalar @filtered_messages,
                0,
"...the HTML produced for node '$$node{title}' of type '" . $node->type_title ."' has no errors for parse type $parsetype."
              )
              || do {
                diag $_ . "\n" . $rv foreach @filtered_messages;
              };
        }
    }

}

sub filter_tidy_messages {

    my $tidy = shift;

    return grep { ! (/<head>/ || /DOCTYPE/ || /inserting implicit <body>/ || /inserting missing 'title' element/ || /trimming empty/ || /backsideerrors/i ) } $tidy->messages;

}

1;
