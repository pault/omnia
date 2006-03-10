package FakeDBI;

sub new
{
	bless( $_[1], $_[0] );
}

{
	my $can_execute = 0;

	sub set_execute
	{
		$can_execute = $_[0];
	}

	sub execute
	{
		return $can_execute;
	}
}

sub fetchrow_hashref
{
	my $self = shift;
	shift @$self;
}

1;
