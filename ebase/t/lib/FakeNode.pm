package FakeNode;

use vars qw( $AUTOLOAD );

sub new {
	bless({ _calls => [] }, $_[0]);
}

sub AUTOLOAD {
	return if $AUTOLOAD =~ /::DESTROY/;
	my $self = shift;

	$AUTOLOAD =~ s/.+:://;

	# store call
	push @{ $self->{_calls} }, [ $AUTOLOAD, @_ ];

	# return expected data
	if (exists($self->{_subs}{$AUTOLOAD})) {
		return shift @{ $self->{_subs}{$AUTOLOAD} };
	}
}

1;
