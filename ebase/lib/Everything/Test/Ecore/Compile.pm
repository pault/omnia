
package Everything::Test::Ecore::Compile;

use base 'Test::Class';
use Everything::HTML;
use HTML::Lint;
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Carp;

sub startup : Test( startup ) {
    my $self = shift;

    my $nb = $self->{nodebase}
      || croak "Must have a nodebase object to continue, $!.";

    my @nodes_under_test = ();
    foreach (qw/htmlpage htmlsnippet htmlcode container nodelet superdoc opcode/) {
        my $nodes = $nb->getNodeWhere( '', $_ );
        push @nodes_under_test, @$nodes;
    }

    $self->{nodes_under_test} = \@nodes_under_test;

    my $mock  = Test::MockObject->new;
    my $query = CGI->new;
    $query->param( "displaytype", 'display' );
    $Everything::HTML::query = $query;
    $Everything::HTML::USER  = $mock;
    $Everything::HTML::NODE  = $mock;
    $mock->set_true('param');
    $mock->set_always( 'getId', 111 );
    $mock->set_false('isGod');
    $self->{mock} = $mock;

}

sub test_compile_nodes : Tests {
    my $self = shift;

    my @nodes = @{ $self->{nodes_under_test} };
    $self->num_tests( scalar @nodes );

    local *Everything::HTML::logErrors;
    local *Everything::logErrors;
    my $err = '';
    *Everything::HTML::logErrors = sub { $err .= "@_"; };
    *Everything::logErrors       = sub { $err .= "@_"; };
    my %successful_nodes;

    foreach (@nodes) {

        $err = '';
        my $rv = $_->compile( $_->{ $_->get_compilable_field } );
        (
            ok( !$err,
"...'$$_{title}' of type '$$_{type}{title}', $$_{node_id} compiles without error."
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
    $mock->set_true(
        'cacheMethod',  'isOfType',
        'update',       'toXML',
        'setVars',      'addType',
        'sortMenu',     'getDefaultTypePermissions',
        'genPopupMenu', 'addHash'
    );
    $mock->set_false( 'hasAccess', 'isGroup' );
    $mock->set_always( 'getHash', {} );
    $mock->set_always( 'genObject', $mock );
    $mock->set_always( 'getVars', {} );
    $mock->set_always( 'getNodelets', [] );
    $mock->set_always( 'listNodes',   [] );
    $mock->set_always( 'selectLinks', 1 );
    $mock->{node_id} = 123;
    $mock->{to_node} = 456;

    my $test_nodes    = $self->{nodebase}->getNodeWhere( '', 'htmlcode' );
    my $compilable    = $self->{test_execute_nodes};
    my @nodes_to_test = grep { $$compilable{ $_->{node_id} } } @$test_nodes;
    $self->num_tests( scalar(@nodes_to_test) * 2 );

    local *Everything::HTML::logErrors;
    local *Everything::logErrors;

    my $err;

    my $error_code = sub {
        my ( $warn, $error, $text, $node ) = @_;
        $err .= join "\n", $warn, $error, $text, $$node{title};
        $err .= "\n" . '#' x 30;
        $err .= "\n\n";
    };

    *Everything::HTML::logErrors = $error_code;
    *Everything::logErrors       = $error_code;

    local *Everything::HTML::getType;
    local *Everything::HTML::getNode;
    local *Everything::HTML::getPage;
    local *Everything::HTML::newFormObject;

    *Everything::HTML::getType       = sub { $mock };
    *Everything::HTML::getNode       = sub { $mock };
    *Everything::HTML::getPage       = sub { $mock };
    *Everything::HTML::newFormObject = sub { $mock };
    *Everything::HTML::HTMLVARS      = {};

    local *Everything::DB::getTableArray;
    *Everything::DB::getTableArray = sub { [qw/onetable twotable/] };

    local *Everything::HTML::getNodeWhere;
    *Everything::HTML::getNodeWhere =
      sub { [ { node_id => 1 }, { node_id => 2 } ] };

    local *Everything::NodeBase::selectNodeWhere;
    *Everything::NodeBase::selectNodeWhere = sub { return ( [$mock] ) };

    local *Everything::HTML::linkNode;
    *Everything::HTML::linkNode = sub { "alink" };

    my $DB = $self->{nodebase};

    local *Everything::HTML::DB;
    *Everything::HTML::DB = \$DB;

    local *Everything::DB;
    *Everything::DB = \$DB;

    my %args = (
        'displaytable' => [ ['node'] ],
        'formatCols'   => [ [ ['one'] ] ],
    );

    foreach (@nodes_to_test) {
        $err                     = '';
        $Everything::HTML::GNODE = $mock;
        my $node = $self->{nodebase}->getNode($_);
        my @args = ();
        ## setup
        if ( $$node{title} eq 'formatCols' ) {
            @args = ( [ 1, 2, 3 ] );
        }

        my $rv = $node->run( undef, undef, @args );
        ok( !$err,
"...execute node $$node{title}, type $$node{type}{title}, id, $$node{node_id}"
        ) || diag $err;

        my $linter = HTML::Lint->new;
        $linter->only_types( 'HTML::Lint::Error::HELPER',
            'HTML::Lint::Error::FLUFF' )
          if $$node{title} eq 'closeform';
        $linter->parse($rv);
        is(
            scalar $linter->errors,
            0,
"...the HTML produced for node '$$node{title}' of type '$$node{type}{title}' has no errors."
          )
          || do {
            diag $_->as_string foreach $linter->errors;
          };

    }

}


sub test_execute_opcode_nodes : Tests {
    my $self = shift;

    my $mock = $self->{mock};

    $mock->{DB}    = $mock;
    $mock->{cache} = $mock;
    $mock->set_true(
        'cacheMethod',  'isOfType',
        'update',       'toXML',
        'setVars',      'addType',
        'sortMenu',     'getDefaultTypePermissions',
        'genPopupMenu', 'addHash'
    );
    $mock->set_false( 'hasAccess', 'isGroup' );
    $mock->set_always( 'getHash', {} );
    $mock->set_always( 'genObject', $mock );
    $mock->set_always( 'getVars', {} );
    $mock->set_always( 'getNodelets', [] );
    $mock->set_always( 'listNodes',   [] );
    $mock->set_always( 'selectLinks', 1 );
    $mock->{node_id} = 123;
    $mock->{to_node} = 456;

    my $test_nodes    = $self->{nodebase}->getNodeWhere( '', 'opcode' );
    my $compilable    = $self->{test_execute_nodes};
    my @nodes_to_test = grep { $$compilable{ $_->{node_id} } } @$test_nodes;
    $self->num_tests( scalar(@nodes_to_test) );

    local *Everything::HTML::logErrors;
    local *Everything::logErrors;

    my $err;

    my $error_code = sub {
        my ( $warn, $error, $text, $node ) = @_;
        $err .= join "\n", $warn, $error, $text, $$node{title};
        $err .= "\n" . '#' x 30;
        $err .= "\n\n";
    };

    *Everything::HTML::logErrors = $error_code;
    *Everything::logErrors       = $error_code;

    local *Everything::HTML::getType;
    local *Everything::HTML::getNode;
    local *Everything::HTML::getPage;
    local *Everything::HTML::newFormObject;

    *Everything::HTML::getType       = sub { $mock };
    *Everything::HTML::getNode       = sub { $mock };
    *Everything::HTML::getPage       = sub { $mock };
    *Everything::HTML::newFormObject = sub { $mock };
    *Everything::HTML::HTMLVARS      = {};

    local *Everything::DB::getTableArray;
    *Everything::DB::getTableArray = sub { [qw/onetable twotable/] };

    local *Everything::HTML::getNodeWhere;
    *Everything::HTML::getNodeWhere =
      sub { [ { node_id => 1 }, { node_id => 2 } ] };

    local *Everything::NodeBase::selectNodeWhere;
    *Everything::NodeBase::selectNodeWhere = sub { return ( [$mock] ) };

    local *Everything::HTML::linkNode;
    *Everything::HTML::linkNode = sub { "alink" };

    my $DB = $self->{nodebase};

    local *Everything::HTML::DB;
    *Everything::HTML::DB = \$DB;

    local *Everything::DB;
    *Everything::DB = \$DB;

    my %args = (
        'displaytable' => [ ['node'] ],
        'formatCols'   => [ [ ['one'] ] ],
    );

    foreach (@nodes_to_test) {
        $err                     = '';
        $Everything::HTML::GNODE = $mock;
        my $node = $self->{nodebase}->getNode($_);
        my @args = ();
        ## setup
        if ( $$node{title} eq 'formatCols' ) {
            @args = ( [ 1, 2, 3 ] );
        }

        my $rv = $node->run( undef, undef, @args );
        ok( !$err,
"...execute node $$node{title}, type $$node{type}{title}, id, $$node{node_id}"
        ) || diag $err;
    }
}

sub test_execute_htmlpage_nodes : Tests {
    my $self = shift;

    my $mock = $self->{mock};

    $mock->{DB}    = $mock;
    $mock->{cache} = $mock;
    $mock->set_true(
        'cacheMethod',  'isOfType',
        'update',       'toXML',
        'setVars',      'addType',
        'sortMenu',     'getDefaultTypePermissions',
        'genPopupMenu', 'addHash'
    );
    $mock->set_false( 'hasAccess', 'isGroup' );
    $mock->set_always( 'getHash', {} );
    $mock->set_always( 'genObject', $mock );
    $mock->set_always( 'getVars', {} );
    $mock->set_always( 'getNodelets', [] );
    $mock->set_always( 'listNodes',   [] );
    $mock->set_always( 'selectLinks', [] );
    $mock->set_always( 'run', '<p>mock compliant html</p>');
    $mock->{node_id} = 123;
    $mock->{to_node} = 456;

    #    local $SIG{__DIE__} = \&Carp::confess;
    my $test_nodes    = $self->{nodebase}->getNodeWhere( '', 'htmlpage' );
    my $compilable    = $self->{test_execute_nodes};
    my @nodes_to_test = grep { $$compilable{ $_->{node_id} } } @$test_nodes;

    ## ten tests for htmlpage, but xml node page we do not test for
    ## well-formedness of html so we take away 5.
    $self->num_tests( scalar(@nodes_to_test) * 10 - 5 );

    local *Everything::HTML::logErrors;
    local *Everything::logErrors;

    my $err;

    my $error_code = sub {
        my ( $warn, $error, $text, $node ) = @_;
        $err .= join "\n", $warn, $error, $text, $$node{title};
        $err .= "\n" . '#' x 30;
        $err .= "\n\n";
    };

    *Everything::HTML::logErrors = $error_code;
    *Everything::logErrors       = $error_code;

    my $setup_parser = setup_parser();

    foreach (@nodes_to_test) {

        $err = '';

        my $node = $self->{nodebase}->getNode($_);

        diag "\nNow testing 'htmlpage' named '$$node{title}'.\n\n";

        $Everything::HTML::DB = $self->{nodebase};
        my @args = ();

        foreach (qw/TEXT PERL HTMLCODE HTMLSNIPPET ALL/) {

            $setup_parser->( $_, $node );

            if (   ( $node->{title} eq 'location display page' )
                && ( $$node{type}{title} eq 'htmlpage' ) )
            {
                my $nodes = $self->{nodebase}->getNodeWhere( '', 'location' );
                my $testnode = $nodes->[0];
                $Everything::HTML::GNODE = $testnode;
                $Everything::HTML::NODE  = $testnode;

            }
            elsif ( $$node{title} =~ /dbtable (?:edit|display) page/ ) {
                my $nodes = $self->{nodebase}->getNodeWhere( '', 'dbtable' );
                my $testnode = $nodes->[0];
                $Everything::HTML::GNODE = $testnode;
                $Everything::HTML::NODE  = $testnode;

            }
            elsif ( $$node{title} =~ /themesetting\s+(?:edit|display)\s+page/ )
            {
                my $nodes =
                  $self->{nodebase}->getNodeWhere( '', 'themesetting' );
                my $testnode = $nodes->[0];
                $Everything::HTML::GNODE = $testnode;
                $Everything::HTML::NODE  = $testnode;

            }
            elsif ( $$node{title} =~ /nodegroup edit.+page/ ) {
                my $nodes = $self->{nodebase}->getNodeWhere( '', 'nodegroup' );
                my $testnode = $nodes->[0];
                $Everything::HTML::GNODE = $testnode;
                $Everything::HTML::NODE  = $testnode;

            }
            elsif ( $$node{title} eq 'user edit page' ) {
                my $nodes = $self->{nodebase}->getNodeWhere( '', 'user' );
                my $testnode = $nodes->[0];
                $Everything::HTML::GNODE = $testnode;
                $Everything::HTML::NODE  = $testnode;

            }
            elsif ( $$node{title} =~ /nodeball (?:edit|display) page/ ) {
                my $nodes = $self->{nodebase}->getNodeWhere( '', 'nodeball' );
                my $testnode = $nodes->[0];
                $Everything::HTML::GNODE = $testnode;
                $Everything::HTML::NODE  = $testnode;

            }
            elsif ( $$node{title} =~ /nodelet (?:edit|display) page/ ) {
                my $nodes = $self->{nodebase}->getNodeWhere( '', 'nodelet' );
                my $testnode = $nodes->[0];
                $Everything::HTML::GNODE = $testnode;
                $Everything::HTML::NODE  = $testnode;

            }
            elsif ( $$node{title} =~ /^setting\s+(?:edit|display)\s+page/ ) {
                my $nodes = $self->{nodebase}->getNodeWhere( '', 'setting' );
                my $testnode = $nodes->[0];
                $Everything::HTML::GNODE = $testnode;
                $Everything::HTML::NODE  = $testnode;

            }
            elsif ( $$node{title} eq 'nodeball edit page' ) {
                my $nodes = $self->{nodebase}->getNodeWhere( '', 'nodeball' );
                my $testnode = $nodes->[0];
                $Everything::HTML::GNODE = $testnode;
                $Everything::HTML::NODE  = $testnode;

            }
            elsif ( $$node{title} eq 'nodetype display page' ) {
                my $nodes = $self->{nodebase}->getNodeWhere( '', 'nodetype' );
                my $testnode = $nodes->[0];
                $Everything::HTML::GNODE = $testnode;
                $Everything::HTML::NODE  = $testnode;

            }
            elsif ( $$node{title} eq 'workspace display page' ) {

                $Everything::HTML::GNODE = $mock;
                $Everything::HTML::NODE  = $mock;

	    }
            elsif ( $$node{title} eq 'superdoc display page' ) {

                $Everything::HTML::GNODE = $mock;
                $Everything::HTML::NODE  = $mock;

            }
            else {
                $Everything::HTML::GNODE = $node;
                $Everything::HTML::NODE  = $node;
            }

            my $rv = $node->run( undef, 'nocache', @args );
            ok( !$err,
"...execute node $$node{title}, type $$node{type}{title}, id, $$node{node_id} for parser type $_"
            ) || diag $err;

            ## produces text/plain, not html
            next if $$node{title} eq 'node xml page';
            my $linter = HTML::Lint->new;
            $linter->clear_errors;

            $linter->parse($rv);
            is(
                scalar $linter->errors,
                0,
"...the HTML produced for node '$$node{title}' of type '$$node{type}{title}' has no errors for parser type $_."
              )
              || do {
                diag $_->as_string foreach $linter->errors;
                diag $rv;
              };
        }
    }
}



sub test_execute_htmlsnippet_nodes : Tests {

    my $self = shift;

    my $mock = $self->{mock};

    my $test_nodes    = $self->{nodebase}->getNodeWhere( '', 'htmlsnippet' );
    my $compilable    = $self->{test_execute_nodes};
    my @nodes_to_test = grep { $$compilable{$_->{node_id}} } @$test_nodes;
    $self->num_tests( scalar( @nodes_to_test ) * 10 );

    local *Everything::HTML::logErrors;
    local *Everything::logErrors;

    my $err;

    my $error_code = sub {
        my ( $warn, $error, $text, $node ) = @_;
        $err .= join "\n", $warn, $error, $text, $$node{title};
        $err .= "\n" . '#' x 30;
        $err .= "\n\n";
    };

    *Everything::HTML::logErrors = $error_code;
    *Everything::logErrors       = $error_code;

    local *Everything::HTML::getType;
    local *Everything::HTML::getNode;
    local *Everything::HTML::getPage;
    local *Everything::HTML::newFormObject;

    *Everything::HTML::getType       = sub { $mock };
    *Everything::HTML::getNode       = sub { $mock };
    *Everything::HTML::getPage       = sub { $mock };
    *Everything::HTML::newFormObject = sub { $mock };
    *Everything::HTML::HTMLVARS      = {};

    local *Everything::DB::getTableArray;
    *Everything::DB::getTableArray = sub { [qw/onetable twotable/] };

    local *Everything::HTML::getNodeWhere;
    *Everything::HTML::getNodeWhere = sub { [ { node_id => 1}, { node_id => 2 } ]};

    local *Everything::NodeBase::selectNodeWhere;
    *Everything::NodeBase::selectNodeWhere = sub { return ( [ $mock ] ) };

    local *Everything::HTML::linkNode;
    *Everything::HTML::linkNode = sub { "alink" };

    my $DB = $self->{nodebase};

    local *Everything::HTML::DB;
    *Everything::HTML::DB = \$DB;

    local *Everything::DB;
    *Everything::DB = \$DB;

    my %args = (
        'displaytable' => [ ['node'] ],
        'formatCols'   => [ [ ['one'] ] ],
    );

    my $setup_parser = setup_parser();

    foreach ( @nodes_to_test ) {
        $err                     = '';
        $Everything::HTML::GNODE = $mock;
	my $node = $self->{nodebase}->getNode( $_ );

	diag "\nNow testing htmlsnippet named '$$node{title}'.\n\n";

	foreach my $parsetype (qw/TEXT PERL HTMLCODE HTMLSNIPPET ALL/) {

	    $setup_parser->( $parsetype, $node );

	my @args = ();

        my $rv =
          $node->run( undef, undef, @args );
        ok( !$err,
"...execute node $$node{title}, type $$node{type}{title}, id, $$node{node_id}"
        ) || diag $err;



	my $linter = HTML::Lint->new;
	$linter->only_types( 'HTML::Lint::Error::HELPER', 'HTML::Lint::Error::FLUFF') if $$node{title} eq 'backsideErrors';
	$linter->parse( $rv );
	is( scalar $linter->errors, 0, "...the HTML produced for node '$$node{title}' of type '$$node{type}{title}' has no errors for parse type $parsetype.")
	  ||
	    do {
		diag $_->as_string foreach $linter->errors;
	    };
    }
    }

}


sub test_execute_container_nodes : Tests {

    my $self = shift;

    my $mock = $self->{mock};

    my $test_nodes    = $self->{nodebase}->getNodeWhere( '', 'container' );
    my $compilable    = $self->{test_execute_nodes};
    my @nodes_to_test = grep { $$compilable{$_->{node_id}} } @$test_nodes;
    $self->num_tests( scalar( @nodes_to_test ) * 10 );

    local *Everything::HTML::logErrors;
    local *Everything::logErrors;

    my $err;

    my $error_code = sub {
        my ( $warn, $error, $text, $node ) = @_;
        $err .= join "\n", $warn, $error, $text, $$node{title};
        $err .= "\n" . '#' x 30;
        $err .= "\n\n";
    };

    *Everything::HTML::logErrors = $error_code;
    *Everything::logErrors       = $error_code;

    local *Everything::HTML::getType;
    local *Everything::HTML::getNode;
    local *Everything::HTML::getPage;
    local *Everything::HTML::newFormObject;

    *Everything::HTML::getType       = sub { $mock };
    *Everything::HTML::getNode       = sub { $mock };
    *Everything::HTML::getPage       = sub { $mock };
    *Everything::HTML::newFormObject = sub { $mock };
    *Everything::HTML::HTMLVARS      = {};

    local *Everything::DB::getTableArray;
    *Everything::DB::getTableArray = sub { [qw/onetable twotable/] };

    local *Everything::HTML::getNodeWhere;
    *Everything::HTML::getNodeWhere = sub { [ { node_id => 1}, { node_id => 2 } ]};

    local *Everything::NodeBase::selectNodeWhere;
    *Everything::NodeBase::selectNodeWhere = sub { return ( [ $mock ] ) };

    local *Everything::HTML::linkNode;
    *Everything::HTML::linkNode = sub { "alink" };

    my $DB = $self->{nodebase};

    local *Everything::HTML::DB;
    *Everything::HTML::DB = \$DB;

    local *Everything::DB;
    *Everything::DB = \$DB;

    my %args = (
        'displaytable' => [ ['node'] ],
        'formatCols'   => [ [ ['one'] ] ],
    );

    my $setup_parser = setup_parser();

    foreach ( @nodes_to_test ) {
        $err                     = '';
        $Everything::HTML::GNODE = $mock;
	my $node = $self->{nodebase}->getNode( $_ );

	diag "\nNow testing htmlsnippet named '$$node{title}'.\n\n";

	foreach my $parsetype (qw/TEXT PERL HTMLCODE HTMLSNIPPET ALL/) {

	    $setup_parser->( $parsetype, $node );

	my @args = ();

        my $rv =
          $node->run( undef, undef, @args );
        ok( !$err,
"...execute node $$node{title}, type $$node{type}{title}, id, $$node{node_id}"
        ) || diag $err;



	    my $linter = HTML::Lint->new;
	    
	    ## to deal with <body> is constructed.
	    $linter->only_types( 'HTML::Lint::Error::HELPER', 'HTML::Lint::Error::FLUFF') if $$node{title} eq 'stdcontainer';

	$linter->parse( $rv );
	is( scalar $linter->errors, 0, "...the HTML produced for node '$$node{title}' of type '$$node{type}{title}' has no errors for parse type $parsetype.")
	  ||
	    do {
		diag $_->as_string foreach $linter->errors;
	    };
    }
    }

}


sub test_execute_nodelet_nodes : Tests {

    my $self = shift;

    my $mock = $self->{mock};

    my $test_nodes    = $self->{nodebase}->getNodeWhere( '', 'nodelet' );
    my $compilable    = $self->{test_execute_nodes};
    my @nodes_to_test = grep { $$compilable{$_->{node_id}} } @$test_nodes;
    $self->num_tests( scalar( @nodes_to_test ) * 10 );

    local *Everything::HTML::logErrors;
    local *Everything::logErrors;

    my $err;

    my $error_code = sub {
        my ( $warn, $error, $text, $node ) = @_;
        $err .= join "\n", $warn, $error, $text, $$node{title};
        $err .= "\n" . '#' x 30;
        $err .= "\n\n";
    };

    $mock->set_true('hasAccess');
    $mock->set_always( run => '<p>mock compliant html</p>' );

    *Everything::HTML::logErrors = $error_code;
    *Everything::logErrors       = $error_code;

    local *Everything::HTML::getType;
    local *Everything::HTML::getNode;
    local *Everything::HTML::getPage;
    local *Everything::HTML::newFormObject;

    *Everything::HTML::getType       = sub { $mock };
    *Everything::HTML::getNode       = sub { $mock };
    *Everything::HTML::getPage       = sub { $mock };
    *Everything::HTML::newFormObject = sub { $mock };
    *Everything::HTML::HTMLVARS      = {};

    local *Everything::DB::getTableArray;
    *Everything::DB::getTableArray = sub { [qw/onetable twotable/] };

    local *Everything::HTML::getNodeWhere;
    *Everything::HTML::getNodeWhere = sub { [ $mock, $mock ]};

    local *Everything::NodeBase::selectNodeWhere;
    *Everything::NodeBase::selectNodeWhere = sub { return ( [ $mock ] ) };

    local *Everything::HTML::linkNode;
    *Everything::HTML::linkNode = sub { "alink" };

    my $DB = $self->{nodebase};

    local *Everything::HTML::DB;
    *Everything::HTML::DB = \$DB;

    local *Everything::DB;
    *Everything::DB = \$DB;

    my %args = (
        'displaytable' => [ ['node'] ],
        'formatCols'   => [ [ ['one'] ] ],
    );

    my $setup_parser = setup_parser();

    foreach ( @nodes_to_test ) {
        $err                     = '';
        $Everything::HTML::GNODE = $mock;
	my $node = $self->{nodebase}->getNode( $_ );

	diag "\nNow testing htmlsnippet named '$$node{title}'.\n\n";

	foreach my $parsetype (qw/TEXT PERL HTMLCODE HTMLSNIPPET ALL/) {

	    $setup_parser->( $parsetype, $node );

	my @args = ();

        my $rv =
          $node->run( undef, undef, @args );
        ok( !$err,
"...execute node $$node{title}, type $$node{type}{title}, id, $$node{node_id}"
        ) || diag $err;



	    my $linter = HTML::Lint->new;

	$linter->parse( $rv );
	is( scalar $linter->errors, 0, "...the HTML produced for node '$$node{title}' of type '$$node{type}{title}' has no errors for parse type $parsetype.")
	  ||
	    do {
		diag $_->as_string foreach $linter->errors;
	    };
    }
    }

}


sub test_execute_superdoc_nodes : Tests {

    my $self = shift;

    my $mock = $self->{mock};

    $mock->set_true('hasTypeAccess');
    $mock->set_always('getTableArray', ['node']);

    my $test_nodes    = $self->{nodebase}->getNodeWhere( '', 'superdoc' );

    my $compilable    = $self->{test_execute_nodes};
    my @nodes_to_test = grep { $$compilable{$_->{node_id}} } @$test_nodes;
    $self->num_tests( scalar( @nodes_to_test ) * 10 );

    local *Everything::HTML::logErrors;
    local *Everything::logErrors;

    my $err;

    my $error_code = sub {
        my ( $warn, $error, $text, $node ) = @_;
        $err .= join "\n", $warn, $error, $text, $$node{title};
        $err .= "\n" . '#' x 30;
        $err .= "\n\n";
    };

    $mock->set_true('hasAccess');
    $mock->set_always( run => '<p>mock compliant html</p>' );

    *Everything::HTML::logErrors = $error_code;
    *Everything::logErrors       = $error_code;

    local *Everything::HTML::getType;
    local *Everything::HTML::getNode;
    local *Everything::HTML::getPage;
    local *Everything::HTML::newFormObject;

    *Everything::HTML::getType       = sub { $mock };
    *Everything::HTML::getNode       = sub { $mock };
    *Everything::HTML::getPage       = sub { $mock };
    *Everything::HTML::newFormObject = sub { $mock };
    *Everything::HTML::HTMLVARS      = {};

    local *Everything::DB::getTableArray;
    *Everything::DB::getTableArray = sub { [qw/onetable twotable/] };

    local *Everything::HTML::getNodeWhere;
    *Everything::HTML::getNodeWhere = sub { [ $mock, $mock ]};

    local *Everything::NodeBase::selectNodeWhere;
    *Everything::NodeBase::selectNodeWhere = sub { return ( [ $mock ] ) };

    local *Everything::HTML::linkNode;
    *Everything::HTML::linkNode = sub { "alink" };

    my $DB = $self->{nodebase};

    local *Everything::HTML::DB;
    *Everything::HTML::DB = \$DB;

    local *Everything::DB;
    *Everything::DB = \$DB;

    my %args = (
        'displaytable' => [ ['node'] ],
        'formatCols'   => [ [ ['one'] ] ],
    );

    my $setup_parser = setup_parser();

    foreach ( @nodes_to_test ) {
        $err                     = '';
        $Everything::HTML::GNODE = $mock;
	my $node = $self->{nodebase}->getNode( $_ );

	diag "\nNow testing htmlsnippet named '$$node{title}'.\n\n";

	foreach my $parsetype (qw/TEXT PERL HTMLCODE HTMLSNIPPET ALL/) {

	    $setup_parser->( $parsetype, $node );

	my @args = ();

        my $rv =
          $node->run( undef, undef, @args );
        ok( !$err,
"...execute node $$node{title}, type $$node{type}{title}, id, $$node{node_id}"
        ) || diag $err;



	    my $linter = HTML::Lint->new;

	$linter->parse( $rv );
	is( scalar $linter->errors, 0, "...the HTML produced for node '$$node{title}' of type '$$node{type}{title}' has no errors for parse type $parsetype.")
	  ||
	    do {
		diag $_->as_string foreach $linter->errors;
	    };
    }
    }

}

sub setup_parser {

    my %parse_types = map { $_ => 1} qw/TEXT PERL HTMLCODE HTMLSNIPPET ALL/;

      return sub {
	  my ( $keep, $node ) = @_;
	  $node->set_default_handlers;
	  return if $keep eq 'ALL';
	  my %types = %parse_types;
	  delete $types{$keep};

	  foreach (keys %types) {
	      $node->set_handler( $_ => sub { return ''} );
	  }
      }
}

1;
