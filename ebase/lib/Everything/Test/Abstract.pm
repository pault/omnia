package Everything::Test::Abstract;

use Scalar::Util 'blessed';
use SUPER;
use Test::More;

use base 'Test::Class';



sub module_class
{
	my $self =  shift;
	my $name =  blessed( $self );
	$name    =~ s/Test:://;
	return $name;
}


sub startup :Test( startup => 1 )
{
	my $self   = shift;
	my $module = $self->module_class();
	use_ok( $module ) or exit;
	$self->{class} = $self->module_class;

}

1;
