#!perl

use strict;
use warnings;

use lib 'lib';

use File::Spec;
use Everything::Build;

my $build = Everything::Build->new(
	module_name       => 'Everything',
	dist_version_from => 'lib/Everything.pm',
	license           => 'artistic',
	requires          =>
	{
		CGI                         => 2.46,
		DBI                         => 1.13,
		Mysql                       => 1.2202,
		Apache                      => 0.82,
		'Archive::Tar'              => 1.0,
		'File::NCopy'               => 0.32,
		'IO::Zlib'                  => 1.0,
		'XML::DOM'                  => 1.27,
		'XML::LibXML'               => 0,
		'XML::Parser'               => 2.26,
		'XML::SimpleObject::LibXML' => 0,
		'File::Spec'                => 0.82,
		'Mail::Address'             => 1.53,
		'Mail::Sender'              => 0,
	},
	build_requires    =>
	{
		'Test::MockObject'          => 0.11,
		'Test::Exception'           => 0.13,
		'Test::Simple'              => 0.47,
	},
	scripts => [ File::Spec->catfile( 'bin', 'nbmasta' ) ],
	
);

my $httpconf   = '';
my $installDir = $build->prompt( 'Install directory: ',
	'/usr/local/everything' );
my $includestr = "Include " .
	File::Spec->catfile( $installDir, 'everything.apache.conf' );

my $include = $build->y_n("May I append:\n\n\t$includestr\n\n" .
	"to your httpd.conf file?", 'n' );

if ( $include )
{
	$httpconf = getHttpconf( $includestr, $build );
}
else
{
	print "You will have to manage httpd.conf yourself, then.\n",
		  "Check out the HTTPCONF_SETUP file for some pointers.\n";
}

print <<CONFIG;
Everything is configured to be installed as follows:
	- Install directory: $installDir
CONFIG

print "	- Append Include to: $httpconf\n" if $httpconf;

unless($build->y_n( 'Is this correct?', 'y' ))
{
	print "Please run 'perl Build.PL' again to enter the correct information\n";
	exit 0;
}

$build->{args}{installDir} = $installDir;
$build->create_build_script();

sub getHttpconf
{
	my ($includestr, $build) = @_;

	my @dirs = qw( /etc/apache /etc/apache/conf /etc/httpd /etc/httpd/conf
		/usr/local/apache/conf );

	my $conf;

	for my $dir (@dirs)
	{
		my $file = File::Spec->catfile( $dir, 'httpd.conf' );
		$conf = $file if -e $file;
	}

	my $defaultstr = '';
	$defaultstr    = "[$conf]" if $conf;

	$conf = $build->prompt( 'Where is your httpd.conf?', $defaultstr );
	unless (-e $conf)
	{
		print "$conf doesn't exist!  Exiting.";
		exit 0;
	}

	local *APACHECONF;
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

0;
