
use ExtUtils::MakeMaker;


my $installDir = "/usr/local/everything";
my $webDir = "/usr/local/apache/htdocs";
my $dbname = "everything";

sub MY::install
{
	package MY;
	my $inherited = shift->SUPER::install(@_);
	$inherited =~ s/(install.*::)(.*)/$1 einstall $2/;
	$inherited .= "\neinstall:\n";

	# Create the basic database
	$inherited .= "	echo \"create database $dbname\" | mysql -u root ; \\\n";
	$inherited .= "	cat ./tables/*.sql | mysql -u root $dbname ; \\\n";
	$inherited .= "	cat ./tables/*.txt | mysql -u root $dbname ; \\\n";

	# Create the installation directory
	$inherited .= "	mkdir $installDir ; \\\n";
	$inherited .= "	cp ./web/index.pl $webDir/index.pl ; \\\n";
	$inherited .= "	chmod a+x $webDir/index.pl ; \\\n";
	$inherited .= "	cp -R ./bin $installDir ; \\\n";
	$inherited .= "	cp -R ./docs $installDir ; \\\n";
	$inherited .= "	cp -R ./images $installDir ; \\\n";
	$inherited .= "	chown -R nobody $installDir ; \\\n";

	# We remove any pod file entry for us before installing otherwise we
	# end up with many pod entries.  Since developers will be running
	# make install when working on the main pm's, we don't want a bunch
	# of enties in the pod file.
	$inherited .= "	./scripts/removePod \$(INSTALLARCHLIB)/perllocal.pod \n";

	$inherited;
}

sub MY::realclean
{
	package MY;
	my $inherited = shift->SUPER::realclean(@_);

	$inherited =~ s/(realclean.*)/$1 erealclean/;
	
	# This will drop the database and remove the pm's
	$inherited .= "\nerealclean:\n";

	$inherited .= "	echo \"drop database if exists $dbname\" | mysql -u root ; \\\n";
	$inherited .= "	rm -rf \$(INSTALLSITELIB)/Everything* ; \\\n";
	$inherited .= "	rm -rf \$(INSTALLSITEARCH)/auto/Everything* ; \\\n";
	$inherited .= "	rm -rf $installDir ; \\\n";
	$inherited .= "	rm -f $webDir/index.pl ; \\\n";
	$inherited .= "	./scripts/removePod \$(INSTALLARCHLIB)/perllocal.pod \n";
}


sub getResponse
{
	my ($default) = @_;
	
	my $response = <STDIN>;
	chomp $response;
	return ( ($response eq "") ? $default : $response );
}

sub insertPaths
{
	my ($infile, $outfile) = @_;
	my $file;

	open(FILE, $infile);
	$file = join "", <FILE>;
	close(FILE);

	$file =~ s/#INSTALL_DIR#/$installDir/g;
	$file =~ s/#WEB_DIR#/$webDir/g;
	$file =~ s/#DB_NAME#/$dbname/g;

	open(FILE, "> $outfile");
	print FILE $file;
	close(FILE);
}


print "Install directory [$installDir]: ";
$installDir = getResponse($installDir);

print "Web directory [$webDir]: ";
$webDir = getResponse($webDir);

print "Database name [$dbname]: ";
$dbname = getResponse($dbname);

print "\nEverything is configured to be installed as follows:\n";
print "  - Install directory: $installDir\n";
print "  - Web directory:  $webDir\n";
print "  - Database:  $dbname\n";
print "\nIs this correct? [y]: ";

if(not (getResponse("y") =~ /^y$/i))
{
	print "Please run \'perl Makefile.PL\' again to enter the correct information\n";
	exit 0;
}

# Create the files based on the install information
insertPaths("web/index.in", "web/index.pl");
insertPaths("tables/basenodes.in", "tables/basenodes.txt");

WriteMakefile(
	'NAME'                 => 'Everything',
	'DISTNAME'             => 'Everything-base',
	'VERSION_FROM'         => 'Everything.pm',

	# These are the modules that we require
	'PREREQ_PM'            => 	{	'Apache'			=> 0.82,
									'DBI'				=> 1.13,
									'XML::Generator'	=> 0.4,
									'XML::Parser'		=> 2.26,
									'Mysql'				=> 1.2202
								},
	'clean'					=> 	{ FILES => 'web/index.pl tables/basenodes.txt' }
);

0;
