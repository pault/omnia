use strict;
use ExtUtils::MakeMaker;

my $installDir = "/usr/local/everything";
my $includestr;
my $httpconf = "";

sub MY::install
{
	package MY;
	my $inherited = shift->SUPER::install(@_);
	$inherited =~ s/(install.*::)(.*)/$1 einstall $2/;
	$inherited .= "\neinstall:\n";

	# Create the installation directory
	$inherited .= "	mkdir $installDir ; \\\n";
	$inherited .= "	cp -R ./nodeballs $installDir ; \\\n";

	# XXX - hack to make install_esite work correctly
	$inherited .= "	mkdir $installDir/nodeballs ; \\\n";
	$inherited .= "	cp -R ./web $installDir ; \\\n";
	$inherited .= "	cp -R ./tables $installDir ; \\\n";
	$inherited .= "	cp -R ./bin $installDir ; \\\n";
	$inherited .= "	cp -R ./docs $installDir ; \\\n";
	$inherited .= "	cp -R ./images $installDir ; \\\n";
	$inherited .= "	cp ./everything.apache.conf $installDir ; \\\n";
	$inherited .= "	echo \"$includestr\" >> $httpconf ; \\\n" if $httpconf;
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

	$inherited .= "	rm -rf \$(INSTALLSITELIB)/Everything* ; \\\n";
	$inherited .= "	rm -rf \$(INSTALLSITEARCH)/auto/Everything* ; \\\n";
	$inherited .= "	rm -rf $installDir ; \\\n";
	$inherited .= "	./scripts/removePod \$(INSTALLARCHLIB)/perllocal.pod \n";
}

sub getHttpconf {
	my ($includestr) = @_;
	my $conf = "";	
	my @locs = qw(/etc/apache /etc/apache/conf /etc/httpd /etc/httpd/conf /usr/local/apache/conf);
	foreach (@locs) {
		$conf = $_."/httpd.conf" if -e $_."/httpd.conf";
	}
	my $defaultstr = "";
	$defaultstr = "[$conf]" if $conf;
	print "Where is your Apache's httpd.conf? $defaultstr";
	$conf = getResponse($conf);
	unless (-e $conf) {
		print "$conf doesn't exist!  Exiting.";
		exit 0;
	}
	open APACHECONF, $conf;
	while (<APACHECONF>) {
		if (/$includestr/) {
			print "It looks like $conf is already including it.  Skipped";
			return 0;
		}
	}
	close APACHECONF;
	
	return $conf;
}

sub getResponse
{
	my ($default) = @_;
	
	my $response = <STDIN>;
	chomp $response;
	return ( ($response eq "") ? $default : $response );
}

print "Install directory [$installDir]: ";
$installDir = getResponse($installDir);
$includestr = "Include $installDir/everything.apache.conf";

print "May I append:\n\n\t$includestr\n\nto your httpd.conf file? (N/y)";
if (getResponse("n") =~ /^y/i) {
	$httpconf = getHttpconf($includestr);
} else { print "You will have to manage httpd.conf yourself, then.\nCheck out the HTTPCONF_SETUP file for some pointers.\n";
$httpconf = ""; }

print "\nEverything is configured to be installed as follows:\n";
print "  - Install directory: $installDir\n";
print "  - Append Include to: $httpconf\n" if $httpconf;

print "\nIs this correct? [y]: ";

if(not (getResponse("y") =~ /^y$/i))
{
	print "Please run \'perl Makefile.PL\' again to enter the correct information\n";
	exit 0;
}

# Create the files based on the install information

WriteMakefile(
	NAME          => 'Everything',
	DISTNAME      => 'Everything-base',
	VERSION_FROM  => 'Everything.pm',

	# These are the modules that we require
	PREREQ_PM     => {
		CGI                => 2.46,
		DBI                => 1.13,
		Mysql              => 1.2202,
		Apache             => 0.82,
		'XML::DOM'         => 1.27,
		'XML::Parser'      => 2.26,
		'File::Spec'       => 0.82,
		'Mail::Address'    => 1.53,
		'Mail::Sender'     => 0,
		'Test::MockObject' => 0.11,
		'Test::Exception'  => 0.13,
	},
	clean         => {
		FILES => 'web/index.pl tables/basenodes.txt'
	},
	test          => {
		TESTS => 't/*.t t/Everything/*.t'
	},
);

0;
