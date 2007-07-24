package Everything::Node::Test::Runnable;

use strict;
use base 'Test::Class';
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::Exception;
use Scalar::Util 'blessed';



BEGIN {
  Test::MockObject->fake_module('Everything::Auth');
}



sub startup_runnable : Test(startup => 1) {
    my $self = shift;
  my $mock = Test::MockObject->new;
  $mock->fake_module('Everything',
		     flushErrorsToBackside => sub {1},
		     getBacksideErrors => sub {1});

  *Everything::HTTP::Request::DB = \$mock;
  $mock->set_always('get_db', $mock);
  $mock->set_always('getNodeById', $mock);

  $mock->set_always('getNode', $mock);
  $mock->set_always('get_user', $mock);
  $mock->set_always('get_db', $mock);




  $mock->set_true('update');
  $mock->set_true('setVars');
  $mock->set_series('isGod', 0, 1);

  $mock->set_always('param', $mock);

  $self->{mock} = $mock;

    *Everything::HTML::Code::Environment::flushErrorsToBackside = sub {1};
    *Everything::HTML::Code::Environment::clearFrontside = sub {1};
    *Everything::HTML::Code::Environment::getFrontsideErrors = sub {[]};

  my $class = $self->module_class();

  $self->{class} = $class;
  use Everything;
  use_ok($class) or die;


}


sub module_class
{
        my $self =  shift;
        my $name =  blessed( $self );
        $name    =~ s/Test:://;
        return $name;
}


sub fixture_environment : Test(setup) {
    my $self=shift;
    $self->{instance} = $self->{class}->new;


}


### A utility sub for eval
sub test_createAnonSub : Test(2) {
  my $self = shift;
  can_ok($self->{class}, 'createAnonSub') || return;
  my $arg = "some random data";
  like( $self->{instance}->createAnonSub($arg), qr/^\s*sub\s*\{\s*$arg\s*\}/s, 'createAnonSub wraps args in sub{}');
}



## takes text which should be an eval-able sub as an argument, returns
## a string.
sub test_eval_code : Test(4) {
  my $self = shift;
  my $class = $self->{class};
  my $instance = $self->{instance};
  can_ok($class, 'eval_code');


  my $errors = '';

  local *Everything::HTML::flushErrorsToBackside;
  *Everything::HTML::flushErrorsToBackside = sub { 1 };


  local *Everything::HTML::getFrontsideErrors;
  *Everything::HTML::getFrontsideErrors = sub { [] };

  local *Everything::HTML::logErrors;
  *Everything::HTML::logErrors = sub { $errors = "@_" };

  my $code = eval "sub {'random text'}";
  is (ref $code, 'CODE', '...we get a code ref.');
  is($instance->eval_code($code, 'page'), 'random text', 'Eval code works');
  is ($errors, '', '...runs without errors.') || diag $errors;
}

1;

