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
use Everything::XML qw/readTag xmlfile2node xml2node fixNodes/;
use Everything::XML::Node;
use Everything::NodeBase;
use SQL::Statement;
use strict;
use warnings;

=head2 C<set_nodeball>

Sets a nodeball file or directory

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

sub get_nodeball {
    my ($self) = @_;
    return $self->get_file || $self->get_nodeball_dir;

}

=head2 C<expandNodeball>

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

This is a method.

It installs nodes stored as XML in the nodeballs.

Takes two optional arguments.  The first is the path to the nodeball directory. The second is a regular expression of node paths to avoid.

Returns undef.

=cut

sub install_xml_nodes {

    my ( $self, $select_cb ) = @_;

    $select_cb ||= sub { 1 };
    my $iterator = $self->make_node_iterator($select_cb);

    while ( my $xmlnode = $iterator->() ) {
        xml2node( $xmlnode->get_raw_xml );
    }

    return;

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

=cut



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

=cut


=head2 C<update_nodeball>

We already have this nodeball in the system, and we need to figure out which
files to add, remove, and update.

=cut

sub update_nodeball {
    my ( $self, $OLDBALL, $dir ) = @_;

    my $DB = $self->get_nodebase
      || Everything::Exception::NoNodeBase->throw("No nodebase here!");
    $dir ||= $self->get_nodeball_dir;
    my $NEWBALL = $self->nodeball_xml;

    my $script_dir = $dir . "/scripts";
    my $preinst    = $script_dir . "/preupdate.pl";
    require $preinst if -f $preinst;

    #check the tables and make sure that they're compatable

    $self->insert_sql_tables($dir);

    my $nodesdir      = $dir . "/nodes";
    my @nodes         = ();
    my @conflictnodes = ();

    use File::Find;

    # XXX: for this to work we need to split XML::xml2node so that
    # inserting into the database and creating functions from nodes
    # are not going through the same function

    # XXXX: xmlFinal also calls update
    find sub {
        my $file = $File::Find::name;
        return unless $file =~ /\.xml$/;
        ## no final means we don't insert the node into the db.
        my $info = xmlfile2node( $file, 'nofinal' );
        push @nodes, @$info if $info;
    }, $nodesdir;

    #check to make sure all dependencies are installed

    # create a hash of the old nodegroup -- better lookup times
    my (%oldgroup);
    foreach my $id ( @{ $$OLDBALL{group} } ) {
        $oldgroup{$id} = $DB->getNode($id);
    }

    ### get all the old noball members.
    my $nbmembers = buildNodeballMembers($OLDBALL);
    my $new_nbfile;
    foreach my $node_id (@nodes) {
        my $N = $DB->getNode($node_id);
        next
          if $$N{type}{title} eq 'nodeball'
          and $$N{title}      eq $$NEWBALL{title};

        # XXX: According to Node.pm, this is supposed to get called on
        # a dummy node, but here we're calling it on a node retrieved
        # from the DB. Something won't work.

        my $OLDNODE = $N->existingNodeMatches();
        if ($OLDNODE) {
            next if $$N{type}{title} eq 'nodeball';
            if ( $oldgroup{ $OLDNODE->getId() } ) {
                delete $oldgroup{ $OLDNODE->getId() };
            }

            if ( $$nbmembers{ $OLDNODE->getId() } ) {
                my $OTHERNB = $DB->getNode( $$nbmembers{ $OLDNODE->getId() } );
                next
                  unless confirmYN(
"$$OLDNODE{title} ($$OLDNODE{type}{title}) is also included in the \"$$OTHERNB{title}\" nodeball.  Do you want to replace it (N/y)?"
                  );
            }
            if ( not $OLDNODE->conflictsWith($N) ) {
                $OLDNODE->updateFromImport( $N, -1 );
            }
            else {
                push @conflictnodes, $N;
            }
        }
        else {
            if ( $$N{type}{title} eq 'nodeball' ) {
                print
"shoot!  Your nodeball says it needs $$N{title}.  You need to go get that.";
                die unless $self->FORCE;
            }
            $N->xmlFinal();
        }
    }

    fixNodes(0);

    #fix broken dependancies

    handleConflicts( \@conflictnodes, $NEWBALL );

    #insert the new nodeball
    $OLDBALL->updateFromImport( $NEWBALL, -1 );

    #find the unused nodes and remove them
    foreach ( values %oldgroup ) {
        my $NODE = $DB->getNode($_);

        next unless ($NODE);

        #we should probably confirm this
        #$NODE->nuke(-1);
    }
    fixNodes(1);

    my $postinst = $script_dir . "/postupdate.pl";
    require $postinst if -f $postinst;

    installModules($dir);

    print "$$OLDBALL{title} updated.\n";
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

    return unless ( -e $dir and -d $dir and !( -l $dir ) );
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

1;
