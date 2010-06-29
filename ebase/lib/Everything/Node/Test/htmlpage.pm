package Everything::Node::Test::htmlpage;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;
use SUPER;

sub test_dbtables
{
	my $self  = shift;
	my $class = $self->node_class();

	can_ok( $class, 'dbtables' );

	my @tables = $class->dbtables();
	is_deeply( \@tables, [qw( htmlpage node )],
		'dbtables() should return node tables' );
}

sub test_insert_access :Test( +0 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->{parent_container} = 'npc';
	$self->SUPER();
}

sub test_insert_restrictions :Test( +0 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->{parent_container} = 'npc';
	$self->SUPER();
}

sub test_insert_restrict_dupes :Test( +0 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->{parent_container} = 'npc';
	$self->SUPER();
}


sub test_make_html : Test(3) {
  my $self = shift;
  my $class = $self->node_class();
  my $instance = $self->{node};
  $instance->set_always( 'run', 'some htmlpage html <BacksideErrors>' );
  $instance->set_always(get_parent_container => 0 );
  my $mock = Test::MockObject->new;
  $mock->set_always( get_user => $mock );
  can_ok($class, 'make_html');
  $instance->{NODE}->{page} = 'text in some htmlpage';
  $instance->{NODE}->{title} = 'node title';
  $instance->{NODE}->{node_id} = '2222';
  $mock->set_series('isGod', 0, 1);

  $mock->mock( formatGodsBacksideErrors => sub { "some errors" } );
  local *Everything::printBacksideToLogFile;
  *Everything::printBacksideToLogFile = sub { 1 };


  is($instance->make_html( $mock, $mock ), 'some htmlpage html ', '...creates html with no errors' );
  is($instance->make_html( $mock, $mock ), 'some htmlpage html some errors', '...creates html with errors' );


}

1;
