package Everything::Build;

use File::Find;
use File::Path;
use File::NCopy;
use strict;
use warnings;

use Module::Build;

use vars '@ISA';
@ISA = 'Module::Build';

sub ACTION_install
{
	my $self       = shift;
	my $installDir = $self->{args}{installDir};

	# Create the installation directory
	eval { mkpath($installDir) };
	die "Couldn't create '$installDir': $@\n" if $@;

	my $file = File::NCopy->new( recursive => 1 );

	for my $dir (
		qw( nodeballs web tables bin docs images )
		)
	{
		$file->copy( $dir, $installDir )
			or warn "No files copied from $dir to $installDir";
	}

	if ( my $httpconf = $self->{args}{httpconf} )
	{
		if ( open( my $CONF, '>>', $httpconf ) )
		{
			print $CONF $self->{args}{includestr};
		}
		else
		{
			warn "Could not append include line to '$httpconf': $!\n";
		}
	}

	$self->SUPER::ACTION_install(@_);
}

1;
