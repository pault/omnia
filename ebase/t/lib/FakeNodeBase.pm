package Everything::NodeBase;

use vars qw( $AUTOLOAD );

sub new
{
	my $class = shift;
	bless( [@_], $class );
}

{
	my %ids;

	sub setId
	{
		my %newids = @_;
		@ids{ keys %newids } = values %newids;
	}

	sub _getId
	{
		return $ids{ $_[1] };
	}
}

{
	my %nodes;

	sub setNode
	{
		my %newnodes = @_;
		@nodes{ keys %newnodes } = values %newnodes;
	}

	sub _getNode
	{
		return $nodes{ $_[1] };
	}
}

{
	my $results;

	sub setResults
	{
		$results = shift;
	}

	sub _prepare
	{
		return $results;
	}

	sub _sqlSelectMany
	{
		return $results;
	}
}

sub _quote
{
	return $_[1];
}

sub calls
{
	return splice( @calls, 0, scalar @calls );
}

sub AUTOLOAD
{
	$AUTOLOAD =~ s/.+:://;
	return if $AUTOLOAD eq 'DESTROY';

	my $self = shift;
	my $sub;
	push @calls, [ $AUTOLOAD, @_ ];

	if ( $sub = $self->can("_$AUTOLOAD") )
	{
		return $sub->( $self, @_ );
	}
	else
	{
		return $self;
	}
}

1;
