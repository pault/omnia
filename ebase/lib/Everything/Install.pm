package Everything::Install;

use Everything::CmdLine qw/abs_path/;
use Everything::NodeBase::Cached;
use Template;

use Moose;
use MooseX::FollowPBP; 

extends 'Everything::Object';

has $_ => ( is => 'rw' ) foreach qw/nodebase nodeball db_name db_rootuser db_rootpass db_user db_pass db_host db_port apache_user data_dir web_dir web_user web_group install_core modify_apache_conf/;

sub create_storage {
    my ( $self, $opts ) = @_;

    my $storage_class = 'Everything::DB::' . $$opts{type};

    ( my $file = $storage_class ) =~ s/::/\//g;
    $file .= '.pm';
    require $file;

    my $storage = $storage_class->new();

    $storage->create_database( $$opts{database}, $$opts{db_rootuser},
        $$opts{db_rootpass}, $$opts{host}, $$opts{port} );

    $storage->grant_privileges( $$opts{database}, $$opts{user},
        $$opts{password}, $$opts{host}, $$opts{port} );

    $storage->install_base_tables;

    $storage->install_base_nodes;

    my $nb = Everything::NodeBase::Cached->new(
        join( ':',
            $$opts{database}, $$opts{user}, $$opts{password}, $$opts{host}, $$opts{ port } ),
        1,
        $$opts{type}
    ) || die "Can't get Nodebase, $!";
    $self->get_nodeball->set_nodebase($nb) if $self->get_nodeball;

    $Everything::DB = $nb; ## hack until Everything/XML.pm is fixed

    $self->set_nodebase($nb);
}

sub install_sql_tables {
    my $self = shift;
    $self->get_nodeball->insert_sql_tables;

}

sub install_nodetypes {

    my $self = shift;
    my $ball = $self->get_nodeball;
    $ball->install_xml_nodetype_nodes;
}

sub update_existing_nodes {

    my $self = shift;
    my $nb   = $self->get_nodebase;

    my $ball = $self->get_nodeball;
    my $nodes = $nb->getNodeWhere( '', 'nodetype', 'node_id' );

    my @get_these = ();
    push @get_these, [ $_->get_title, $_->type_title ] foreach @$nodes;

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

        $node->update( -1, 'nomodify' );
    }
    $nb->rebuildNodetypeModules();

    1;
}

sub install_nodes {

    my $self = shift;

    my $ball = $self->get_nodeball;

    $ball->install_xml_nodes_basic(
        sub {
            my $xmlnode = shift;
            return 1 unless $xmlnode->get_nodetype eq 'nodetype';
            return;
        }
    );

    $self->get_nodebase->{cache}->flushCache;

    $ball->install_xml_nodes_final(        sub {
            my $xmlnode = shift;
            if ( $xmlnode->get_nodetype eq 'nodetype' ) {
		return 1;
	    }
            return;
        }
);

    $self->get_nodebase->rebuildNodetypeModules;

    $ball->install_xml_nodes_final(        sub {
            my $xmlnode = shift;
            return 1 unless $xmlnode->get_nodetype eq 'nodetype';
            return;
        }
);

    ## the nodeball isn't part of itself.
    $ball->install_nodeball_description;


}

sub check_everything_dir {
    my ( $self, $dir ) = @_;

    return unless $dir;
    my @reqddirs = qw(web images);

    foreach (@reqddirs) {

        return 0 unless -d File::Spec->catdir( $dir, $_ );
    }
    return 1;
}


sub guess_everything_dir {
    my ($self, $edir) = @_;

    # they might have specified it in options
    return if check_everything_dir( $edir );

    # this file comes in the everything/bin directory.  Take the dir
    # of this script and try the parent directory
    my $script = $0;
    $script =~ s/\/[^\/]+$/\/../;

    # try the following directories
    my @trythese = ( qw(. .. /usr/local/everything /usr/share/everything), $script);
    foreach my $try (@trythese) {
        if ( $self->check_everything_dir($try) ) { 
            $edir = abs_path $try;
	    last;
        }
    }

    return $edir;

}

sub guess_web_dir {
    my ($self, %OPTIONS) = @_;
    my $webdir = $OPTIONS{webdir};

    my @defaults = qw( /var/www /usr/local/apache/htdocs /home/httpd/html
      ~/public_html);

    my $default;
    foreach (@defaults) {
        $_ = abs_path $_;
        if ( -d and -w and -x ) {
            $default = $_;
            last;
        }
    }

    return $default;
}

sub create_index {
    my ($self, $OPTIONS) = @_;

    my %OPTIONS = %$OPTIONS;

    my $infile = File::Spec->catfile( $OPTIONS{edir}, 'web', 'index.in' );
    my $outfile = File::Spec->catfile( $OPTIONS{webdir}, 'index.pl' );

    $self->amend_template(\%OPTIONS, $infile, $outfile);

    chmod 0741, $outfile;
    my $uid = getpwnam( $self->get_web_user );
    my $gid = getgrnam( $self->get_web_group );
    chown $uid, $gid, $outfile;
}

sub guess_apache_user {
    my ( $self ) = @_;

    my @apacheusers =  ( 'www-data', qw(apache nobody) );

    my $default;
    foreach (@apacheusers) {
        if ( getpwnam($_) ) {
            $default = $_;
            last;
        }
    }

    return $default;
}

sub create_incoming {

    my ($self, $webdir, $user) = @_;

    $user ||= $self->get_web_user;

    unless (getpwnam($user)) {
	warn "It doesn't look like user '$user' exists! Not creating incoming directory.";
	return;
}
    my $incoming = File::Spec->catdir( $webdir, 'incoming' );
    mkdir $incoming, 0755;
    chown( ( getpwnam($user) )[ 2, 3 ], $incoming );

    print "$webdir\/incoming created and chown to $user!\n";
}

sub amend_template {
    my ($self, $vars, $template_name, $out_name ) = @_;

    my $tt = Template->new( ABSOLUTE => 1);
    $tt->process( $template_name, $vars, $out_name ) || die Template->error;

}

sub create_apache_handler_conf {
    my ($self, $OPTIONS) = @_;

    my %OPTIONS = %$OPTIONS;

    my $infile = File::Spec->catfile( $OPTIONS{edir}, 'web', 'everything-apache-handler.conf.in' );
    my $outfile = File::Spec->catfile( $OPTIONS{edir}, 'web', 'everything-apache-handler.conf' );

    $self->amend_template(\%OPTIONS, $infile, $outfile);

    return $outfile;
}


sub create_apache_cgi_conf {

    my ($self, $edir, $webdir) = @_;

    my $conffile =
      File::Spec->catfile( $edir, 'web', 'everything-apache-cgi.conf.in' );

    my $outfile = File::Spec->catfile( $edir, 'web', 'everything-apache-cgi.conf' );
    unless ( -e $conffile ) {
        return;
    }

    $self->amend_template( { webdir => $webdir}, $conffile, $outfile );

    return $outfile;
}

sub guess_apache_conf {


	my ($self) = @_;

	my @dirs = qw( /etc/apache2 /etc/apache2/conf /etc/apache /etc/apache/conf /etc/httpd /etc/httpd/conf
		/usr/local/apache/conf );

	my $conf;

	for my $dir (@dirs)
	{
		my $file = File::Spec->catfile( $dir, 'conf.d' );
		if (-e $file && -d $file ) {
		    return [ 'directory', $file ];
		  }
	      }
	for my $dir (@dirs)
	{
		my $file = File::Spec->catfile( $dir, 'httpd.conf' );
		return [ 'file', $file ] if -e $file;
	}

	return;
      }

1;
