package Everything::HTTP::Response::Test::Htmlpage;

use Test::More;
use Test::MockObject;
use Scalar::Util 'blessed';

use base 'Test::Class';
use strict;
use warnings;

my $mock;

sub module_class
{
        my $self =  shift;
        my $name =  blessed( $self );
        $name    =~ s/Test:://;
        return $name;
}

use Everything::HTTP::Response::Htmlpage;
use Everything::HTTP::Request;


sub startup : Test(startup=>2) {
  my $self = shift;
  $self->{class} = $self->module_class();
  use_ok($self->{class}) || die $self->{class};
  my $mock = Test::MockObject->new;

  $mock->set_always( getNode => $mock );
  $mock->set_true( 'set_theme' );
  $mock->set_always( 'get_theme', $mock );
  $mock->set_always( 'get_node', $mock );
  $mock->set_always( 'get_nodebase', $mock );
  $mock->set_always( 'param', 'display' );
  $mock->set_always( 'get_cgi', $mock );
  $mock->set_always( 'getType', $mock );
  $mock->set_always( 'get_user_vars', { key => 'value' } );
  $mock->{title} = 'a title';
  $self->{mock} = $mock;
  isa_ok ($self->{instance} = $self->{class}->new($mock), $self->{class});


}


sub test_http_response : Test(3){
  my $self = shift;
  my $class = $self->{class};
  my $instance = $self->{instance};
  can_ok($class, 'create_http_header');
  can_ok($class, 'create_http_body');
  can_ok($class, 'get_mime_type');


}


sub test_get_theme : Test(2) {

  my $self = shift;
  my $class = $self->{class};
  my $instance = $self->{instance};
  my $e = $instance->get_request;
  can_ok($class, 'getTheme') || return;
  my $mock = $self->{mock};
  $e->set_always(get_system_vars => { one => 'two' })
    ->set_always(get_db => $mock);
  $mock->set_series(isOfType => 1, 0)
       ->set_always('getVars', {var1 => 'one', var2 => 'two'});
  ok($instance->getTheme($instance->get_request));

}

1;
