package Everything::Nodeball;

#############################################################################
#	Everything::Nodeball
#		Functions used by nbmasta and everything_install	
#

use strict;
use Everything;
use Everything::XML;


use vars qw(%OPTIONS);

sub BEGIN
{
	use Exporter();
	use vars qw($VERSIONS @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
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
}


#############################################################################
#
#	setupOptions
#
#	purpose
#		set up our command line options hash %OPTIONS
#	
#	params
#		a hashref of defaults, and an arrayref of (presumably) ARGV
#
#	returns 
#		nothing, but the exported symbol %OPTIONS is initialized
#		also, any options are removed from the @ARGV
#
sub setupOptions {
	my ($defaults, $args) = @_;

	@OPTIONS{keys %$defaults} = values %$defaults;

	while (@$args and $$args[0] =~ s/^\-(.*?)/$1/) {
		my $arg = shift @$args;
		if ($arg =~ s/^-(.*?)/$1/) {
			$OPTIONS{$arg}++ if exists ($OPTIONS{$arg});
			next;
		}
		$OPTIONS{verbose}++ if ($arg =~ /v/);
		if ($arg =~ /u/) {
			$OPTIONS{user} = shift @$args;
		}
		if ($arg =~ /p/) {
			$OPTIONS{password} = shift @$args;
		}
		if ($arg =~ /h/) {
			$OPTIONS{host} = shift @$args;
		}
	}

	"";
}

#############################################################################
#	Function
#		buildSqlCmdline
#
#	Purpose
#		This script has to call mysqldump and mysql a few different
#		times, this function builds the command line options
#
sub buildSqlCmdline {
	my $sql;
	$sql .= " -u $OPTIONS{user} ";
	$sql .= " -p$OPTIONS{password} " if $OPTIONS{password};
	$sql .= " --host=$OPTIONS{host} " if $OPTIONS{host};
	
	$sql;
}

#############################################################################
#	Function
#		exportTables
#
#	Purpose
#		This dumps the table structures in the given database using the
#		mysqldump utility.  We do not dump the table row data, since we
#		are using XML to store the database info.
#
sub exportTables {
	my ($tables, $dir) = @_;
	my $args = "--lock-tables --no-data";

	my $tbstr = join(" ", @$tables);

	# We need to make the directory writable, because mysql may be
	# running as the mysql user rather than root, and it will need
	# write permissions.
	my $mode = 0766;
	chmod $mode, $dir;

	my $sqlcommand = "mysqldump".buildSqlCmdline." -T $dir $args $DB->{dbname} $tbstr";
	my $err = `$sqlcommand`;
	chomp $err;
	# do another chmod here so it's not as ugly?
	$err =~ s/^ *//g;  # clear out any whitespace

	if($err ne "") {
		print "mysqldump errors:\n" . $err;
		die unless $OPTIONS{force};
	}
}

#############################################################################
#	sub 
#		confirmYN
#
#	ask a yes no question (the sole parameter) return 0 if user answers false
#	(default) otherwise return 1
#
sub confirmYN {
	my ($q) = @_;
	print "$q (N/y)";
	my $ans = <STDIN>;
	return 1 if $ans =~ /^y/i;
	return 0;
}


##############################################################################
#	sub
#		createDB
#
#	create a database of the given name
sub createDB{
	my ($dbname) = @_;
	$DB->getDatabaseHandle()->do("create database $dbname"); 
}

#############################################################################
#	sub
#		dropDB
#
#	drop a database (does not give warnings)
#
sub dropDB{
	my ($dbname) = @_;
   $DB->getDatabaseHandle()->do("drop database $dbname"); 
}

##########################################################################
#	sub
#		addTablesToDB	
#
#	adds specific tables to a database from a directory of create definitions
#	if no tables are specified, all are imported
#	Only tables listed in $TABLES array ref are used, if it's passed.	
sub addTablesToDB{
   my ($dbname, $tabledir, $TABLES) = @_;
   
	my %filter = map { $_ => 1 } @$TABLES;
	opendir DIR, $tabledir || die "can't opendir $tabledir $!";
	my $file; 
	my @tablefiles;
	while(defined($file=readdir(DIR))){
		if($file=~/(.*?)\.sql$/){
			my $tbname = $1;
			if (@$TABLES) {
				next unless (defined($filter{$tbname}));
			}
	 		print "adding $tbname to $dbname\n" if $OPTIONS{verbose};
			system "mysql ".buildSqlCmdline()."$dbname<$tabledir/$file"; 
			push @tablefiles, $file; 
		}
	}
	closedir DIR; 
	return @tablefiles;
}

###########################################################################
#	sub
#		getTablesHashref
#
#	get the list of tables (actually a hash reference) for the given database
#
sub getTablesHashref{
   my ($db)=@_; 
   
   my $tempdbh = DBI->connect("DBI:mysql:$db:$OPTIONS{host}", $OPTIONS{user}, $OPTIONS{password});
   die "could not connect to database $db" unless $tempdbh;
   
   my $st = $tempdbh->prepare("show tables");
   $st->execute;
   my %tables;
   while(my $ref=$st->fetchrow_arrayref){
      $tables{$ref->[0]}=1; 
   }
   $st->finish;
   $tempdbh->disconnect;
   return \%tables;
}

#######################################################################
#	sub
#		getColumns
#	
#	get the column information for a given table as a HOH 
#	with fieldname as key
#
sub getColumns {
	my ($table, $dbname) = @_;

    my $tempdbh = DBI->connect("DBI:mysql:$dbname:$OPTIONS{host}", $OPTIONS{user}, $OPTIONS{password});
	my $st=$tempdbh->prepare("show columns from $table");    
	$st->execute;
	
	my %colhash;
	while(my $ref=$st->fetchrow_hashref){
		my $temp=$ref->{"Field"}; 
		foreach(keys %$ref){
			$colhash{$temp}{$_}=$ref->{$_}; 
		}
	}
	$st->finish;
	$tempdbh->disconnect;
	\%colhash;
}


########################################################################
#	sub
#		compareAllTables
#
#	compare the tables of the two database, making db1 the same as db2
#	or spitting out errors as to what the difference is.
#
#	params
#		checktab -- hashref of tables to be checked
#		dummytab -- hashref of tables to be checked against (assumed correct)
#		checkdb	-- name of db to be checked
#		dummydb -- name of db to check against
#		tabledir -- where all the tables are hiding
#
sub compareAllTables{
   my $ok=1;  
   my($checktab,$dummytab, $dummydb, $checkdb, $tabledir)=@_;
   foreach my $table (keys %$dummytab){
	   unless($checktab->{$table}){
		   print "$checkdb is missing the $table table -- adding it\n"; 
		   addTablesToDB($checkdb, $tabledir, [$table]);
		   next;
	   }
	 
	   my %dummyhash = %{ getColumns ($table, $dummydb) };
	   my %checkhash = %{ getColumns ($table, $checkdb) };
	   
	   foreach (keys %dummyhash){
		   if($checkhash{$_}){
			   foreach my $value(keys %{$dummyhash{$_}}){
					my $dummyval = $dummyhash{$_}{$value};
					if (exists ($checkhash{$_}) and 
						defined ($checkhash{$_}{$value}) and 
						$checkhash{$_}{$value} ne $dummyval){
					   $ok=0;
					   print "Discrepancy found\n";
					   print "\tTable: $table\n";
					   print "\tColumn: $_\n";
					   print "\tCategory $value\n";
					   print "\t$dummydb value=$dummyhash{$_}{$value} $checkdb value=$checkhash{$_}{$value}\n"; 
				   		#we would want to do an ALTER TABLE modify here
				  } 
			   } 
		   } else {
			   print "table $table in $checkdb is missing column $_\n";  
			   $ok=0;
			   #alter table add here
		   } 
	   } 
	   foreach (keys %checkhash) {
			next if ($dummyhash{$_});
			print "$checkdb table $table has extra column \"$_\"\n";
	   		#an extra table isn't necessarily bad
	   }
   }
   return $ok;
}

##########################################################################
#	sub
#		checkTables
#
#	checks to see if the tables in the target database are equivalent
#	to the tables in the sql files.  Does this by creating a dummy database
#	dumping the tables into it, and comparing them with show table and show
#	field statements.
#
sub checkTables {
	my ($tabledir) = @_;
	my $dummydb="dummy" . int(rand(1000));

	my $database = $DB->{dbname};

	#initEverything($database.":$OPTIONS{user}:$OPTIONS{password}:$OPTIONS{host}", 1);
	createDB $dummydb;
	addTablesToDB $dummydb, $tabledir;
	my $ret = compareAllTables(getTablesHashref($database), getTablesHashref($dummydb),
		  $dummydb, $database, $tabledir);
	dropDB $dummydb;
	
	#initEverything($database.":$OPTIONS{user}:$OPTIONS{password}:$OPTIONS{host}", 1);
	$ret;
}

##########################################################################
#	sub
#		checkNamedTables
#
#	checks to see if the tables in the target database are equivalent
#	to the tables in the sql files.  Works just like checkTables, except
#	that it only checks files listed in the first argument, an array ref.
#
sub checkNamedTables {
	my ($tables_ref, $dir) = @_;
	my $dummydb="dummy" . int(rand(1000));
	my $database = $DB->{dbname};

	initEverything($database.":$OPTIONS{user}:$OPTIONS{password}:$OPTIONS{host}", 1);
	createDB($dummydb);
	addTablesToDB($dummydb, $dir, $tables_ref);
	my $ret = compareAllTables(getTablesHashref($database),
		getTablesHashref($dummydb),  $dummydb, $database, $dir);
	dropDB($dummydb);
	
	initEverything($database.":$OPTIONS{user}:$OPTIONS{password}:$OPTIONS{host}", 1);
	return $ret;
}

###########################################################################
#	sub
#		createDir
#
#	purpose
#		create a new directory.  If you can, else barf
#
sub createDir {
	my ($dir) = @_;
	unless (-e $dir) {
		my $mode = 0777;
		my $result = mkdir $dir, $mode;
		die "error creating $dir: $!" 
			if (!$result and !$OPTIONS{force});
	} else {
		die "$dir already exists" unless $OPTIONS{force};	
	}
	return 1;
}


#############################################################################
#	Function
#		exportNodes
#
#	Purpose
#		This function constructs our everything nodes (table joins, etc)
#		and exports each node in XML format into its own file.  The node
#		XML files are put in directories based on their nodetypes.  For
#		example, the node "root" will be exported to nodes/user/root.xml.
#
#	params
#		nodes - ref to an array of node ID's (do not pass node refs!)
#		basedir - the dir to export them to
#		loud - print a message for each node	
#		dev - true if this is a dev export.  If so, this will only export
#			nodes that have a modified time greater than zero (only the
#			nodes that you have touched)
#
sub exportNodes
{
	my ($nodes, $basedir, $loud, $dev) = @_;
	my %nodetypes=();
	my %nodeindex=();
	my @nodefiles=();

	$dev ||= 0;

	for(my $i =0; $i < @$nodes;$i++) {
		my $ID = $$nodes[$i];
		my $N = getNode($ID);
		push @{ $nodetypes{$$N{type}{title}} }, $ID
			if(not $dev or $$N{modified} =~ /[1-9]/);
		$nodeindex{$ID}=$i;
	}
	
	foreach my $NODETYPE (keys %nodetypes) {
		my $dir = $NODETYPE;
		
		# convert spaces to '_'. We don't want spaces in the file name.
		$dir =~ tr/ /_/;
		$dir = $basedir.'/'.$dir; 
		createDir $dir unless (-e $dir);	
		foreach my $N (@{ $nodetypes{$NODETYPE} }) {
			my $NODE = getNode($N);
			next unless($NODE);

			# If this is a dev export and the modified is all zeros
			# then this node needs to be skipped.
			next if($dev && (not ($$NODE{modified} =~ /[1-9]/)));
			my $file = $$NODE{title};
			$file =~ tr/ /_/;
			
			$file.=".xml";
			
			print "$$NODE{title} ($$NODE{type}{title}) --> $file\n"
				if $OPTIONS{verbose};

			$file = $dir."/".$file; 

			# We want to concat any new stuff onto the end of the file.
			# This way, if the file already exists, we are just adding
			# a new node to the file.
			open(FILE, ">>".$file) 
				or die "couldn't create $file in $dir - do we have permission?";
			print FILE $NODE->toXML();

			close(FILE);

			my $index = $nodeindex{getId($NODE)};
			$nodefiles[$index]= $file;
		}	
	}
	@nodefiles;
}

########################################################################
#	sub
#		printSettings
#
#	purpose
#		print the settings of the current nodeball
#
sub printSettings {
	my ($VARS) = @_;

	foreach (keys %$VARS) {
		print "$_ :\t$$VARS{$_}\n";	
	}
	print "\n";
}

#######################################################################
#	sub
#		createNodeball
#
#	purpose
#		take a given directory, and tar-gzip it -- as a nodeball
#
#	params
#		dir - directory of stuff
#		NODEBALL - filename to create file for
#
sub createNodeball {
	my ($dir, $NODEBALL) = @_;

	my $VARS = $NODEBALL->getVars();
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

###########################################################################
#	sub
#		expandNodeball
#
#	purpose
#		take a tar-gziped nodeball and expand it to a dir in /tmp
#		return the directory

sub expandNodeball {
	my ($nbfile) = @_;

	die "Can't seem to see the nodeball: $nbfile" unless (-e $nbfile);
	my $dir = "/tmp/everything".int(rand(1000));
	createDir($dir);	

	use Cwd;
	my $cwd = getcwd;

	#make the file abs path
	$nbfile = $cwd."/".$nbfile unless ($nbfile =~ /^\//);
	$nbfile = absPath ($nbfile);
	
	chdir $dir;
	my @files = `tar -xvzf $nbfile`;
	if ($OPTIONS{verbose}) {
		foreach (@files) {print $_;}
	}

	chdir $cwd;
	return $dir;
}


###########################################################################
#	sub
#	 	buildNodeballMembers	
#
#	builds a hash of node_id->nodeball that it belongs to.  The nodeball(s)
#	that are sent as parameters are to be discluded.  This way we can
#	see if a node is in more than one nodeball -- where potential conflicts
#	might emerge.  Returns a hash reference
#
#	params:  any nodeball(s) that should be excluded from the hash
#
#
sub buildNodeballMembers {
	my (@EXCLUDES) = @_;
	
	my %excl;
	foreach (@EXCLUDES) {
		$excl{getId($_)} = 1;
	}
	#we build a hash to make lookups easier.

	my $NODEBALLS = getNodeWhere({type_nodetype => getType('nodeball')}, 'nodeball');
	
	my %nbmembers;
	foreach (@$NODEBALLS) {
		next if $excl{getId($_)};
		my $group = $$_{group};
		foreach my $member (@$group) {
			$nbmembers{$member} = getId($_);	
		}
	}

	return \%nbmembers;
}


############################################################################
#	sub
#		absPath
#
#	get the absolute path of the file or directory
#
sub absPath {
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

############################################################################
#	sub 
#		cleanUpDir
#
#	purpose
#		removes a specified directory
#
sub cleanUpDir {
	my ($dir) = @_;
	#don't let this bite you in the ass

	return unless (-e $dir and -d $dir and !(-l $dir));
	use File::Path;
	rmtree($dir);
}

#############################################################################
#	sub
#		checkDeps
#
#	purpose	
#		checks dependencies of a node for the given nodeball
#		if there is a dependent node, not in core or in a referenced
#		nodeball dependency, we can throw a warning during export
#
#	params
#		NODEBALL -- the nodeball 
sub checkDeps {
	my ($NODEBALL) = @_;
	
	my %nodes;
	local *buildDeplist = sub {
		my ($NB) = @_;
		getRef($NB);
		return if $nodes{getId($NB)};
		$nodes{getId($NB)}=1;
		foreach (@{ $$NB{group} }) {
			my $NODE = getNode($_);
			next unless ref $NODE;
			$nodes{$NODE->getId()} = 1;
			if ($$NODE{type}{title} eq 'nodeball') {
				buildDeplist($NODE);
			}
		}
	};
	buildDeplist($NODEBALL);

	#we don't care if a dep is in the core
	my $CORE = getNode('core system', 'nodeball');
	my $coregroup = $$CORE{group};
	
	my %inCore;
	foreach (@$coregroup) {
		$inCore{$_} = 1;
	}

	foreach (@{ $$NODEBALL{group} })
	{
		my $NODE = getNode($_);
		next unless(ref $NODE);

		my $exportFields = $NODE->getNodeKeys(1);
		
		foreach my $key (keys %$exportFields)
		{
			next unless ($key =~ /_(\w+)$/ and $1 ne "id"); 
			next unless ($$NODE{$key});

			# eliminate if it's in our dependancies
			next if ($nodes{$$NODE{$key}});

			# warning: this doesn't take into account different core versions
			# eliminate it if it's in the core node
			next if exists($inCore{$$NODE{$key}});

			# Also skip it if it is a -1.  -1 is a flag that it "inherits"
			# (mostly used by nodetypes).
			next if($$NODE{$key} eq "-1");
			
			my $N = getNode($$NODE{$key});	
			print "$$N{title} ($$N{type}{title}) is referenced by " .
				"$$NODE{title}, but is not included as a dependancy\n";
		}
	}
}

############################################################################
#	sub
#		installNodeball
#
sub installNodeball {
	my ($dir) = @_;

	print "Installing nodeball.  Hang on.\n";

	my $script_dir = $dir."/scripts";
	my $preinst = $script_dir."/preinstall.pl";
	require $preinst if -f $preinst; 
	
	my $tables_dir = $dir."/tables";
	#import any tables that need it
	use File::Find;	

	my (@add_tables, @check_tables);
	if(-e $tables_dir)
	{
		print "Creating tables...\n";
		find sub {
			my ($file) = $File::Find::name;
				if ($file =~ /sql$/) {
					push @add_tables, $file;
				}
			}, $tables_dir;
		print "   - Done.\n";
	}

	my $curr_tables = getTablesHashref($DB->{dbname});
	foreach my $table (@add_tables) {
		next unless ($table =~ m!/(\w+)\.sql$!);
		my $no_path = $1;
		
		if (exists $curr_tables->{$no_path}) {
			print "Skipping already installed table $no_path!\n";
			push @check_tables, $no_path;
			next;
		} else {
			system "mysql ".buildSqlCmdline().$DB->{dbname}." < $table";
		}
	}

	if (@check_tables) {
		my $check = checkNamedTables(\@check_tables, $tables_dir);
		print "Skipped tables have the right columns, though!\n" if ($check);
	}
	my $nodetypes_dir = $dir."/nodes/nodetype";

	if(-e $nodetypes_dir)
	{
		print "Installing nodetypes...\n";
		find sub {
			my ($file) = $File::Find::name;
			xmlfile2node($file) if $file =~ /\.xml$/;  
			}, $nodetypes_dir if -e $nodetypes_dir;
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
	find sub  {
		my ($file) = $File::Find::name;
		my ($currDir) = $File::Find::dir;
		
		# Don't do the nodetypes again!  We already installed them and fixed
		# some of their references.  If we install them again, they will be
		# broken for the rest of the nodes that we need to install.
		return if($currDir =~ /nodes\/nodetype/);
		
		xmlfile2node($file) if $file =~ /\.xml$/;  
	}, $dir;

	print "Fixing references...\n";
	fixNodes(1);
	print "   - Done.\n";

	my $postinst = $script_dir."/postinstall.pl";
	require $postinst if -f $postinst;

	# install any .pm's that we might have
	installModules($dir);

	#we should give warnings if dependant 
	#nodeballs are not installed...  but we don't
}


#############################################################################
#	Sub
#		installModules
#
#	Purpose
#		Copy any perl modules that exist in this nodeball to the appropriate
#		install directory on the system.
#
#	Parameters
#		$dir - the base directory of this nodeball
#
#	Returns
#		1 if something was copied.  0 if no work was done.
#
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
	$e_dir .= "/" unless($e_dir =~ /\/$/);
	$e_dir .= "Everything";
	return $result unless(-e $e_dir && -d $e_dir);

	$includeDir = getPMDir() . "/Everything";
	
	# Copy all of the pm's to the system directory.
	find sub {
		my ($file) = $File::Find::name;
			if ($file =~ /pm$/)
			{
				($_ = $file) =~ s!.+?Everything/!!;
				print "Copying $file\n   to " . $includeDir . "/" . $_ . "\n";
				copy($file, $includeDir . "/" . $_);
				$result = 1;
			}
		}, $e_dir;

 	return $result;
}


#############################################################################
#	Sub
#		getPMDir
#
#	Purpose
#		When Everything is installed, the base perl modules are installed
#		somewhere on the system.  Where they are installed varies from
#		system to system, but they are always installed somewhere in the
#		standard perl include directories.  This searches through the
#		install directories until we find it.
#
#	Parameters
#		None
#
#	Returns
#		The include directory where Everything.pm and Everthing/ can be
#		found.  undef if we couldn't find it.
#
sub getPMDir
{
	my $includeDir;
	my $edir;
	
	foreach $includeDir (@INC)
	{
		$edir = $includeDir . "/Everything";
		return $includeDir if(-e $edir);
	}

	return undef;
}




###########################################################################
#
#	sub
#		handleConflicts
#
#	purpose 
#		we have a list of nodes that have potentially been edited since
#		our last update.  We need to "safely" handle them
#		nodes that can be workspaced, will -- nodes that cannot
#		are confirmed by user
#
sub handleConflicts {
	my ($CONFLICTS, $NEWBALL) = @_;

	my @workspaceable;

	foreach (@$CONFLICTS) {
		push(@workspaceable, $_), next if $_->canWorkspace;	
		
		my $yesno;	
		my $N = $_->existingNodeMatches();
		$N->updateFromImport($_, -1) if confirmYN("$$_{title} ($$_{type}{title}) has been modified, seems to conflict with the new nodeball, and cannot be workspaced.\nDo you want me to update it anyway? (N/y)\n");
	}

	return unless @workspaceable;
	#the rest we put in a workspace
	my $ROOT = getNode('root', 'user');
	my $NBV = $NEWBALL->getVars;
	my $WS = getNode("$$NEWBALL{title}-$$NBV{version} changes", "workspace", "create");
	$WS->insert($ROOT);
	$DB->joinWorkspace($WS);
	
	print "The following nodes may have conflicts:\n";
	foreach (@workspaceable) {
		print "\t$$_{title} ($$_{type}{title})\n"; 
		my $N = $_->existingNodeMatches();
		$N->updateFromImport($_, -1);
	}
	print "\nThe new versions have been put in workspace \"$$WS{title}\"\nJoin that workspace as the root user to test and commit or discard the changes\n";
	
	$DB->joinWorkspace(0);
	"";
}

############################################################################
#	sub 
#		updateNodeball
#
#	purpose
#		we already have this nodeball in the system, and we need to figure
#		out which files to add, remove, and update
#
sub updateNodeball {
	my ($OLDBALL, $NEWBALL, $dir) = @_;

	#check the tables and make sure that they're compatable
	my $script_dir = $dir ."/scripts";
	my $preinst = $script_dir ."/preupdate.pl";
	require $preinst if -f $preinst;
	
	my $tabledir = $dir."/tables";
	unless (not -d $tabledir or checkTables ($tabledir) or $OPTIONS{force}) { 
		die "your tables weren't exactly alike.  Change your tables in the "
		."mysql client or use --force";
	}

	my $nodesdir = $dir."/nodes";
	my @nodes = ();
	my @conflictnodes = ();
	
	use File::Find;
	find sub {
			my $file = $File::Find::name;
			my $info = xmlfile2node($file, 'nofinal');
			push @nodes, @$info if $info;
	  	}, $nodesdir;

	#check to make sure all dependencies are installed
	
	# create a hash of the old nodegroup -- better lookup times
	my (%oldgroup);
	foreach my $id (@{ $$OLDBALL{group} }) {
		$oldgroup{$id} = getNode($id);
	}
	
	my $nbmembers = buildNodeballMembers($OLDBALL);
	my $new_nbfile;
	foreach my $N (@nodes) {
		next if $$N{type}{title} eq 'nodeball' and $$N{title} eq $$NEWBALL{title};
		#we'll take care of this later
		
		my $OLDNODE = $N->existingNodeMatches(); 
		if ($OLDNODE) {
			next if $$N{type}{title} eq 'nodeball';
			if ($oldgroup{getId($OLDNODE)}) {
				delete $oldgroup{getId($OLDNODE)};
			} 

			if ($$nbmembers{getId($OLDNODE)}) {
				my $OTHERNB = getNode $$nbmembers{getId($OLDNODE)};
				next unless confirmYN("$$OLDNODE{title} ($$OLDNODE{type}{title}) is also included in the \"$$OTHERNB{title}\" nodeball.  Do you want to replace it (N/y)?");
			}
			if (not $OLDNODE->conflictsWith($N)) {
				$OLDNODE->updateFromImport($N, -1);	
			} else {
				push @conflictnodes, $N;
			}
		} else {
			if ($$N{type}{title} eq 'nodeball') {
				print "shoot!  Your nodeball says it needs $$N{title}.  You need to go get that.";
				die unless $OPTIONS{force};
			}
			$N->xmlFinal();
		}
	}
	
	fixNodes(0);
	#fix broken dependancies

	handleConflicts(\@conflictnodes, $NEWBALL);

	#insert the new nodeball
	$OLDBALL->updateFromImport($NEWBALL, -1);

	#find the unused nodes and remove them
	foreach (values %oldgroup) {
		my $NODE = getNode($_);

		next unless($NODE);

		#we should probably confirm this
		#$NODE->nuke(-1);
	}
	fixNodes(1);
	
	my $postinst = $script_dir."/postupdate.pl";
	require $postinst if -f $postinst;
	
	installModules($dir);
	
	print "$$NEWBALL{title} updated.\n";
}


############################################################################
#	sub 
#		removeNodeball
#
#	purpose
#		kill the sucka!
#
sub removeNodeball {
	my ($DOOMEDBALL) = @_;
	# we need the root user so we can nuke nodes successfully
	my $root = $DB->getNode('root', 'user');
	my $doomed_id = $DB->getId($DOOMEDBALL);
	my @members;

	#we should also check dependancies -- am I in any other nodeballs?
	# this technique avoids 'out of memory' errors
	my (@NODEBALLS) = $DB->getNodeWhere( { 1 => 1 }, $DB->getType("nodeball"));
	while (@NODEBALLS) {
		my $NB = shift @NODEBALLS;
		push @members, $NB->{group};
	}

	foreach my $member (@members) {
		foreach (@$member) {
			if ($DB->getId($_) == $doomed_id) {
				my $DEPENDENT = getNode($_);
				my $VARS = $DEPENDENT->getVars(-1);
				die "Nodeball \"$$DEPENDENT{title}\" ($$VARS{version}) " .
				  "depends on $$DOOMEDBALL{title}\n" .
				  "Remove \"$$DEPENDENT{title}\" first, or use --force\n"
				  unless ($OPTIONS{force});
			}
		}
	}

	unless ($OPTIONS{force}) {
		print "Are you sure you want to remove $$DOOMEDBALL{title}?\n";
		my $yesno = <STDIN>;
		exit unless ($yesno =~ /^y/i);
	}
	
	foreach (@{ $$DOOMEDBALL{group} }) {
		my $N = getNode($_);
		next if ($$N{type}{title} eq "nodeball"); #don't remove dependancies
		print "removing \"$$N{title}\" ($$N{type}{title})...\n"
			if $OPTIONS{verbose};
		$N->nuke($root) or print "Remove Error!  I can't nuke $$N{title}!!!\n" ;
	}

	$DOOMEDBALL->nuke($root);
	print "$$DOOMEDBALL{title} removed\n";
}

1;
