package Everything::Config;

use AppConfig qw/ :argcount /;
use File::Spec;
use File::Basename;
use Everything '$DB';
use Cwd qw/abs_path/;
use Everything::Config::URLDeconstruct;
use strict;
use warnings;

use Moose;
use MooseX::FollowPBP; 

extends 'Everything::Object';

has $_ => ( is => 'rw' ) foreach qw/config file settings_node apache_request deconstruct_modifiers deconstruct_locations nb/;

our $AUTOLOAD;

sub BUILD {
    my $self = shift;

	## initialise some attributes
	$self->set_deconstruct_modifiers( [] );
	$self->set_deconstruct_locations( [] );

        my $config = AppConfig->new;

        foreach (
            qw/database_name|d database_user|u database_password|p database_host|h database_port|P database_type|t database_superuser database_superpassword/
          )
        {
            $config->define( $_, { DEFAULT => '', ARGCOUNT => ARGCOUNT_ONE } );
        }

        $config->define( 'htmlvars',
            { DEFAULT => {}, ARGCOUNT => ARGCOUNT_HASH } );

        $config->define( 'request_modifier_standard',
            { DEFAULT => [], ARGCOUNT => ARGCOUNT_LIST } );

        $config->define( 'request_modifier_code',
            { DEFAULT => [], ARGCOUNT => ARGCOUNT_LIST } );

        $config->define( 'location_schema_nodetype',
            { DEFAULT => [], ARGCOUNT => ARGCOUNT_LIST } );

	$config->define( 'location_code',
			 { DEFAULT => [], ARGCOUNT => ARGCOUNT_LIST } );

        $config->define( 'system_settings_node',
            { DEFAULT => 'system settings', ARGCOUNT => ARGCOUNT_ONE } );

        $config->define('static_nodetypes');

	my $file = $self->get_file;
	my $r = $self->get_apache_request;

	if ( ! $file && $r ) {
	    my $f = $r->dir_config->get('everything-config-file');
	    my $base = Apache2::ServerUtil::server_root();
	    $file = File::Spec->rel2abs( $f, $base );

	}

        ## first the file
        $config->file( $file ) if $file;

	make_db_path_absolute( $config,  ( fileparse( $file ) )[1] ) if $file;

        ## now apache request
        read_apache_request( $config, $r ) if $r;

        $self->set_config( $config );

	$self->handle_location_schemas;
}



sub make_db_path_absolute {

    my ( $config, $base ) = @_;
    return unless $config->get('database_type') eq 'sqlite';
    my $db_name = File::Spec->rel2abs( $config->get('database_name'), $base );
    $config->set('database_name', $db_name );

}

sub read_apache_request {
    my ( $config, $r ) = @_;

    my $apr_table = $r->dir_config;

        foreach (
            qw/database_name database_user database_password database_host database_port database_type/
		) {
	    my $attribute = $_;
	    $attribute =~ s/_/\-/;
	    $attribute = 'everything-' . $attribute;
	    my $value = $apr_table->get( $attribute );
	    $config->set( $_, $value ) if $value;
	}

    make_db_path_absolute( $config, Apache2::ServerUtil::server_root() );

}


sub handle_location_schemas {
     my $self = shift;

     my @request_modifiers = ();
     my @linknode_rules = ();

     my @schemas =  @{ $self->get_config->get('location_schema_nodetype') };

     foreach ( @schemas) {
         my $schema = Everything::Config::URLDeconstruct->new();
         my ( $rule, $nodetype_name ) = split /\s+/, $_;
         $schema->set_schema($rule);
         push @request_modifiers, $schema->make_modify_request;
         push @linknode_rules,
           $schema->create_nodetype_rule( $schema->location_creator,
             $nodetype_name );
     }
     $self->set_deconstruct_modifiers( \@request_modifiers );
     $self->set_deconstruct_locations( \@linknode_rules );
}

sub htmlvars {
    my ($self) = @_;
    my $nb = $self->get_nb || $self->nodebase;

    my $config = $self->get_config;

    my $htmlvars = $config->get('htmlvars');

    my $settings_node =
      $nb->getNode( $config->get('system_settings_node'), 'setting' );
    my $settings = $settings_node->getVars;
    foreach ( keys %$settings ) {
        $$htmlvars{$_} = $$settings{$_};
    }
    return $htmlvars;

}

sub nodebase {
    my ($self)      = @_;
    my $db_name     = $self->get_config->get('database_name');
    my $db_user     = $self->get_config->get('database_user');
    my $db_password = $self->get_config->get('database_password');
    my $db_host     = $self->get_config->get('database_host');
    my $db_type     = $self->get_config->get('database_type');
    my $db_port     = $self->get_config->get('database_port');

    my %options;
    $options{staticNodetypes} = $self->get_config->get('static_nodetypes');
    $options{dbtype}          = $db_type;

    my $db_string = join( ':',
            $self->database_name,     $self->database_user,
            $self->database_password, $self->database_host || '');

    $db_string .= ':' . $self->database_port if $self->database_port;

    my $nb = Everything::initEverything( $db_string, \%options );

    $self->set_nb( $nb );
    return $nb;
}

sub AUTOLOAD {
    my ( $self, @args ) = @_;

    my $func = $AUTOLOAD;
    if ( $func =~ /(database_.*)$/ ) {
        my $attribute_name = $1;
        my $arg_value      = $args[0];
        return $self->db_data( $attribute_name, $arg_value );
    }

    return;
}

sub db_data {
    my ( $self, $data_name, $data ) = @_;
    return $self->get_config->set( $data_name, $data ) if $data;
    return $self->get_config->get($data_name);
}

my %standard_modifiers = (
    css => sub {
        my ( $url, $e ) = @_;
        return unless $url =~ /\/stylesheets\/([0-9]+),([0-9]+)\.css/;
        my $stylesheet = $e->get_nodebase->getNode($1);
        $e->set_response_type('stylesheet');
        $e->set_node($stylesheet);
        1;
    },
    javascript => sub {
        my ( $url, $e ) = @_;
        return unless $url =~ /\/javascript\/([0-9]+)\.js$/;
        my $js_node = $e->get_nodebase->getNode($1);
        $e->set_response_type('javascript');
        $e->set_node($js_node);
        1;
    },

    nodeball_download => sub {
	my ( $url, $e ) = @_;
	return unless $url =~ m{^/repositories/nodeballs/(\d+)};
	my $node = $e->get_nodebase->getNode( $1 );
	return unless ref $node;
	return unless $node->isa( 'Everything::Node::nodeball' );
	$e->set_node( $node );
	$e->set_response_type( 'nodeball' );
	return 1;
    }
);

sub get_standard_modifier { $standard_modifiers{ $_[1] } }

sub request_modifiers {
    my ($self) = @_;
    my @modifiers = ();

    foreach ( @{ $self->get_config->get('request_modifier_standard') } ) {
        my $code = $self->get_standard_modifier($_);
        push @modifiers, $code;
    }

    foreach ( @{ $self->get_config->get('request_modifier_code') } ) {
        my $code = eval $_; ## no critic
	die "Error in request_modifier_code, $@:\n $_" if $@;
        push @modifiers, $code;
    }

    push @modifiers, @{ $self->get_deconstruct_modifiers };

    return \@modifiers;
}

sub node_locations {
    my ( $self ) = @_;
    my @locators = ();

    foreach ( @{ $self->get_config->get('location_code') } ) {
        my $code = eval $_;	## no critic
        push @locators, $code;
    }

    push @locators, @{ $self->get_deconstruct_locations };

    return \@locators;
}

1;

__END__

=head1 NAME

Everything::Config - A package to manage the configuartion variables for the Everything CMS

=cut

=head2 nodebase

A method that returns a nodebase object depending on the state of this configuration object.

=cut

=head2 Configuration file options

The following options may be set in the configuration file:

=over 4

=item database_name

The name of the database. In the case of sqlite, this is a file
name. A relative path may be specified, in which case it is relative
to the location of the config file.

=item database_user

The user to connect to the database

=item database_password

The database password for the above named user

=item database_host

The host

=item database_port

The port to which to connect to the database.

=item database_type

The type of the database we will connect to must be 'mysql', 'sqlite' or 'Pg' without the quotes.

=item static_nodetypes

If this is set, the nodetype nodes are not updated for each request. Defaults to untrue.

=item system_settings_node

The name of the 'setting' type node which contains the system settings, also konwn as HTMLVARS.  Defaults to 'system settings'.

=item htmlvars

These can be set in the form C<htmlvars varname = varvalue>. They are overriden by values in the system settings node.

=item request_modifier_standard

This may appear several times.  It takes the values of the 'standard' request modifiers available.

=item request_modifier_code

This may appear several times.  It must be perl code that can be
correctly evaled. It should be an anonymous subroutine. This
subroutine is passed two arguments: the url being requested and the
Everything::HTTP::Request object to be modified. It should return
true, if it believes it should be the last request_modifier to be
processed.

=item location_schema_nodetype

There may be more than one of these. Using this you may set a location schema of the sort provided for in Everything::URL::Deconstruct, for a nodetype.  It should take the form:

=over

location_schema_nodetype = /schema/type nodetypename

=back

Where C< /schema/type > is the schema and C<nodetypename> is the nodetype.

=item location_code

There may be more than one of these.  This is perl code that must be
able to eval'd as an anonymous subroutine. It will be passed one
argument, a node object, and should return the local url location of
that node, say, for example, C</node/nodeid>.


=back


=head2 Options that can be set in httpd.conf

These can be set in your apache configuration file using the form:

=over

PerlSetVar variable-name variablevalue

=back

=over

=item everything-config-file

Name of the config file. If a relative path, it must be relative to
value set by Apache's ServerRoot directive.

=item everything-database-name

Database name to connect to. If the database type is 'sqlite', this is a file name which may be relative to the Apache directive C<ServerRoot>.

=item everything-database-user

The user that connects to the database

=item everything-database-password

The database password for the above mentioned user

=item everything-database-host

The host

=item everything-database-port

The port

=item everything-database-type

The type of database "mysql", "Pg" or "sqlite".

=back

=head2 Standard Request Modifiers

The following standard request modifiers are available:

=over

=item css

This modifies the Everything::HTTP::Request object if a requested url
is in the form /css/xxx,xxx.css. Where xxx are any number of digits.
It sets the requested_node attribute to the node represented by the
first series of digits and sets the response_type attribute to 'css'.

=item javascript

This modifies the Everything::HTTP::Request object if a requested url
is in the form /javascript/xxx.js. Where xxx are any number of digits.
It sets the requested_node attribute to the node represented by this series of digits and sets the response_type attribute to 'javascript'.

=back


=cut

