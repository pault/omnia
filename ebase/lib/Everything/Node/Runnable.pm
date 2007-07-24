package Everything::Node::Runnable;

use Everything ();
use Everything::HTML;

use base 'Class::Accessor';
__PACKAGE__->follow_best_practice;

use strict;
use warnings;



sub run {
    my ( $self, $field, $no_cache, @args) = @_;

    $field ||= $self->get_compilable_field;

    if ( $no_cache ) {

	my $code = $self->compile( $self->{$field} );
	return $self->eval_code( $code, $field, \@args );
    }

    my $ret = $self->execute_cached_code( $field, \@args );
    return $ret if $ret;
    my $code = $self->compile( $self->{ $field } );
    die "Cache failed" unless $self->cache_code( $field, $code );
    return $self->execute_cached_code( $field, \@args );

}


sub cache_code {
    my ($self, $field, $code_ref) = @_;
    $field ||= $self->get_compilable_field;

    return 1 if $self->{DB}->{cache}->cacheMethod($self, $field, $code_ref);


}

sub execute_cached_code {
	my ($self, $field, $args) = @_;

	$field ||= $self->get_compilable_field;

	$args ||= [];

	my $code_ref;

	if ($code_ref = $self->{"_cached_$field"}) {

		if (ref($code_ref) eq 'CODE' and defined &$code_ref) {


			return $self->eval_code($code_ref, $field, $args);
		}
	}
}


sub compile {
    my ( $self, $code ) = @_;

    my $anon = Everything::HTML::createAnonSub($code);
    return Everything::HTML::make_coderef($anon, $self);


}

sub get_compilable_field {

    die "Sub-class responsibility";

}

sub eval_code {
  my $self = shift;
  my $sub = shift;
  my $field = shift;
  $field ||= $self->get_compilable_field;
  my @args = @_;


  my $html = Everything::HTML::execute_coderef( $sub, $field, $self, @args );
  return $html;
}


sub createAnonSub {
	my ($self, $code) = @_;

### package name as to be put here to make sure we know which subs we are executing --------- set up environment
	"sub {
	       $code 
	}\n";
}

=head2 C<compileCache>

Common compilation and caching and initial calling of htmlcode and
nodemethod functions.  Hopefully it keeps common code in one spot.  For
internal use only!

=over 4

=item * $code

the text to eval() into an anonymous subroutine

=item * $NODE

the node object from which the code came

=item * $field

the field of the node that holds the code for that nodetype

=item * $args

a reference to a list of arguments to pass

=back

Returns a string containing results of the code or a blank string.  Undef if
the compilation fails -- in case we need to default to old behavior.

=cut

sub compileCache
{
	my ($self, $code_ref, $args) = @_;
	my $field = $self->get_compilable_field;
	my $NODE = $self->getNODE;
	return unless $code_ref;

	return 1 if $NODE->{DB}->{cache}->cacheMethod($NODE, $field, $code_ref);

}


1;