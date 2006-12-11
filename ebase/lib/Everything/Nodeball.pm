
=head1 Everything::Nodeball

Functions used by nbmasta and everything_install	

=cut

package Everything::Nodeball;

use strict;
use Everything qw/:all/;
use Everything::XML qw/xmlfile2node fixNodes/;

our %OPTIONS;

use base 'Exporter';

our @EXPORT_OK = qw(
		%OPTIONS
		setupOptions
		removeNodeball
		updateNodeball
		installNodeball
		installModules
		handleConflicts
		getPMdir
		checkDeps
		cleanUpDir
		createDir
		absPath
		buildNodeballMembers
		expandNodeball
		createNodeball
		exportNodes
		checkedNamedTables
		checkTables
		compareAllTables
		getColumns
		getTablesHashref
		addTablesToDB
		dropDB
		createDB
		confirmYN
		exportTables
		buildSqlCmdline
		printSettings
	);

our %EXPORT_TAGS = ( all => \@EXPORT_OK );

=cut


=head2 C<setupOptions>

set up our command line options hash %OPTIONS

=over 4

=item * $defaults

a hashref of defaults

=item * $args 

an arrayref of (presumably) ARGV

=back

Returns nothing, but the exported symbol %OPTIONS is initialized.  Any options
are removed from the @ARGV.

=cut

sub setupOptions
{
	my ( $defaults, $args ) = @_;

	@OPTIONS{ keys %$defaults } = values %$defaults;

	while ( @$args and $$args[0] =~ s/^\-(.*?)/$1/ )
	{
		my $arg = shift @$args;
		if ( $arg =~ s/^-(.*?)/$1/ )
		{
			$OPTIONS{$arg}++ if exists( $OPTIONS{$arg} );
			next;
		}
		$OPTIONS{verbose}++ if ( $arg =~ /v/ );
		if ( $arg =~ /u/ )
		{
			$OPTIONS{user} = shift @$args;
		}
		if ( $arg =~ /p/ )
		{
			$OPTIONS{password} = shift @$args;
		}
		if ( $arg =~ /h/ )
		{
			$OPTIONS{host} = shift @$args;
		}
	}

	"";
}

=cut


=head2 C<buildSqlCmdline>

This script has to call mysqldump and mysql a few different times, this
function builds the command line options

=cut

sub buildSqlCmdline
{
	my $sql;
	$sql .= " -u $OPTIONS{user} ";
	$sql .= " -p$OPTIONS{password} " if $OPTIONS{password};
	$sql .= " --host=$OPTIONS{host} " if $OPTIONS{host};

	$sql;
}

=cut


=head2 C<exportTables>

This dumps the table structures in the given database using the mysqldump
utility.  We do not dump the table row data, since we are using XML to store
the database info.

=cut

sub exportTables
{
	my ( $tables, $dir ) = @_;
	my $args = "--lock-tables --no-data";

	my $tbstr = join( " ", @$tables );

	# We need to make the directory writable, because mysql may be
	# running as the mysql user rather than root, and it will need
	# write permissions.
	my $mode = 0766;
	chmod $mode, $dir;

	my $sqlcommand =
		"mysqldump" . buildSqlCmdline . " -T $dir $args $DB->{dbname} $tbstr";
	my $err = `$sqlcommand`;
	chomp $err;

	# do another chmod here so it's not as ugly?
	$err =~ s/^ *//g;    # clear out any whitespace

	if ( $err ne "" )
	{
		print "mysqldump errors:\n" . $err;
		die unless $OPTIONS{force};
	}
}

=cut


=head2 C<confirmYN>

ask a yes no question (the sole parameter) return 0 if user answers false
(default) otherwise return 1

=cut

sub confirmYN
{
	my ($q) = @_;
	print "$q (N/y)";
	my $ans = <STDIN>;
	return 1 if $ans =~ /^y/i;
	return 0;
}

=cut


=head2 C<createDB>

Create a database of the given name

=cut

sub createDB
{
	my ($dbname) = @_;
	$DB->getDatabaseHandle()->do("create database $dbname");
}

=cut


=head2 C<dropDB>

Drop a database (does not give warnings)

=cut

sub dropDB
{
	my ($dbname) = @_;
	$DB->getDatabaseHandle()->do("drop database $dbname");
}

=cut


=head2 C<addTablesToDB>

Adds specific tables to a database from a directory of create definitions.  If
no tables are specified, all are imported.  Only tables listed in $TABLES array
ref are used, if it's passed.	

=cut

sub addTablesToDB
{
	my ( $dbname, $tabledir, $TABLES ) = @_;

	my %filter = map { $_ => 1 } @$TABLES;
	opendir DIR, $tabledir || die "can't opendir $tabledir $!";
	my $file;
	my @tablefiles;
	while ( defined( $file = readdir(DIR) ) )
	{
		if ( $file =~ /(.*?)\.sql$/ )
		{
			my $tbname = $1;
			if (@$TABLES)
			{
				next unless ( defined( $filter{$tbname} ) );
			}
			print "adding $tbname to $dbname\n" if $OPTIONS{verbose};
			system "mysql " . buildSqlCmdline() . "$dbname<$tabledir/$file";
			push @tablefiles, $file;
		}
	}
	closedir DIR;
	return @tablefiles;
}

=cut


=head2 C<getTablesHashref>

Get the list of tables (actually a hash reference) for the given database.

=cut

sub getTablesHashref
{
	my ($db) = @_;

	my $tempdbh = DBI->connect( "DBI:mysql:$db:$OPTIONS{host}",
		$OPTIONS{user}, $OPTIONS{password} );
	die "could not connect to database $db" unless $tempdbh;

	my $st = $tempdbh->prepare("show tables");
	$st->execute;
	my %tables;
	while ( my $ref = $st->fetchrow_arrayref )
	{
		$tables{ $ref->[0] } = 1;
	}
	$st->finish;
	$tempdbh->disconnect;
	return \%tables;
}

=cut


=head2 C<getColumns>
	
get the column information for a given table as a HOH with fieldname as key

=cut

sub getColumns
{
	my ( $table, $dbname ) = @_;

	my $tempdbh = DBI->connect( "DBI:mysql:$dbname:$OPTIONS{host}",
		$OPTIONS{user}, $OPTIONS{password} );
	my $st = $tempdbh->prepare("show columns from $table");
	$st->execute;

	my %colhash;
	while ( my $ref = $st->fetchrow_hashref )
	{
		my $temp = $ref->{"Field"};
		foreach ( keys %$ref )
		{
			$colhash{$temp}{$_} = $ref->{$_};
		}
	}
	$st->finish;
	$tempdbh->disconnect;
	\%colhash;
}

=cut


=head2 C<compareAllTables>

Compare the tables of the two database, making db1 the same as db2 or spitting
out errors as to what the difference is.

=over 4

=item * checktab

hashref of tables to be checked

=item * dummytab

hashref of tables to be checked against (assumed correct)

=item * checkdb

name of db to be checked

=item * dummydb

name of db to check against

=item * tabledir

where all the tables are hiding

=back

=cut

sub compareAllTables
{
	my $ok = 1;
	my ( $checktab, $dummytab, $dummydb, $checkdb, $tabledir ) = @_;
	foreach my $table ( keys %$dummytab )
	{
		unless ( $checktab->{$table} )
		{
			print "$checkdb is missing the $table table -- adding it\n";
			addTablesToDB( $checkdb, $tabledir, [$table] );
			next;
		}

		my %dummyhash = %{ getColumns( $table, $dummydb ) };
		my %checkhash = %{ getColumns( $table, $checkdb ) };

		foreach ( keys %dummyhash )
		{
			if ( $checkhash{$_} )
			{
				foreach my $value ( keys %{ $dummyhash{$_} } )
				{
					my $dummyval = $dummyhash{$_}{$value};
					if (    exists( $checkhash{$_} )
						and defined( $checkhash{$_}{$value} )
						and $checkhash{$_}{$value} ne $dummyval )
					{
						$ok = 0;
						print "Discrepancy found\n";
						print "\tTable: $table\n";
						print "\tColumn: $_\n";
						print "\tCategory $value\n";
						print
"\t$dummydb value=$dummyhash{$_}{$value} $checkdb value=$checkhash{$_}{$value}\n";

						#we would want to do an ALTER TABLE modify here
					}
				}
			}
			else
			{
				print "table $table in $checkdb is missing column $_\n";
				$ok = 0;

				#alter table add here
			}
		}
		foreach ( keys %checkhash )
		{
			next if ( $dummyhash{$_} );
			print "$checkdb table $table has extra column \"$_\"\n";

			#an extra table isn't necessarily bad
		}
	}
	return $ok;
}

=cut


=head2 C<checkTables>

Checks to see if the tables in the target database are equivalent to the tables
in the sql files.  Does this by creating a dummy database dumping the tables
into it, and comparing them with show table and show field statements.

=cut

sub checkTables
{
	my ($tabledir) = @_;
	my $dummydb = "dummy" . int( rand(1000) );

	my $database = $DB->{dbname};

#initEverything($database.":$OPTIONS{user}:$OPTIONS{password}:$OPTIONS{host}", 1);
	createDB $dummydb;
	addTablesToDB $dummydb, $tabledir;
	my $ret = compareAllTables(
		getTablesHashref($database),
		getTablesHashref($dummydb),
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

=cut

sub checkNamedTables
{
	my ( $tables_ref, $dir ) = @_;
	my $dummydb  = "dummy" . int( rand(1000) );
	my $database = $DB->{dbname};

	initEverything(
		$database . ":$OPTIONS{user}:$OPTIONS{password}:$OPTIONS{host}", 1 );
	createDB($dummydb);
	addTablesToDB( $dummydb, $dir, $tables_ref );
	my $ret = compareAllTables(
		getTablesHashref($database),
		getTablesHashref($dummydb),
		$dummydb, $database, $dir
	);
	dropDB($dummydb);

	initEverything(
		$database . ":$OPTIONS{user}:$OPTIONS{password}:$OPTIONS{host}", 1 );
	return $ret;
}

=cut


=head2 C<createDir>

Create a new directory, if you can, else barf.

=cut

sub createDir
{
	my ($dir) = @_;
	unless ( -e $dir )
	{
		my $mode = 0777;
		my $result = mkdir $dir, $mode;
		die "error creating $dir: $!"
			if ( !$result and !$OPTIONS{force} );
	}
	else
	{
		die "$dir already exists" unless $OPTIONS{force};
	}
	return 1;
}

=cut


=head2 C<exportNodes>

This function constructs our everything nodes (table joins, etc) and exports
each node in XML format into its own file.  The node XML files are put in
directories based on their nodetypes.  For example, the node "root" will be
exported to nodes/user/root.xml.

=over 4

=item * nodes

ref to an array of node ID's (do not pass node refs!)

=item * basedir

the dir to export them to

=item * loud

print a message for each node	

=item * dev

true if this is a dev export.  If so, this will only export nodes that have a
modified time greater than zero (only the nodes that you have touched)

=back

=cut

sub exportNodes
{
	my ( $nodes, $basedir, $loud, $dev ) = @_;
	my %nodetypes = ();
	my %nodeindex = ();
	my @nodefiles = ();

	$dev ||= 0;

	for ( my $i = 0 ; $i < @$nodes ; $i++ )
	{
		my $ID = $$nodes[$i];
		my $N  = getNode($ID);
		push @{ $nodetypes{ $$N{type}{title} } }, $ID
			if ( not $dev or $$N{modified} =~ /[1-9]/ );
		$nodeindex{$ID} = $i;
	}

	foreach my $NODETYPE ( keys %nodetypes )
	{
		my $dir = $NODETYPE;

		# convert spaces to '_'. We don't want spaces in the file name.
		$dir =~ tr/ /_/;
		$dir = $basedir . '/' . $dir;
		createDir $dir unless ( -e $dir );
		foreach my $N ( @{ $nodetypes{$NODETYPE} } )
		{
			my $NODE = getNode($N);
			next unless ($NODE);

			# If this is a dev export and the modified is all zeros
			# then this node needs to be skipped.
			next if ( $dev && ( not( $$NODE{modified} =~ /[1-9]/ ) ) );
			my $file = $$NODE{title};
			$file =~ tr/ /_/;

			$file .= ".xml";

			print "$$NODE{title} ($$NODE{type}{title}) --> $file\n"
				if $OPTIONS{verbose};

			$file = $dir . "/" . $file;

			# We want to concat any new stuff onto the end of the file.
			# This way, if the file already exists, we are just adding
			# a new node to the file.
			open( FILE, ">>" . $file )
				or die "couldn't create $file in $dir - do we have permission?";
			print FILE $NODE->toXML();

			close(FILE);

			my $index = $nodeindex{ getId($NODE) };
			$nodefiles[$index] = $file;
		}
	}
	@nodefiles;
}

=cut


=head2 C<printSettings>

Print the settings of the current nodeball

=cut

sub printSettings
{
	my ($VARS) = @_;

	foreach ( keys %$VARS )
	{
		print "$_ :\t$$VARS{$_}\n";
	}
	print "\n";
}

=cut


=head2 C<createNodeball>

Take a given directory, and tar-gzip it -- as a nodeball

=over 4

=item * dir

directory of stuff

=item * NODEBALL

filename to create file for

=back

=cut

sub createNodeball
{
	my ( $dir, $NODEBALL ) = @_;

	my $VARS    = $NODEBALL->getVars();
	my $version = $$VARS{version};

	my $filename = $$NODEBALL{title};
	$filename =~ tr/ /_/;
	$filename .= "-$version" if $version;
	$filename .= ".nbz";
	use Cwd;
	my $cwd = getcwd;
	$cwd .= '/' . $filename;

	chdir $dir;

	`tar -cvzf $cwd *`;
	chdir getcwd;

	print "\n$filename created\n";
}

=cut


=head2 C<expandNodeball>

Take a tar-gziped nodeball and expand it to a dir in /tmp return the directory

=cut

sub expandNodeball
{
	my ($nbfile) = @_;

	die "Can't seem to see the nodeball: $nbfile" unless ( -e $nbfile );
	my $dir = "/tmp/everything" . int( rand(1000) );
	createDir($dir);

	use Cwd;
	my $cwd = getcwd;

	#make the file abs path
	$nbfile = $cwd . "/" . $nbfile unless ( $nbfile =~ /^\// );
	$nbfile = absPath($nbfile);

	chdir $dir;
	my @files = `tar -xvzf $nbfile`;
	if ( $OPTIONS{verbose} )
	{
		foreach (@files) { print $_; }
	}

	chdir $cwd;
	return $dir;
}

=cut


=head2 C<buildNodeballMembers>

Builds a hash of node_id-E<gt>nodeball that it belongs to.  The nodeball(s)
that are sent as parameters are to be discluded.  This way we can see if a node
is in more than one nodeball -- where potential conflicts might emerge.
Returns a hash reference

Takes any nodeball(s) that should be excluded from the hash.

=cut

sub buildNodeballMembers
{
	my (@EXCLUDES) = @_;

	my %excl;
	foreach (@EXCLUDES)
	{
		$excl{ getId($_) } = 1;
	}

	#we build a hash to make lookups easier.

	my $NODEBALLS =
		getNodeWhere( { type_nodetype => getType('nodeball') }, 'nodeball' );

	my %nbmembers;
	foreach (@$NODEBALLS)
	{
		next if $excl{ getId($_) };
		my $group = $$_{group};
		foreach my $member (@$group)
		{
			$nbmembers{$member} = getId($_);
		}
	}

	return \%nbmembers;
}

=cut


=head2 C<absPath>

Get the absolute path of the file or directory.

=cut

sub absPath
{
	my ($file) = @_;

	#thank you Perl Cookbook!
	$file =~ s{ ^ ~ ( [^/]* ) }
	{ $1
		? (getpwnam($1))[7]
			: ( $ENV{HOME} || $ENV{LOGDIR}
					|| (getpwuid($>))[7]
			  )
	}ex;

	#make the file abs path
	use File::Spec::Unix;
	return File::Spec::Unix->rel2abs($file);
}

=cut


=head2 C<cleanUpDir>

Removes a specified directory.

=cut

sub cleanUpDir
{
	my ($dir) = @_;

	#don't let this bite you in the ass

	return unless ( -e $dir and -d $dir and !( -l $dir ) );
	use File::Path;
	rmtree($dir);
}

=cut


=head2 C<checkDeps>

Checks dependencies of a node for the given nodeball.  If there is a dependent
node, not in core or in a referenced nodeball dependency, we can throw a
warning during export

=over 4

=item * NODEBALL

the nodeball 

=back

=cut

sub checkDeps
{
	my ($NODEBALL) = @_;

	my %nodes;
	local *buildDeplist = sub {
		my ($NB) = @_;
		getRef($NB);
		return if $nodes{ getId($NB) };
		$nodes{ getId($NB) } = 1;
		foreach ( @{ $$NB{group} } )
		{
			my $NODE = getNode($_);
			next unless ref $NODE;
			$nodes{ $NODE->getId() } = 1;
			if ( $$NODE{type}{title} eq 'nodeball' )
			{
				buildDeplist($NODE);
			}
		}
	};
	buildDeplist($NODEBALL);

	#we don't care if a dep is in the core
	my $CORE      = getNode( 'core system', 'nodeball' );
	my $coregroup = $$CORE{group};

	my %inCore;
	foreach (@$coregroup)
	{
		$inCore{$_} = 1;
	}

	foreach ( @{ $$NODEBALL{group} } )
	{
		my $NODE = getNode($_);
		next unless ( ref $NODE );

		my $exportFields = $NODE->getNodeKeys(1);

		foreach my $key ( keys %$exportFields )
		{
			next unless ( $key =~ /_(\w+)$/ and $1 ne "id" );
			next unless ( $$NODE{$key} );

			# eliminate if it's in our dependancies
			next if ( $nodes{ $$NODE{$key} } );

			# warning: this doesn't take into account different core versions
			# eliminate it if it's in the core node
			next if exists( $inCore{ $$NODE{$key} } );

			# Also skip it if it is a -1.  -1 is a flag that it "inherits"
			# (mostly used by nodetypes).
			next if ( $$NODE{$key} eq "-1" );

			my $N = getNode( $$NODE{$key} );
			print "$$N{title} ($$N{type}{title}) is referenced by "
				. "$$NODE{title}, but is not included as a dependancy\n";
		}
	}
}

=cut


=head2 C<installNodeball>

=cut

sub installNodeball
{
	my ($dir) = @_;

	print "Installing nodeball.  Hang on.\n";

	my $script_dir = $dir . "/scripts";
	my $preinst    = $script_dir . "/preinstall.pl";
	require $preinst if -f $preinst;

	my $tables_dir = $dir . "/tables";

	#import any tables that need it
	use File::Find;

	my ( @add_tables, @check_tables );
	if ( -e $tables_dir )
	{
		print "Creating tables...\n";
		find sub {
			my ($file) = $File::Find::name;
			if ( $file =~ /sql$/ )
			{
				push @add_tables, $file;
			}
		}, $tables_dir;
		print "   - Done.\n";
	}

	my $curr_tables = getTablesHashref( $DB->{dbname} );
	foreach my $table (@add_tables)
	{
		next unless ( $table =~ m!/(\w+)\.sql$! );
		my $no_path = $1;

		if ( exists $curr_tables->{$no_path} )
		{
			print "Skipping already installed table $no_path!\n";
			push @check_tables, $no_path;
			next;
		}
		else
		{
			system "mysql " . buildSqlCmdline() . $DB->{dbname} . " < $table";
		}
	}

	if (@check_tables)
	{
		my $check = checkNamedTables( \@check_tables, $tables_dir );
		print "Skipped tables have the right columns, though!\n" if ($check);
	}
	my $nodetypes_dir = $dir . "/nodes/nodetype";

	if ( -e $nodetypes_dir )
	{
		print "Installing nodetypes...\n";
		find sub {
			my ($file) = $File::Find::name;
			xmlfile2node($file) if $file =~ /\.xml$/;
			},
			$nodetypes_dir
			if -e $nodetypes_dir;
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
	find sub {
		my ($file)    = $File::Find::name;
		my ($currDir) = $File::Find::dir;

		# Don't do the nodetypes again!  We already installed them and fixed
		# some of their references.  If we install them again, they will be
		# broken for the rest of the nodes that we need to install.
		return if ( $currDir =~ /nodes\/nodetype/ );

		xmlfile2node($file) if $file =~ /\.xml$/;
	}, $dir;

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

sub installModules
{
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
		if ( $file =~ /pm$/ )
		{
			( $_ = $file ) =~ s!.+?Everything/!!;
			print "Copying $file\n   to " . $includeDir . "/" . $_ . "\n";
			copy( $file, $includeDir . "/" . $_ );
			$result = 1;
		}
	}, $e_dir;

	return $result;
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

sub getPMDir
{
	my $includeDir;
	my $edir;

	foreach $includeDir (@INC)
	{
		$edir = $includeDir . "/Everything";
		return $includeDir if ( -e $edir );
	}

	return undef;
}

=cut


=head2 C<handleConflicts>

We have a list of nodes that have potentially been edited since our last
update.  We need to "safely" handle them nodes that can be workspaced, will --
nodes that cannot are confirmed by user.

=cut

sub handleConflicts
{
	my ( $CONFLICTS, $NEWBALL ) = @_;

	my @workspaceable;

	foreach (@$CONFLICTS)
	{
		push( @workspaceable, $_ ), next if $_->canWorkspace;

		my $yesno;
		my $N = $_->existingNodeMatches();
		$N->updateFromImport( $_, -1 )
			if confirmYN(
"$$_{title} ($$_{type}{title}) has been modified, seems to conflict with the new nodeball, and cannot be workspaced.\nDo you want me to update it anyway? (N/y)\n"
			);
	}

	return unless @workspaceable;

	#the rest we put in a workspace
	my $ROOT = getNode( 'root', 'user' );
	my $NBV  = $NEWBALL->getVars;
	my $WS   = getNode( "$$NEWBALL{title}-$$NBV{version} changes",
		"workspace", "create" );
	$WS->insert($ROOT);
	$DB->joinWorkspace($WS);

	print "The following nodes may have conflicts:\n";
	foreach (@workspaceable)
	{
		print "\t$$_{title} ($$_{type}{title})\n";
		my $N = $_->existingNodeMatches();
		$N->updateFromImport( $_, -1 );
	}
	print
"\nThe new versions have been put in workspace \"$$WS{title}\"\nJoin that workspace as the root user to test and commit or discard the changes\n";

	$DB->joinWorkspace(0);
	"";
}

=cut


=head2 C<updateNodeball>

We already have this nodeball in the system, and we need to figure out which
files to add, remove, and update.

=cut

sub updateNodeball
{
	my ( $OLDBALL, $NEWBALL, $dir ) = @_;

	#check the tables and make sure that they're compatable
	my $script_dir = $dir . "/scripts";
	my $preinst    = $script_dir . "/preupdate.pl";
	require $preinst if -f $preinst;

	my $tabledir = $dir . "/tables";
	unless ( not -d $tabledir or checkTables($tabledir) or $OPTIONS{force} )
	{
		die "your tables weren't exactly alike.  Change your tables in the "
			. "mysql client or use --force";
	}

	my $nodesdir      = $dir . "/nodes";
	my @nodes         = ();
	my @conflictnodes = ();

	use File::Find;
	find sub {
		my $file = $File::Find::name;
		my $info = xmlfile2node( $file, 'nofinal' );
		push @nodes, @$info if $info;
	}, $nodesdir;

	#check to make sure all dependencies are installed

	# create a hash of the old nodegroup -- better lookup times
	my (%oldgroup);
	foreach my $id ( @{ $$OLDBALL{group} } )
	{
		$oldgroup{$id} = getNode($id);
	}

	my $nbmembers = buildNodeballMembers($OLDBALL);
	my $new_nbfile;
	foreach my $N (@nodes)
	{
		next
			if $$N{type}{title} eq 'nodeball'
			and $$N{title}      eq $$NEWBALL{title};

		#we'll take care of this later

		my $OLDNODE = $N->existingNodeMatches();
		if ($OLDNODE)
		{
			next if $$N{type}{title} eq 'nodeball';
			if ( $oldgroup{ getId($OLDNODE) } )
			{
				delete $oldgroup{ getId($OLDNODE) };
			}

			if ( $$nbmembers{ getId($OLDNODE) } )
			{
				my $OTHERNB = getNode $$nbmembers{ getId($OLDNODE) };
				next
					unless confirmYN(
"$$OLDNODE{title} ($$OLDNODE{type}{title}) is also included in the \"$$OTHERNB{title}\" nodeball.  Do you want to replace it (N/y)?"
					);
			}
			if ( not $OLDNODE->conflictsWith($N) )
			{
				$OLDNODE->updateFromImport( $N, -1 );
			}
			else
			{
				push @conflictnodes, $N;
			}
		}
		else
		{
			if ( $$N{type}{title} eq 'nodeball' )
			{
				print
"shoot!  Your nodeball says it needs $$N{title}.  You need to go get that.";
				die unless $OPTIONS{force};
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
	foreach ( values %oldgroup )
	{
		my $NODE = getNode($_);

		next unless ($NODE);

		#we should probably confirm this
		#$NODE->nuke(-1);
	}
	fixNodes(1);

	my $postinst = $script_dir . "/postupdate.pl";
	require $postinst if -f $postinst;

	installModules($dir);

	print "$$NEWBALL{title} updated.\n";
}

=cut


=head2 C<removeNodeball>

Kill the sucka!

=cut

sub removeNodeball
{
	my ($DOOMEDBALL) = @_;

	# we need the root user so we can nuke nodes successfully
	my $root      = $DB->getNode( 'root', 'user' );
	my $doomed_id = $DB->getId($DOOMEDBALL);

	unless ( $OPTIONS{force} )
	{

		# we should also check dependencies -- am I in any other nodeballs?
		# this technique avoids 'out of memory' errors

		my $nodeballs =
			$DB->getNodeWhere( { 1 => 1 }, $DB->getType('nodeball') );

		my $depends;

		foreach my $nodeball (@$nodeballs)
		{
			if ( $nodeball->inGroup($doomed_id) )
			{
				my $version = $nodeball->getVars(-1)->{version};

				warn qq|Nodeball "$nodeball->{title}" ($version) depends on |
					. qq|"$DOOMEDBALL->{title}".\n|;
				$depends++;
			}
		}

		die qq|Cannot remove "$DOOMEDBALL->{title}".\nRemove $depends |
			. qq|dependencies first or use --force.\n|
			if $depends;

		print "Are you sure you want to remove $DOOMEDBALL->{title}?\n";
		my $yesno = <STDIN>;
		exit unless $yesno =~ /^y/i;
	}

	foreach my $node ( @{ $DOOMEDBALL->{group} } )
	{
		my $N = getNode($node);
		unless ( defined $N )
		{
			Everything::logErrors( '',
				      'Cannot fetch node "'
					. ( defined $node ? $node : 'UNDEF' )
					. '"' );
			next;
		}

		# don't remove dependancies
		next if $N->{type}{title} eq 'nodeball';

		print qq|Removing "$N->{title}" ($N->{type}{title})...\n|
			if $OPTIONS{verbose};
		$N->nuke($root)
			or Everything::logErrors( '', "Can't nuke $N->{title}!" );
	}

	$DOOMEDBALL->nuke($root);
	print "$DOOMEDBALL->{title} removed\n";
}

1;
