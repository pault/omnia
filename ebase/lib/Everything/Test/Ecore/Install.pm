
package Everything::Test::Ecore::Install;

use Everything::NodeBase;
use Everything::Storage::Nodeball;
use Carp qw/confess cluck croak/;
use Test::More;
use base 'Test::Class';

use strict;
use warnings;

sub startup : Test( startup ) {
    my $self        = shift;
    my $stored_ball = Everything::Storage::Nodeball->new;
    $stored_ball->set_nodebase( $self->{nb} );
    $stored_ball->set_nodeball( $self->{nodeball} );

    $self->{ball} = $stored_ball;

    #    $self->install_basenodes; # base nodes always in test db
}

sub test_10_sql_tables : Test(1) {
    my $self = shift;

    my %expected_tables =
      map { $_ => 1 }
      qw/version mail image container node symlink nodemethod nodetype typeversion nodelet revision workspace htmlcode themesetting htmlpage nodegroup javascript setting document user links/;

    $self->{ball}->insert_sql_tables;
    my %actual_tables = map { $_ => 1 } $self->{nb}->{storage}->list_tables;

    is_deeply( \%actual_tables, \%expected_tables,
        '...testing all tables we expected are there.' )
      || $self->BAILOUT("Can't proceed without tables installed");

}

sub test_11_base_nodes : Test(3) {

    my $self = shift;

    my $nb = $self->{nb};

    my $ball  = $self->{ball};
    my $nodes = $nb->getNodeWhere( '', 'nodetype', 'node_id' );

    my @get_these = ();
    push @get_these, [ $$_{title}, $$_{type}{title} ] foreach @$nodes;

    my $select = sub {
        my $xmlnode  = shift;
        my $nodetype = $xmlnode->get_nodetype;
        my $title    = $xmlnode->get_title;
        foreach (@get_these) {
            if ( $title eq $_->[0] && $nodetype eq $_->[1] ) {
                return 1;
            }
        }

        return;
    };
    my $node_iterator = $ball->make_node_iterator($select);

    while ( my $xmlnode = $node_iterator->() ) {
        my $title = $xmlnode->get_title;
        my $type  = $xmlnode->get_nodetype;

        my $node = $nb->getNode( $title, $type );

        foreach ( @{ $xmlnode->get_attributes } ) {

            if ( $_->get_type eq 'literal_value' ) {
                $$node{ $_->get_name } = $_->get_content;
            }
            elsif ( $_->get_type eq 'noderef' ) {

                my ($ref_name) = split /,/, $_->get_type_nodetype;
                my $ref_node = $nb->getNode( $_->get_content, $ref_name );

                $$node{ $_->get_name } = $ref_node ? $ref_node->{node_id} : -1;
            }
        }

        ok( $node->update( -1, 'nomodify' ),
            "...base node, $$node{title}, has been updated" );
    }
    $nb->rebuildNodetypeModules();

}

sub test_20_nodetypes : Test(1) {

    my $self = shift;

    my $nb            = $self->{nb};
    my $nodetypes_dir = $self->{ball}->get_nodeball_dir . '/nodes/nodetype';

    $Everything::DB = $nb;
    my $errors;
    local *Everything::logErrors;
    *Everything::logErrors = sub { $errors = "@_"; };

    $self->{ball}->install_xml_nodetype_nodes;
    print "Fixing references...\n";
    $self->{ball}->fix_node_references(1);
    print "   - Done.\n";


    my %all_types =
      map { $_ => 1 } $self->{nb}->{storage}->fetch_all_nodetype_names;

    my %xml_types = ();
    my $iterator  = $self->{ball}->make_node_iterator(
        sub {
            my $xmlnode = shift;
            if ( $xmlnode->get_nodetype eq 'nodetype' ) {
                $xml_types{ $xmlnode->get_title } = 1;
                return 1;
            }
            return;
        }
    );
    while ( $iterator->() ) {
    }
    is_deeply( \%all_types, \%xml_types, '...28 nodetypes are installed.' );

}

sub test_30_install_nodes : Test(1) {

    my $self   = shift;
    my $errors = '';

    local *Everything::logErrors;
    *Everything::logErrors = sub { confess("@_") };

    my $node_iterator = $self->{ball}->make_node_iterator;

    my $number_of_nodes = 0;
    while ( $node_iterator->() ) {
	$number_of_nodes++;
    }

    $number_of_nodes++; ## add one for the nodeball itself

    $self->{number_of_nodes} = $number_of_nodes;

    $self->{ball}->install_xml_nodes(
        sub {
            my $xmlnode = shift;
            return 1 unless $xmlnode->get_nodetype eq 'nodetype';
            return;
        }
    );

    ## the nodeball isn't part of itself.
    $self->{ball}->install_nodeball_description;
    $self->{ball}->fix_node_references(1);
    my $nodes = $self->{nb}->selectNodeWhere();

    is( @$nodes, $number_of_nodes, "...should be $number_of_nodes nodes installed." );
}

sub test_40_verify_nodes : Tests {
    my $self = shift;
    my $nb   = $self->{nb};

    $self->num_tests( $self->{number_of_nodes} );

    $nb->resetNodeCache();

    my $ball          = $self->{ball};
    my $node_iterator = $ball->make_node_iterator;

    while ( my $xmlnode = $node_iterator->() ) {
        my $title = $xmlnode->get_title;
        my $type  = $xmlnode->get_nodetype;

        my $node = $nb->getNode( $title, $type );

        ok( $node, "...test existence of '$title', '$type'" );

    }

}

sub test_50_verify_nodes_attributes : Tests {
    my $self = shift;
    my $nb   = $self->{nb};

    my $ball          = $self->{ball};
    my $node_iterator = $ball->make_node_iterator;

    my $total_tests = 0;
    while ( my $xmlnode = $node_iterator->() ) {
        my $atts = $xmlnode->get_attributes;
	$total_tests += scalar(@$atts);

    }

    $self->num_tests($total_tests);

    ## now run attribute tests
    $node_iterator = $ball->make_node_iterator;

    while ( my $xmlnode = $node_iterator->() ) {
        my $atts = $xmlnode->get_attributes;

        my $node_title = $xmlnode->get_title;
        my $node_type  = $xmlnode->get_nodetype;

        my $node = $nb->getNode( $node_title, $node_type );

        foreach (@$atts) {
            my $att_name = $_->get_name;

            my $att_type = $_->get_type;

            if ( $att_type eq 'literal_value' ) {

                ## the line below makes undef an empty string to deal
                ## with the way database tables are created at the
                ## moment.
                my $content = defined $_->get_content ? $_->get_content : '';

                is( $node->{$att_name}, $content,
"...test node: '$node_title' of type '$node_type', attribute '$att_name'."
                );
            }
            else {

                my ($type_name) = split /,/, $_->get_type_nodetype;
                my $node_name = $_->get_content;

                my $wanted = $nb->getNode( $node_name, $type_name );

                is( $node->{$att_name}, $wanted->{node_id},
"... node '$node_title', attribute '$att_name' references '$$wanted{title}'."
                );

            }

        }

    }

}

sub test_60_verify_node_vars : Tests {
    my $self = shift;
    my $nb   = $self->{nb};

    my $ball = $self->{ball};

    my $vars_selector = sub { return 1 if @{ $_[0]->get_vars }; return; };

    my $node_iterator = $ball->make_node_iterator($vars_selector);

    my $total_vars = 0;
    while ( my $xmlnode = $node_iterator->() ) {
        my $vars = $xmlnode->get_vars;
        $total_vars += scalar(@$vars);

    }

    $self->num_tests($total_vars);

    ## now run attribute tests
    $node_iterator = $ball->make_node_iterator($vars_selector);

    while ( my $xmlnode = $node_iterator->() ) {
        my $vars = $xmlnode->get_vars;

        my $node_title = $xmlnode->get_title;
        my $node_type  = $xmlnode->get_nodetype;

        my $node    = $nb->getNode( $node_title, $node_type );
        my $db_vars = $node->getVars;

        foreach (@$vars) {
            my $var_name = $_->get_name;

            my $var_type = $_->get_type;

            if ( $var_type eq 'literal_value' ) {

                ## the line below makes undef an empty string to deal
                ## with the way database tables are created at the
                ## moment.
                my $content = defined $_->get_content ? $_->get_content : '';

                is( $db_vars->{$var_name}, $content,
"...test node: '$node_title' of type '$node_type', var '$var_name'."
                );
            }
            else {

                my ($type_name) = split /,/, $_->get_type_nodetype;
                my $node_name = $_->get_content;

                my $wanted = $nb->getNode( $node_name, $type_name );

                is( $db_vars->{$var_name}, $wanted->{node_id},
"... node '$node_title', var '$var_name' references '$$wanted{title}'."
                );

            }

        }

    }

}

sub test_70_verify_nodegroup_members : Tests {
    my $self = shift;
    my $nb   = $self->{nb};

    my $ball = $self->{ball};

    my $group_selector =
      sub { return 1 if @{ $_[0]->get_group_members }; return; };

    my $node_iterator = $ball->make_node_iterator($group_selector);

    my $total_members = 0;
    while ( my $xmlnode = $node_iterator->() ) {
        my $members = $xmlnode->get_group_members;
        $total_members += scalar(@$members);

    }

    $self->num_tests($total_members);

    ## now run attribute tests
    $node_iterator = $ball->make_node_iterator($group_selector);

    while ( my $xmlnode = $node_iterator->() ) {
        my $members = $xmlnode->get_group_members;

        my $node_title = $xmlnode->get_title;
        my $node_type  = $xmlnode->get_nodetype;

        my $node = $nb->getNode( $node_title, $node_type );
        my %db_members = map { $_ => 1 } @{ $node->selectGroupArray };

        foreach (@$members) {

            my ($type_name) = split /,/, $_->get_type_nodetype;
            my $node_name = $_->get_name;

            my $wanted = $nb->getNode( $node_name, $type_name );

            ok(
                $db_members{ $wanted->{node_id} },
                "... node '$node_title',contains group member '$$wanted{title}."
            );

        }

    }

}

1;
