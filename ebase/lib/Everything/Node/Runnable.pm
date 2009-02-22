package Everything::Node::Runnable;

use Everything ();
use Everything::HTML;

use Moose::Role;

=head2 C<run>

Compiles, if necessary, and executes the node.  It also uses the node caching system to cache the code out put. 

It takes one hash ref argument.  The hash may take keys as follows:

=over 4

=item field

The field name of the node that contains code we wish to compile and run

=item no_cache

If true the code will not be cached in the node cache

=item ehtml

An Everything::HTML object. Essential for some node types.

=item args

An array ref of arguments to be passed to the compiled code. The code will fail if it is anything other than an array ref. This is a feature.

=back

Returns whatever the output of the code in the node outputs.

=cut

use Carp; $SIG{__DIE__} = \&Carp::confess;
sub run {
    my ( $self, $arg_hash ) = @_;

    my $field = $$arg_hash{ field };
    my $no_cache = $$arg_hash{ no_cache };
    my @args = $$arg_hash{args} ? @{ $$arg_hash{args} } : ();
    unshift  @args, $$arg_hash{ ehtml };
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

    return 1 if $self->get_nodebase->{cache}->cacheMethod($self, $field, $code_ref);


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
