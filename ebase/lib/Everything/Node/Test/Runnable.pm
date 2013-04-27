package Everything::Node::Test::Runnable;

use strict;
use base 'Test::Class';
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::Exception;
use Everything::HTML;
use Scalar::Util 'blessed';



BEGIN {
  Test::MockObject->fake_module('Everything::Auth', import => sub {} );
}

{
    package Node::Runnable;

    use Moose;
    use MooseX::FollowPBP;

    with 'Everything::Node::Runnable';

    sub get_compilable_field { 'a_field_with_perl' }
}


sub startup_runnable : Test(startup) {
    my $self = shift;
  my $mock = Test::MockObject->new;

  *Everything::HTTP::Request::DB = \$mock;
  *Everything::HTML::DB = \$mock;
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

  my $class = 'Node::Runnable';

  $self->{class} = $class;

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
    my $instance = $self->{class}->new;

    $instance->{node_id} = 777;
    $instance->{title} = 'Temp title';

    $self->{instance} = $instance;


}

sub test_cleanup : Test(teardown) {

    my $self = shift;

    Everything::clearFrontside();
    Everything::clearBackside();
}

sub test_compile : Test( 3 ) {
    my $self = shift;

    my $test_instance = $self->{ instance };

    my $test_code = 'my $x = 1; my $y = 2; $x + $y';

    ok ( my $rv = $test_instance->compile( $test_code ), '...code compiles.' ) || diag $@;

    is ( ref $rv, 'CODE', '...returns a code ref.' );

    my $mock = Test::MockObject->new;

    is ( $rv->( $mock ), 3, '...that executes.' );

}

sub test_compile_errors : Test( 3 ) {
    my $self = shift;

    my $test_instance = $self->{ instance };

    # haven't used 'my'!! So shouldn't compile
    my $test_code = '$x = 1; $y = 2; $x + $y';

    $test_instance->{a_field_with_perl} = $test_code;

    is ( $test_instance->compile( $test_code ), undef, '...code does not compile.' );

    ok ( @Everything::bsErrors, '...errors have been logged.' );

    like ( $Everything::bsErrors[0]->{error}, qr/Global symbol/, '...the error is expected.') ;
}

sub test_run_errors : Test( 5 ) {

    my $self = shift;

    my $test_instance = $self->{ instance };

    # haven't used 'my'!! So shouldn't compile
    my $test_code = 'my $x;  $x->nonExistantSubroutine()';

    $test_instance->{'TEST CODE FIELD'} = $test_code;

    ok ( my $code = $test_instance->compile( $test_code ), '...code compiles.' );
    is ( ref $code, 'CODE', '...returns a code ref.' );

    ## Code returns a false value because we have not passed Everything::HTML object
    ok( ! $test_instance->eval_code( $code, 'TEST CODE FIELD' ), '...code runs, and returns a false value.' );

    ## errors tested on backside because we haven't passed an Everything::HTML object.

    ok ( @Everything::bsErrors, '...but errors have been logged.' ) ;

    like ( $Everything::bsErrors[0]->{error}, qr/Can't call method/, '...the error is expected.') ;

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
  my $mock = $self->{mock};
  can_ok($class, 'eval_code');


  my $errors = '';

  local *Everything::HTML::flushErrorsToBackside;
  *Everything::HTML::flushErrorsToBackside = sub { 1 };


  local *Everything::HTML::getFrontsideErrors;
  *Everything::HTML::getFrontsideErrors = sub { [] };

  local *Everything::HTML::logErrors;
  *Everything::HTML::logErrors = sub { $errors = "@_" };

  ## no critic
  my $code = eval "sub {'random text'}";
  ## use critic

  my $ehtml = Everything::HTML->new;
  ## NOTE: the third argument is the args passed to the subroutine,
  ## the first of these is the Everything::HTML object.
  is($instance->eval_code($code, 'page', [ $ehtml ] ), 'random text', 'Eval code works');
  is ($errors, '', '...runs without errors.') || diag $errors;

  my $args;
  $code = sub { $args = "@_" };
  $instance->eval_code($code, 'page', [ $ehtml, 'an arg' ] );
  is($args,  "$ehtml an arg", 'Correctly passes arguments.');
}


1;

