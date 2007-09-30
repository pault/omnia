#!perl

use strict;
use warnings;

use lib 'lib';

use File::Find;
use File::Spec;

use Everything::Build;

my @test_files;

find( sub { return unless /\.t\z/; push @test_files, $File::Find::name }, 't' );

my $build = Everything::Build->new(
	module_name       => 'Everything',
    dist_version          => '2.0-pre-alpha',
    dist_abstract          => 'Yet Another Web Content Management Package using Perl, Apache and Mysql/Pg/sqlite',
	license           => 'artistic',
	requires          =>
	{
		CGI                         => 2.46,
		DBI                         => 1.13,
		'Bundle::Apache2'           => 0,
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
		'Scalar::Util'              => 1.01,
		'SUPER'                     => 1.16,
		'Object::InsideOut'	    => 3.21,
		'Archive::Tar'		    => 0,
		'Class::Factory'	    => 0,
		'SQL::Statement'	    => 1.15,

	},
	build_requires    =>
	{
		'Test::Class'               => 0.11,
		'Test::MockObject'          => 1.05,
		'Test::Warn'		    => 0.10,
		'Test::Exception'           => 0.13,
		'Test::Simple'              => 0.47,
	 'Template' => 0,
	},
	scripts    => [ File::Spec->catfile( 'bin', 'nbmasta' ) ],
	test_files => join( ' ', @test_files ),
);

my $httpconf   = '';
my $installDir = $build->prompt( 'Install directory: ',
	'/usr/local/everything' );

print <<CONFIG;
Everything is configured to be installed as follows:
	- Install directory: $installDir
CONFIG

unless($build->y_n( 'Is this correct?', 'y' ))
{
	print "Please run 'perl Build.PL' again to enter the correct information\n";
	exit 0;
}

$build->{args}{installDir} = $installDir;
$build->create_build_script();

0;
