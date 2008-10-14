
=head1 Everything::Storage::Nodeball

A module that manages the import and export of nodeballs to/from a nodebase.

=cut

package Everything::Storage::Nodeball;

{
use Object::InsideOut;


    my @nodebase
      :Field
      :Standard(nodebase)
      :Arg(nodebase);

    my @file
      :Field
      :Standard(file)
      :Arg(file);

    my @nodeball_dir
      :Field
      :Standard(nodeball_dir)
      :Arg(nodeball_dir);

    my @all_files
      :Field
      :Standard(all_files);

    my @cleanup
      :Field
      :Accessor(cleanup);

    my @FORCE
      :Field
      :Accessor(FORCE);

    my @db_name
      :Field
      :Standard(db_name)
      :Arg(dbname);

    my @db_user
      :Field
      :Standard(db_user)
      :Arg(dbuser);

    my @db_host
      :Field
      :Standard(db_host)
      :Arg(dbhost);

    my @db_password
      :Field
      :Standard(db_password)
      :Arg(dbpassword);

    my @db_type
      :Field
      :Standard(db_type)
      :Arg(dbtype);

    my %init_args :InitArgs = (
      nodeball => '',
      db_name => '',
      db_host => '',
      db_user => '',
      db_password => '',
      db_type => ''
    );


## special handling for the nodeball and db arguments to the constructor.

sub _init : Init {
    my ( $self, $args ) = @_;
    $self->set_nodeball( $args->{nodeball} ) if defined $args->{nodeball};

    if ( defined $args->{db_name} ) {
        my $db_name     = $args->{db_name};
        my $db_user     = $args->{db_user} || 'root';
        my $db_password = $args->{db_password} || '';
        my $db_type     = $args->{db_type} || 'mysql';
        my $db_host     = $args->{db_host} || 'localhost';
        $self->set( \@db_name,     $db_name );
        $self->set( \@db_user,     $db_user );
        $self->set( \@db_password, $db_password );
        $self->set( \@db_type,     $db_type );
        $self->set( \@db_host,     $db_host );
        my $nb =
          Everything::NodeBase->new( "$db_name:$db_user:$db_password:$db_host",
            1, $db_type )
          || Everything::Exception::NoNodeBase->throw(
"Can't open a nodebase of type $db_type, called $db_name. User: $db_user, Password: $db_password"
          );
        $self->set_nodebase($nb);
    }

}

}

use Exception::Class (
    Everything::Exception::CorruptNodeball => {
        fields      => [qw/nodeball_path file_path/],
        description => "Exceptions thrown when a nodeball is corrupt."
    },

    Everything::Exception::NodeballExists => {
        fields      => [qw/nodeball/],
        description =>
"Exceptions thrown when attempting to insert a nodeball when a ball of the same name already exists in a given nodebase.",
    },

    Everything::Exception::NoNodeBase => {
        descripton =>
          "Thrown when a nodebase is necessary but has not been set."
    }
);

use Carp;
use IO::File;
use File::Path ();
use File::Temp ();
use Everything::XML qw/readTag xmlfile2node xml2node fixNodes/;
use Everything::XML::Node;
use Everything::NodeBase;
use SQL::Statement;
use strict;
use warnings;

=head2 C<set_nodeball>

Sets the nodeball attribute. The argument may be a file or directory. If it is a file, the file is expanded and the nodeball_dir attribute is set to the directory of the expanded nodeball.

If the argument is a directory, the nodeball_dir is set to it.

=cut

sub set_nodeball {
    my ( $self, $nodeball ) = @_;

    if ( -d $nodeball ) {
        $self->set_nodeball_dir($nodeball);

    }
    else {
        $self->set_file($nodeball);
        $self->expand_nodeball($nodeball);
        $self->cleanup(1);
    }

    return;
}

=head2 C<get_nodeball>

If the file attribute is set returns its value. Otherwise returns the value of nodeball_dir.

=cut

sub get_nodeball {
    my ($self) = @_;
    return $self->get_file || $self->get_nodeball_dir;

}

=head2 C<expand_nodeball>

Take a tar-gziped nodeball and expand it to a dir in /tmp return the directory

=cut

sub expand_nodeball {
    my ( $self, $nbfile ) = @_;

    croak "Can't seem to see the nodeball: $nbfile" unless ( -e $nbfile );
    my $dir = $self->get_temp_dir();

    my @files = `tar -xvzf $nbfile -C $dir`;
    $self->set_nodeball_dir($dir);
    $self->set_all_files( \@files );
    $self->set_nodeball_dir($dir);
    return $dir;
}

sub nodeball_xml {

    my ( $self, $dir ) = @_;
    $dir ||= $self->get_nodeball_dir;

    my $NODEBALL = IO::File->new( $dir . '/ME', 'r' )
      or Everything::Exception::CorruptNodeball->throw(
        error         => "Can't open the nodeball link '$dir\/ME'",
        nodeball_path => $dir,
        file_path     => "$dir/ME"
      );

    my $nodeball_xml = join '', <$NODEBALL>;
    close $NODEBALL;
    return $nodeball_xml;
}

sub nodeball_vars {

    my ( $self, $dir ) = @_;
    $dir ||= $self->get_nodeball_dir;

    my $nodeball_xml = $self->nodeball_xml($dir);

    my $r = {};
    $r->{version}     = readTag( 'version',     $nodeball_xml, 'var' );
    $r->{author}      = readTag( 'author',      $nodeball_xml, 'var' );
    $r->{description} = readTag( 'description', $nodeball_xml, 'var' );
    $r->{title} = readTag( 'title', $nodeball_xml );
    return $r;

}

=head2 C<checkTables>

Checks to see if the tables in the target database are equivalent to the tables
in the sql files.  Does this by creating a dummy database dumping the tables
into it, and comparing them with show table and show field statements.

=cut

sub checkTables {
    my ( $self, $tabledir, $DB ) = @_;
    my $dummydb = "dummy" . int( rand(1000) );

    my $database = $DB->{dbname};

#initEverything($database.":$OPTIONS{user}:$OPTIONS{password}:$OPTIONS{host}", 1);
    createDB $dummydb;
    addTablesToDB( $dummydb, $tabledir );
    my $ret = compareAllTables(
        $self->getTablesHashref($database),
        $self->getTablesHashref($dummydb),
        $dummydb, $database, $tabledir
    );
    dropDB $dummydb;

#initEverything($database.":$OPTIONS{user}:$OPTIONS{password}:$OPTIONS{host}", 1);
    $ret;
}

=cut



=head2 C<checkNamedTables>

Checks to see if the tables in the target database are equivalent to the tables
in the sql files.  Works just like checkTables, except that it only checks
files listed in the first argument, an array ref.

Returns a hash ref of tablename => [ column list ] of the columns
missing in the current database.

=cut

sub checkNamedTables {
    my ( $tables_ref, $dir, $DB ) = @_;

    my $parser = Everything::Storage::Nodeball::SQLParser->new();
    $parser->{PrintError} = 1;
    $parser->{RaiseError} = 1;
    $parser->feature( 'reserved_words', 'USER', 0 );

    my %tables;

    local *DIR;
    opendir DIR, $dir;
    my @files = map { File::Spec->catfile( $dir, $_ ) } readdir DIR;
    closedir DIR;

    foreach (@files) {
        next unless -f;

        my $fh = IO::File->new( $_, 'r' ) || die "Can't open $_, $!";

        my @statements = $DB->{storage}->parse_sql_file($fh);

        foreach my $sql (@statements) {
            next unless $sql =~ /^\s*CREATE\s+TABLE/i;

            my $stmt = SQL::Statement->new( $sql, $parser );

            my @tables  = map { $_->name } $stmt->tables;
            my @columns = map { $_->name } $stmt->columns;

            $tables{ $tables[0] } = \@columns;

        }

    }

    my %new_fields;
    foreach my $table (@$tables_ref) {
        my @existing_fields =
          $DB->{storage}->getFieldsHash( $table, 0 )
          ;    # second arg means get an array of fields.
        my %fields_in_file = map { $_ => 1 } @{ $tables{$table} };

        foreach my $field (@existing_fields) {

            delete $fields_in_file{$field};
        }

        my @keys = keys %fields_in_file;
        $new_fields{$table} = \@keys if @keys;

    }
    return \%new_fields if %new_fields;
    return;
}

=head2 C<buildSqlCmdline>

This script has to call mysqldump and mysql a few different times, this
function builds the command line options

XXX: This must be moved into the DB layer.

=cut

sub buildSqlCmdline {
    my $self = shift;
    my %OPTIONS;
    $OPTIONS{user}     = $self->get_db_user;
    $OPTIONS{host}     = $self->get_db_host;
    $OPTIONS{password} = $self->get_db_password;
    my $sql;
    $sql .= " -u $OPTIONS{user} ";
    $sql .= " -p$OPTIONS{password} " if $OPTIONS{password};
    $sql .= " --host=$OPTIONS{host} " if $OPTIONS{host};

    $sql;
}

=head2 C<insert_sql_tables>

Takes optional directory arguments.

Assumes that sql related to tables is located in the tables/ directory
of a nodeball. It reads these and attempts to insert them into the
nodebase.

=cut

sub insert_sql_tables {
    my ( $self, $dir ) = @_;

    $dir ||= $self->get_nodeball_dir;
    my $nodebase   = $self->get_nodebase;
    my $tables_dir = $dir . "/tables";

    $nodebase->{storage} =~ /DB::(\w+)/;
    my $nodebase_type = $1;

    if ( $nodebase_type eq 'Pg' ) {
        $tables_dir = File::Spec->catfile( $tables_dir, 'Pg' );
    }
    elsif ( $nodebase_type eq 'sqlite' ) {
        $tables_dir = File::Spec->catfile( $tables_dir, 'SQLite' );
    }
    elsif ( $nodebase_type eq 'mysql' ) {
        $tables_dir = File::Spec->catfile( $tables_dir, 'mysql' );
    }

    return unless -d $tables_dir;

    #import any tables that need it
    use File::Find;

    my ( @add_tables, @check_tables );
    if ( -e $tables_dir ) {
        print "Creating tables...\n";
        find sub {
            my ($file) = $File::Find::name;
            if ( $file =~ /sql$/ ) {
                push @add_tables, $file;
            }
        }, $tables_dir;
        print "   - Done.\n";
    }

    ### This assumes a nodeball structure that might not necessarily
    ### exist, that is that sql files are named table_name.sql.

    foreach my $table (@add_tables) {
        next unless ( $table =~ m!/(\w+)\.sql$! );
        my $table_name = $1;

        if ( $nodebase->{storage}->tableExists($table_name) ) {
            print "Skipping already installed table $table_name!\n";
            push @check_tables, $table_name;
            next;
        }
        else {

            my $fh = IO::File->new( $table, 'r' )
              or Everything::Exception::CorruptNodeball->throw(
                "Can't open $table, $!");
            my @sql_commands = $nodebase->{storage}->parse_sql_file($fh);

            $nodebase->getDatabaseHandle->do($_) || warn "$_, $DBI::errstr"
              foreach @sql_commands;

            $fh->close;
        }
    }

    if (@check_tables) {
        my $check = checkNamedTables( \@check_tables, $tables_dir, $nodebase );
        print "Skipped tables have the right columns, though!\n"
          unless ($check);
    }

}

=head2 C<make_node_iterator>

This is a method. It returns an iterator sub-ref.  On each call returns a new Everything::XML::Node object, until it has run through all the nodes.

=cut

sub make_node_iterator {
    my ( $self, $node_selection_cb ) = @_;

    $node_selection_cb ||= sub { 1 };

    my $dir = File::Spec->catfile( $self->get_nodeball_dir, 'nodes' );

    my @queue = ($dir);

    my $iterator = sub {

        while (@queue) {

            my $file = shift @queue;

            if ( -d $file ) {
                opendir my $dh, $file or next;
                my @newfiles = grep { $_ ne '.' && $_ ne '..' } readdir $dh;
                push @queue, map { File::Spec->catfile( $file, $_ ) } @newfiles;
            }

            next unless $file =~ /\.xml$/;

            my $fh = IO::File->new( $file, 'r' );
            local $/;
            my $xmlnode = Everything::XML::Node->new;
            $xmlnode->parse_xml(<$fh>);

            next unless $node_selection_cb->($xmlnode);

            return $xmlnode;

        }

        return;

    };

}

=head2 C<fix_node_references>

Tries to fix broken references to other nodes, for nodes that were
previously inserted into the database.

=cut

sub fix_node_references {

    fixNodes(@_);

}

=head2 C<install_xml_nodes>

It installs nodes stored as XML in the nodeballs.

Takes an optional argument of a call back that examines each node.  The call back should return true if it's a node we want or false otherwise.

Returns undef.

=cut

sub install_xml_nodes {

    my ( $self, $select_cb ) = @_;

    $select_cb ||= sub { 1 };
    my $iterator = $self->make_node_iterator($select_cb);

    while ( my $xmlnode = $iterator->() ) {
	$self->install_xml_node( $xmlnode );
    }

    return;

}

=head2 C<install_xml_node>

It installs a node stored as XML into the the current nodebase.

It takes on argument which is the Everything::XML::Node object to be
installed.


=cut

sub install_xml_node {

    my ( $self, $xmlnode ) = @_;
    xml2node( $xmlnode->get_raw_xml );

}


=head2 C<install_nodeball_description>

It installs a node representing the current nodeball, as XML, into the
the current nodebase.

Currently, this means reading from the ME file.


=cut

sub install_nodeball_description {

    my ( $self ) = @_;

    my $dir = $self->get_nodeball_dir;
    my $mefile = File::Spec->catfile( $dir, 'ME' );
    my $fh = IO::File->new ( $mefile );
    local $/;
    my $xml = <$fh>;
    $fh->close;
    my $xmlnode = Everything::XML::Node->new;
    $xmlnode->parse_xml( $xml );
    $self->install_xml_node( $xmlnode );

}


=head2 C<install_xml_nodetype_nodes>

This is a method.

It installs nodetype nodes stored as XML in the nodeballs.

Returns undef.

=cut

sub install_xml_nodetype_nodes {

    my ( $self ) = @_;

    my $select_cb = sub { my $xmlnode = shift; return 1 if $xmlnode->get_nodetype eq 'nodetype'; return; };

    $self->install_xml_nodes( $select_cb );

    $self->get_nodebase->{cache}->flushCache();

    $self->get_nodebase->rebuildNodetypeModules();

}

=head2 C<install_nodeball>

Installs the nodeball. If supplied with an argument in a
directory. Installs the nodeball in that directory.

=cut

sub install_nodeball {

    my ( $self, $dir ) = @_;
    $dir ||= $self->get_nodeball_dir;
    my $DB   = $self->get_nodebase;
    my $vars = $self->nodeball_vars($dir);

    if ( my $oldball = $DB->getNode( $$vars{title}, 'nodeball' ) ) {
        Everything::Exception::NodeballExists->throw(
            error => "Can't install nodeball at "
              . $self->get_nodeball
              . " a nodeball of that name already exists",
            nodeball => $oldball
        );
    }

    ## run pre-install scripts
    my $script_dir = $dir . "/scripts";
    my $preinst    = $script_dir . "/preinstall.pl";
    require $preinst if -f $preinst;

    $self->insert_sql_tables($dir);

    my $nodetypes_dir = $dir . "/nodes/nodetype";

    if ( -e $nodetypes_dir ) {
        print "Installing nodetypes...\n";
        $self->install_xml_nodes(
            sub {
                my $xmlnode = shift;
                return 1 if $xmlnode->get_nodetype eq 'nodetype';
                return;
            }
        );
        print "Fixing references...\n";
        fixNodes(0);
        print "   - Done.\n";
    }

    # Now that the nodetypes are installed, we can install the nodes.
    # But first, we need to flush the entire cache because some nodetypes
    # may have been loaded before their parent nodetypes.  This would
    # result in nodetypes being cached that are not complete.  By flushing
    # the cache, we will reload all the types as they are needed and they
    # will be properly derived.
    $DB->{cache}->flushCache();

    # Also, we need to rebuild the cache of Nodetype .pm's so that we
    # what does and does not exist since new nodetypes may have been
    # installed.
    $DB->rebuildNodetypeModules();

    print "Installing nodes...\n";
    $self->install_xml_nodes(
        sub {
            my $xmlnode = shift;
            return
              if $xmlnode->get_nodetype && $xmlnode->get_nodetype eq 'nodetype';
            return 1;
        }
    );
    print "Fixing references...\n";
    fixNodes(1);
    print "   - Done.\n";

    my $postinst = $script_dir . "/postinstall.pl";
    require $postinst if -f $postinst;

    # install any .pm's that we might have
    installModules($dir);

    #we should give warnings if dependant
    #nodeballs are not installed...  but we don't
}



sub export_nodeball_to_directory {

    my ( $self, $nodeball_name, $dir ) = @_;
    my $nodeball = $self->get_nodebase->getNode( $nodeball_name, 'nodeball');
    croak "No nodeball, $nodeball_name" unless $nodeball;

    ###setup directory for export
    $self->set_nodeball_dir( $dir || $self->get_temp_dir );
    $self->write_node_to_nodeball( $nodeball, 'ME' ); # create ME file
    my $group = $nodeball->selectNodegroupFlat;
    foreach ( @$group ) {
	$self->write_node_to_nodeball( $_ );

    }

}

sub export_nodeball_to_file {

    my ( $self, $nodeball_name, $filename ) = @_;

    $self->export_nodeball_to_directory( $nodeball_name );
    $self->create_nodeball_file( $nodeball_name, undef,  $filename );


}

=head2 C<installModules>

Copy any perl modules that exist in this nodeball to the appropriate
install directory on the system.

=over 4

=item * $dir

the base directory of this nodeball

=back

Returns 1 if something was copied.  0 if no work was done.

=cut

sub installModules {
    my ($dir) = @_;
    my $includeDir;
    my $result = 0;

    use File::Find;
    use File::Copy;

    # If there is an Everything directory, we need to install the modules
    # in the system include directory.
    my $e_dir = $dir;
    $e_dir .= "/" unless ( $e_dir =~ /\/$/ );
    $e_dir .= "Everything";

    return $result unless ( -e $e_dir && -d $e_dir );

    $includeDir = getPMDir() . "/Everything";

    # Copy all of the pm's to the system directory.
    find sub {
        my ($file) = $File::Find::name;
        if ( $file =~ /pm$/ ) {
            ( $_ = $file ) =~ s!.+?Everything/!!;

            copy( $file, $includeDir . "/" . $_ );
            $result = 1;
        }
    }, $e_dir;

    return $result;
}



=head2 C<build_new_nodes>

Iterates through the nodes in the current nodeball and turns them into
Everything::Node objects that aren't in the NodeBase (i.e. they are
not stored in the database).

Takes an optional subroutine references which is passed to
make_node_iterator so that the nodes may be selected.

Returns a list.

=cut

sub build_new_nodes {

    my ( $self ) = @_;

    my $select_cb ||= sub { 1 };
    my $iterator = $self->make_node_iterator( $select_cb );

    my @nodes;
    while ( my $xmlnode = $iterator->( $select_cb ) ) {
	my $node =  xml2node( $xmlnode->get_raw_xml, 'nofinal' );
	push @nodes, @$node;
    }

    return @nodes;

}

sub update_node_to_nodebase {
    my ( $self, $node, $handle_conflict_cb ) = @_;

    my $oldnode = $node->existingNodeMatches();

    ## default behaviour is to clobber nodes
    $handle_conflict_cb ||= sub { $oldnode->updateFromImport( $node, -1 ) };
    if ($oldnode) {

        if ( $oldnode->conflictsWith($node) ) {
            $handle_conflict_cb->( $self, $node );
        }
        else {
            $oldnode->updateFromImport( $node, -1 );
        }

    }
    else {
        $node->insert(-1);
    }

}



=head2 C<verify_nodes>

Cycles through the nodeball and checks each node against what is in the nodebase. the Checks that a node in the nodeball is the same as the one in the nodebase.
Returns a list of array refs.

The first is a list of xmlnodes that don't have corresonding entries
in the nodebase.

The second is a list of nodes that don't have corresonding xmlnodes 
in the nodeball.

The third is a list of Everything::Storage::Nodeball::Diff objects
that set out that differences.

=cut


sub verify_nodes {
    my ($self) = @_;

    my $nb = $self->get_nodebase;

    my $iterator = $self->make_node_iterator;

    my $nodebase_nodeball_group =
      $nb->getNode( $self->nodeball_vars->{title}, 'nodeball' )
      ->selectGroupArray;

    ## get nodes in group;

    my %nodebase_group = map {
        my $n = $nb->getNode($_);
        ( "$$n{title},$$n{type}{title}" => 1 );
    } @$nodebase_nodeball_group;

    my @diffs;

    my @in_nodeball;

    my @in_nodebase;

  XMLNODE:
    while ( my $xmlnode = $iterator->() ) {

        my $title = $xmlnode->get_title;
        my $type  = $xmlnode->get_nodetype;
        my $node  = $self->get_nodebase->getNode( $title, $type );

        delete $nodebase_group{"$title,$type"};

        if ( !$node ) {

            push @in_nodeball, $xmlnode;
            next XMLNODE;
        }

        if ( my $diff = $self->verify_node( $xmlnode, $node ) ) {

            push @diffs, [ $xmlnode, $diff ] ;
            next XMLNODE;
        }

    }

    foreach ( keys %nodebase_group ) {
        my ( $title, $type ) = split /,/, $_;
        push @in_nodebase, $nb->getNode( $title, $type );
    }

    return \@in_nodeball, \@in_nodebase, \@diffs;
}

=head2 C<verify_node>

Checks that a node in the nodeball is the same as the one in the nodebase.

First argument in the XML::Node object, the second one is the Everything::Node object.

Returns an array ref of Everything::Storage::Nodeball::Diff objects.

=cut


sub verify_node {

    my ( $self, $xmlnode, $node ) = @_;


    ### XXX: if we want to turn this into a function, $nb can be the
    ### nodebae stored in $node
    my $nb = $self->get_nodebase;

    my @differences;
    ## verify attributes
        my $atts = $xmlnode->get_attributes;



        my $node_title = $xmlnode->get_title;
        my $node_type  = $xmlnode->get_nodetype;

         foreach (@$atts) {

            my $att_name = $_->get_name;

	    my $diff = Everything::Storage::Nodeball::Diff->new( nodebase => $nb );
	    if ( $diff->check_attribute( $xmlnode, $node, $_ ) ) {

		push @differences, $diff;
	    }

	}


    ### verify vars

    my $vars = $xmlnode->get_vars;

    if (@$vars) {

        my $db_vars = $node->getVars;

        foreach (@$vars) {

	    my $diff = Everything::Storage::Nodeball::Diff->new( nodebase => $nb );
	    if ( $diff->check_var( $xmlnode, $node, $_ ) ) {

		push @differences, $diff;
	    }

	}
    }


    ## verify group members


    my $members = $xmlnode->get_group_members;

    if ( @$members ) {

	    my $diff = Everything::Storage::Nodeball::Diff->new( nodebase => $nb );
	    if ( $diff->check_members( $xmlnode, $node ) ) {

		push @differences, $diff;
	    }

 
    }

    return \@differences if @differences;
    return;
}

=head2 C<update_nodebase_from_nodeball>

We already have this nodeball in the system, and we are going to
update it. This does not delete nodes in the existing nodeball and not
in the new one, it simply removes them from the nodeball in the
nodebase. Takes an optional second argument of the nodeball directory
and an optional third argument which is a call back that updates an
indiviudal node to the nodebase. It is passed the nodeball object and
a node object as arguments. It defaults to calling
update_node_to_nodebase.

=cut

sub update_nodebase_from_nodeball {
    my ( $self, $dir, $update_node_cb ) = @_;

    my $DB = $self->get_nodebase
      || Everything::Exception::NoNodeBase->throw("No nodebase here!");

    $dir ||= $self->get_nodeball_dir;

    $update_node_cb ||= sub { my ( $nodeball, $node ) = @_;
			      $nodeball->update_node_to_nodebase( $node );
			  };

    my $NEWBALLXML = $self->nodeball_xml;

    my $vars = $self->nodeball_vars;

    my $OLDBALL = $self->get_nodebase->getNode( $vars->{title}, 'nodeball');

    #check the tables and make sure that they're compatable

    $self->insert_sql_tables($dir);

    my @nodes = $self->build_new_nodes; # list of new nodes

    foreach my $N (@nodes) {

	$update_node_cb->( $self, $N );
    }

    $self->fix_node_references(0);

    #insert the new nodeball
    my $nodelist = xml2node( $NEWBALLXML, 'nofinal' );

    $OLDBALL->updateFromImport( $$nodelist[0], -1 );

    $self->fix_node_references(1);

}

=cut



=head2 C<getPMDir>

When Everything is installed, the base perl modules are installed somewhere on
the system.  Where they are installed varies from system to system, but they
are always installed somewhere in the standard perl include directories.  This
searches through the install directories until we find it.

Returns the include directory where Everything.pm and Everthing/ can be found.
undef if we couldn't find it.

=cut

sub getPMDir {
    my $includeDir;
    my $edir;

    foreach $includeDir (@INC) {
        $edir = $includeDir . "/Everything";
        return $includeDir if ( -e $edir );
    }

    return undef;
}

=head2 C<get_temp_dir>

Gets a new temporary directory with a unique name and creates it.

=cut

sub get_temp_dir {
    my $self = shift;
    my $dir  =
      File::Temp::tempdir( 'everythingXXXXX', DIR => File::Spec->tmpdir );
    return $dir;
}

=head2 C<createDir>

Create a new directory, if you can, else barf.

=cut

sub createDir {
    my ( $self, $dir ) = @_;
    unless ( -e $dir ) {
        my $mode = 0777;
        my $result = mkdir $dir, $mode;
        croak "error creating $dir: $!"
          if ( !$result and !$self->FORCE );
    }
    else {
        croak "$dir already exists" unless $self->FORCE;
    }
    return 1;
}

=head2 C<cleanUpDir>

Removes a specified directory.

=cut

sub cleanUpDir {
    my ($dir) = @_;

    #don't let this bite you in the ass

    return unless ( defined $dir and -e $dir and -d $dir and !( -l $dir ) );
    use File::Path;
    rmtree($dir);
}

sub _destroy : Destroy {
    my $self = shift;
    cleanUpDir( $self->get_nodeball_dir ) if $self->cleanup;

}

=head2 C<getTablesHashref>

Get the list of tables (actually a hash reference) for the given database.


XXX TODO: Move into DB layer.

=cut

sub getTablesHashref {
    my ( $self, $db ) = @_;

    $db ||= '';
    my %OPTIONS;
    $OPTIONS{host}     ||= '';
    $OPTIONS{user}     ||= '';
    $OPTIONS{password} ||= '';

    my $tempdbh = DBI->connect( "DBI:mysql:$db:$OPTIONS{host}",
        $OPTIONS{user}, $OPTIONS{password} );
    die "could not connect to database $db" unless $tempdbh;

    my $st = $tempdbh->prepare("show tables");
    $st->execute;
    my %tables;
    while ( my $ref = $st->fetchrow_arrayref ) {
        $tables{ $ref->[0] } = 1;
    }
    $st->finish;
    $tempdbh->disconnect;
    return \%tables;
}

=head2 C<write_node_to_nodeball>

  Writes a node to a nodeball turning it into XML in the process. Takes one argument which should be the Everything::Node object to be written to the nodeball. Takes an optional second argument which is the path (under the nodeball directory) to which the node should be written.

=cut

sub write_node_to_nodeball {
    my ( $self, $node, $filepath ) = @_;


    my $volume;
    my $save_title;
    my $save_dir;


    if ( $$node{type}{title} eq 'dbtable' ) {
	$self->write_sql_table_to_nodeball( $$node{title} );
    }

    if ( ! $filepath ) {
	$save_title = $$node{title};
	$save_dir =  $$node{type}{title};
	$save_dir =~ tr/ /_/;
	$save_dir = File::Spec->catfile ('nodes', $save_dir);
	$save_title =~ tr/ /_/;
	$save_title =~ s/:+/-/;
	$save_title .= '.xml';
	$filepath = File::Spec->catfile( $save_dir, $save_title );
    } else {
	( $volume, $save_dir, $save_title ) = File::Spec->splitpath( $filepath );
    }

    my $save_path = File::Spec->catfile( $self->get_nodeball_dir, $save_dir );
    File::Path::mkpath( $save_path ) unless -d $save_path; 
    $save_path = File::Spec->catfile( $save_path, $save_title );
    my $xml = Everything::XML::Node->new( nodebase => $self->get_nodebase, node => $node )->toXML;
     my $fh = IO::File->new( $save_path, 'w' ) || croak "Can't open $save_path for writing, $!";
     print $fh $xml;
     $fh->close;

}

=head2 C<write_sql_table_to_nodeball>

  Writes a sql create statement to a nodeball. Takes one argument which is the table name.

=cut

sub write_sql_table_to_nodeball {
    my ( $self, $table_name ) = @_;

    my $nb = $self->get_nodebase;

    $nb->{storage} =~ /DB::(\w+)/;
    my $storage_type = $1;
    my $dir          = $self->get_nodeball_dir;
    $dir = File::Spec->catfile( $dir, 'tables' );
    mkdir $dir unless -d $dir;
    if ( $storage_type eq 'Pg' ) {
        $dir = File::Spec->catfile( $dir, 'Pg' );
    }
    elsif ( $storage_type eq 'sqlite' ) {
        $dir = File::Spec->catfile( $dir, 'SQLite' );
    }
    elsif ( $storage_type eq 'mysql' ) {
        $dir = File::Spec->catfile( $dir, 'mysql' );
    }
    mkdir $dir unless -d $dir;

    my $sql       = $nb->{storage}->get_create_table($table_name);
    my $file_name = File::Spec->catfile( $dir, "$table_name.sql" );

    my $fh = IO::File->new( $file_name, 'w' )
      or croak "Can't open $file_name for writing, $!";
    print $fh $sql;
    $fh->close;

}


=head2 C<create_nodeball_file>

Tar-gzips a directory it -- as a nodeball

=over 4

=item * NODEBALL

The nodeball object we are exporting

=item * dir

directory of stuff (optional if nodeball_dir is set).

=back

=cut

sub create_nodeball_file
{
	my ( $self, $NODEBALL, $dir, $filename ) = @_;

	$dir ||= $self->get_nodeball_dir;
	my $nodeball = $self->get_nodebase->getNode( $NODEBALL, 'nodeball' );
	my $VARS    = $nodeball->getVars();
	my $version = $$VARS{version};

	if ( ! $filename) {

	    $filename = $$NODEBALL{title};
	    $filename =~ tr/ /_/;
	    $filename .= "-$version" if $version;
	    $filename .= ".nbz";
	}

	use Cwd;
	my $cwd = getcwd();
	$cwd .= '/' . $filename;

	`tar -cvzf $cwd -C $dir .`;

}

=head2 C<buildNodeballMembers>

Builds a hash of node_id-E<gt>nodeball that it belongs to.  The nodeball(s)
that are sent as parameters are to be discluded.  This way we can see if a node
is in more than one nodeball -- where potential conflicts might emerge.
Returns a hash reference

Takes any nodeball(s) that should be excluded from the hash.

=cut

sub buildNodeballMembers {
    my ( $DB, @EXCLUDES ) = @_;

    my %excl;
    foreach (@EXCLUDES) {
        $excl{ $_->getId() } = 1;
    }

    #we build a hash to make lookups easier.

    my $NODEBALLS =
      $DB->getNodeWhere( { type_nodetype => $DB->getType('nodeball') },
        'nodeball' );

    my %nbmembers;
    foreach (@$NODEBALLS) {
        next if $excl{ $_->getId() };
        my $group = $$_{group};
        foreach my $member (@$group) {
            $nbmembers{$member} = $_->getId();
        }
    }

    return \%nbmembers;
}

=head2 C<check_nodeball_integrity>

Checks the internal structure of a nodeball. Return undef if everything is OK.

Otherwise, it returns a list of two array refs of hash refs.  The hash refs have two keys 'title' and 'type'. The first hashref lists the nodes present in the nodeball but not listed in the ME file.  The second lists those listed in the ME file, but not present in the nodeball.

=cut

sub check_nodeball_integrity {
    my $self = shift;
    local $/;
    my $fh = IO::File->new( File::Spec->catfile ( $self->get_nodeball_dir, 'ME' ) );
    my $xml =  <$fh>;
    my $me = Everything::XML::Node->new;
    $me->parse_xml( $xml );
    my @members = @{ $me->get_group_members || [] };

    my $iterator = $self->make_node_iterator;
    my @nodes;
    while ( my $xmlnode = $iterator->() ) {
	push @nodes, $xmlnode;
    }

    my ( @not_in_me, @not_in_nodeball );

    foreach my $member (@members) {
	my ( $member_type ) = split /,/, $member->get_type_nodetype;
	my $found_xmlnode = 0;
      XMLNODE:
	foreach my $xmlnode ( @nodes ) {

	    if ( ($xmlnode->get_title eq $member->get_name) && ( $xmlnode->get_nodetype eq $member_type)) {
		$found_xmlnode++;
		last XMLNODE
	    }
	}
	push @not_in_nodeball, { title => $member->get_name, type=> $member_type } unless $found_xmlnode;
    }


    foreach my $xmlnode (@nodes) {
	my $found_xmlnode = 0;
      GROUPMEMBER:
	foreach my $member ( @members ) {
	    my ( $member_type ) = split /,/, $member->get_type_nodetype;
	    if ( ($xmlnode->get_title eq $member->get_name) && ( $xmlnode->get_nodetype eq $member_type ) ) {
		$found_xmlnode++;
		last GROUPMEMBER
	    }

	}
	push @not_in_me, { title => $xmlnode->get_title, type=> $xmlnode->get_nodetype } unless $found_xmlnode;

    }

    return if ( ! @not_in_nodeball && ! @not_in_me );
    return \@not_in_me, \@not_in_nodeball;
}

package Everything::Storage::Nodeball::SQLParser;

use base 'SQL::Parser';

sub CREATE {
    my $self     = shift;
    my $stmt     = shift;
    my $features = 'TYPE|KEYWORD|FUNCTION|OPERATOR|PREDICATE';
    if ( $stmt =~ /^\s*CREATE\s+($features)\s+(.+)$/si ) {
        my ( $sub, $arg ) = ( $1, $2 );
        $sub = 'CREATE_' . uc $sub;
        return $self->$sub($arg);
    }

    $stmt =~ s/^CREATE (LOCAL|GLOBAL) /CREATE /si;
    if ( $stmt =~ /^\s*CREATE\s+(TEMP|TEMPORARY)\s+TABLE\s+(.+)$/si ) {
        $stmt = "CREATE TABLE $2";
        $self->{"struct"}->{"is_ram_table"} = 1;

        #  $self->{"struct"}->{"command"} = 'CREATE_RAM_TABLE';
        # return $self->CREATE_RAM_TABLE($1);
    }
    $self->{"struct"}->{"command"} = 'CREATE';
    my ( $table_name, $table_element_def, %is_col_name );

    if ( $stmt =~ /^(.*) ON COMMIT (DELETE|PRESERVE) ROWS\s*$/si ) {
        $stmt = $1;
        $self->{"struct"}->{"commit_behaviour"} = $2;
    }
    if ( $stmt =~ /^CREATE TABLE (\S+) \((.*)\)$/si ) {
        $table_name        = $1;
        $table_element_def = $2;
    }
    elsif ( $stmt =~ /^CREATE TABLE (\S+) AS (.*)$/si ) {
        $table_name = $1;
        my $subquery = $2;
        return undef unless $self->TABLE_NAME($table_name);
        $self->{"struct"}->{"table_names"} = [$table_name];
        $self->{"struct"}->{"subquery"}    = $subquery;
        return 1;
    }
    else {
        return $self->do_err("Can't find column definitions!");
    }
    return undef unless $self->TABLE_NAME($table_name);
    my $length;
    $table_element_def =~ s/\s+\(/(/g;
    my $primary_defined;
    for my $col ( split ',', $table_element_def ) {
        next if $col =~ /^\s*PRIMARY KEY/;    # get rid of this.
        next if $col =~ /^\s*KEY/;            # and this.
        my ( $name, $type, $constraints ) =
          ( $col =~ /\s*(\S+)\s+(\S+)\s*(.*)/ );

        next unless $name && $name =~ /\w/;  #we need this because the above
                                             #split also splits in the middle of
                                             #functions.

        if ( !$type ) {
            return $self->do_err(
"Column definition, $name $type $constraints, is missing a data type!"
            );
        }
        return undef if !( $self->IDENTIFIER($name) );
        $name = $self->replace_quoted_ids($name);

        $self->{"struct"}->{"column_defs"}->{"$name"}->{"data_type"}   = $type;
        $self->{"struct"}->{"column_defs"}->{"$name"}->{"data_length"} =
          $length;
        push @{ $self->{"struct"}->{"column_names"} }, $name;

        #push @{$self->{"struct"}->{ORG_NAME}},$name;
        my $tmpname = $name;
        $tmpname = uc $tmpname unless $tmpname =~ /^"/;
        return $self->do_err("Duplicate column names!")
          if $is_col_name{$tmpname}++;

    }
    $self->{"struct"}->{"table_names"} = [$table_name];
    return 1;
}

package Everything::Storage::Nodeball::Diff;

{

use Object::InsideOut;

my @nodebase :Field :Arg(nodebase) :Std(nodebase);

my @name :Field :Arg(name) :Std(name); # for attributes and vars

my @is_noderef :Field :Default(0) :Acc(is_noderef);

my @is_var :Field :Default(0) :Acc(is_var);

my @is_attribute :Field :Default(0) :Acc(is_attribute);

my @is_groupmember :Field :Default(0) :Acc(is_groupmember);

my @xmlnode :Field :Arg(xmlnode) :Std(xmlnode);

my @nb_node :Field :Arg(nb_node) :Std(nb_node);

my @xmlnode_attribute :Field :Std(xmlnode_attribute) :Type(Everything::XML::Node::Attribute);

my @xmlnode_content :Field :Std(xmlnode_content); #for literal content

my @nb_node_content :Field :Std(nb_node_content); #for literal content

my @xmlnode_ref_name :Field :Std(xmlnode_ref_name); #for noderefs

my @nb_node_ref_name :Field :Std(nb_node_ref_name); #for noderefs

my @xmlnode_ref_type :Field :Std(xmlnode_ref_type); #for noderefs

my @nb_node_ref_type :Field :Std(nb_node_ref_type); #for noderefs

my @xmlnode_additional :Field :Std(xmlnode_additional) :Type(list); # for group members

my @nb_node_additional :Field :Std(nb_node_additional) :Type(list); # for group members

}

sub check_attribute {

    my ( $self, $xmlnode, $nb_node, $xmlnode_attribute ) = @_;

    my $nb = $self->get_nodebase;

    $self->is_attribute(1);

    $self->set_xmlnode($xmlnode);
    $self->set_nb_node($nb_node);

    my $name = $xmlnode_attribute->get_name;

    $self->set_name($name);

    my $method = 'get_' . $name;

    my $nb_node_content = $nb_node->$method;

    return $self->compare_data( $xmlnode_attribute, $nb_node_content );
}

sub check_var {

    my ( $self, $xmlnode, $nb_node, $xmlnode_attribute ) = @_;

    my $nb = $self->get_nodebase;

    $self->is_var(1);

    $self->set_xmlnode($xmlnode);
    $self->set_nb_node($nb_node);

    my $name = $xmlnode_attribute->get_name;

    $self->set_name($name);

    my $vars = $nb_node->getVars;

    my $nb_node_content = $vars->{$name};

    return $self->compare_data( $xmlnode_attribute, $nb_node_content );
}

sub compare_data {

    my ( $self, $xmlnode_attribute, $nb_node_content ) = @_;

    $nb_node_content ||= '';

    my $nb = $self->get_nodebase;

    my $att_type = $xmlnode_attribute->get_type;

    if ( $att_type eq 'literal_value' ) {

        $self->is_noderef(0);

        my $xmlcontent = $xmlnode_attribute->get_content || '';

        return if $xmlcontent eq $nb_node_content;

        $self->set_xmlnode_content($xmlcontent);
        $self->set_nb_node_content($nb_node_content);

    }
    else {

        my ($type_name) = split /,/, $xmlnode_attribute->get_type_nodetype;
        my $node_name = $xmlnode_attribute->get_content;

        my $expected = $nb->getNode( $node_name, $type_name );

        my $nb_ref = $self->get_nodebase->getNode($nb_node_content);

        return
          if $expected
          && $nb_ref
          && ( $expected->get_node_id == $nb_ref->get_node_id );

        $self->is_noderef(1);

        $self->set_xmlnode_ref_name($node_name);
        $self->set_xmlnode_ref_type($type_name);
        $self->set_nb_node_ref_name( $nb_ref->get_title )           if $nb_ref;
        $self->set_nb_node_ref_type( $nb_ref->get_type->get_title ) if $nb_ref;

    }

    return $self;

}

sub check_members {

    my ( $self, $xmlnode, $nb_node ) = @_;

    my $nb = $self->get_nodebase;

    my @db_members = @{ $nb_node->selectGroupArray };    # node_ids
    my %db_members = map { $_ => 1 } @db_members;

    my @in_nodeball;

    my $members = $xmlnode->get_group_members;

  MEMBER:
    foreach (@$members) {

        my ($type_name) = split /,/, $_->get_type_nodetype;
        my $node_name = $_->get_name;

        my $wanted = $nb->getNode( $node_name, $type_name );

        next MEMBER if $wanted && delete $db_members{ $wanted->get_node_id };
        push @in_nodeball, { name => $node_name, type => $type_name };

    }

    my @in_nodebase;
    foreach ( keys %db_members ) {

        my $member = $nb->getNode($_);
        push @in_nodebase, $member;
    }

    return if !@in_nodebase && !@in_nodeball;

    $self->is_groupmember(1);
    $self->set_xmlnode_additional( @in_nodeball ) if @in_nodeball;
    $self->set_nb_node_additional( @in_nodebase ) if @in_nodebase;

    return $self;
}

1;
