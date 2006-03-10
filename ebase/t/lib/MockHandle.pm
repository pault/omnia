package MockHandle;

use strict;
require Tie::Handle;

my @currentbuffer;
my $placeholder = 0;
my $FAILURE;

sub READLINE
{
	return unless @currentbuffer > 0;
	return $currentbuffer[ $placeholder++ ] if $placeholder < @currentbuffer;
	return;
}

sub TIEHANDLE
{
	my ( $class, $string, $failure ) = @_;
	$FAILURE = $failure || "";
	my $this;
	@currentbuffer = split( "\n", $string );
	$placeholder = 0;
	return bless \$this, $class;
}

sub OPEN
{
	my ($this) = @_;
	return undef if $FAILURE and $FAILURE == 1;
	return 1;
}

sub CLOSE
{
	return 1;
}

1;
