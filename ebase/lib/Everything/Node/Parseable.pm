package Everything::Node::Parseable;

use Moose::Role;

with 'Everything::Node::Runnable' => { alias => { compile => '_super_compile' } };


=head1 <tokens_to_perl>

This is a function.

It takes two arguments: an array ref of tokens and a call back. Turns each token into executable perl in accordance with the dispatch table returned by the method 'get_handlers'.

Returns an array ref.

=cut

sub tokens_to_perl {
    my ( $tokens, $error_cb ) = @_;

    my $dispatch_table = get_handlers();

    my @encoded = ();
    foreach (@$tokens) {
        my ( $token, $text ) = @$_;
        my $encoded = $dispatch_table->{$token}->($text);

        if ( $error_cb && $token ne 'TEXT' ) {
            $encoded .= $error_cb->() || '';
        }

        push @encoded, [ $token => $encoded ];
    }

    return \@encoded;

}


=head1 C<compile>

Overrides the super class compile.

Takes one argument which is the text to be compiled and sends it to
the parser before being compiled.

=cut

sub compile {
    my ( $self, $text ) = @_;

    my $code = $self->parse( $text );
    return $self->_super_compile( $code);
};

sub basic_handler {
    my ($specific_cb) = @_;

    return sub {
        my ($text) = @_;
        $text =~ s!"!\"!g;
        $text = $specific_cb->($text);
	my $wrapped = " eval {$text} || '';\n";
        return $wrapped;
    };

}

## class variable
my %handlers;

sub set_default_handlers {
    %handlers = (
        HTMLCODE => basic_handler(
            sub {
                my ( $func, $args ) = split( /\s*:\s*/, $_[0] );

                my $rv = '$this->'."$func(";
                if ( defined $args ) {
                    my @args = do_args($args);
                    $rv .= join( ", ", @args ) if (@args);
                }
                $rv .= ") ";
                return $rv;
            }
        ),
        TEXT => sub {
            my $text = shift;
            $text =~ s!\'!\\'!g;
            return " '$text';";
        },
        HTMLSNIPPET =>
          basic_handler( sub { '$this->' . "htmlsnippet('$_[0]')" } ),
        PERL => basic_handler( sub { " \n$_[0]\n" } ),
    );
}

BEGIN { set_default_handlers() }

sub get_handlers {
    \%handlers;
}

sub delete_handlers {
    %handlers = ();

}

sub set_handler {
    my ( $self, $text_type, $code ) = @_;
    $handlers{$text_type} = $code;
}

=head1 C<tokenise>

This is a function.

It takes one argument of text and splits it into 'tokens'.

Text wrapped in [{ }] is labelled 'HTMLCODE'.

Text wrapped in [% %] or [" "] is labelled 'PERL'

Text wrapped in [< >] is labelled 'HTMLSNIPPET'.

Everything else is labelled 'TEXT'.

Returns an array ref of array refs. These latter have two elements 'LABEL' and 'text'

=cut

sub tokenise {
    my ($text) = @_;

    my @tokens;

    for my $chunk ( split( /(\[(?:\{.*?\}|\".*?\"|%.*?%|<.*?>)\])/s, $text ) ) {
        next unless $chunk =~ /\S/;

        my ( $start, $code, $end );
        if ( ( $start, $code, $end ) =
            $chunk =~ /^\[([%"<{])(.+?)([%">}])\]$/s )
        {

            if ( $start eq '{' ) {
                push @tokens, [ 'HTMLCODE', $code ];
            }
            elsif ( $start eq '<' ) {
                push @tokens, [ 'HTMLSNIPPET', $code ];
            }
            elsif ( $start eq '"' or $start eq '%' ) {
                push @tokens, [ 'PERL', $code ];
            }
        }
        else {

            next unless ( $chunk =~ /\S/ );
            push @tokens, [ 'TEXT', $chunk ];
        }
    }
    return \@tokens;
}


sub add_error_text {
    my ($CURRENTNODE) = @_;

    my $error_text = qq|\nEverything::logErrors('', \$\@, '', { title => 
				'\Q$$CURRENTNODE{title}\E', node_id => '$$CURRENTNODE{node_id}' })
				if (\$\@);\n|;
    return $error_text;
}

=head1 C<parse>

This looks for code wrapped in:

=over 4

=item C<[{   }]>

In which case the enclosed is the name of an htmlcode node which must be retrieved form the db and executed.


=item C<[< >]>

In which case the enclosed is the name of an htmlsnippet which must be retrieved from the db.

=item C<[% %]>

In which case the enclosed is perl

=item C<[" "]>

Once again, the enclosed is perl

=back

Everything else is text or html.



=cut

sub parse {
    my $self           = shift;
    my $data           = shift;
    my $tokens         = tokenise($data);
    my $encoded_tokens =
      tokens_to_perl( $tokens, sub { add_error_text($self) } );

    my $text = 'my $result;' . "\n\n";

    $text .= join '', map { '$result .= ' . $_->[1] . "\n\n" }
      grep /\S/, @$encoded_tokens;

    $text .= 'return $result;';
    return $text;

}

=head2 C<do_args>

This is a supporting function for compileCache().  It turns a comma-delimited
list of arguments into an array, performing variable interpolation on them.
It's probably not necessary once things move over to the new AUTOLOAD htmlcode
scheme.

=over 4

=item * $args

a comma-delimited list of arguments

=back

Returns an array of manipulated arguments.

=cut

sub do_args {
    my $args = shift;
    $args =~ s/\s+$//;
    my @args = split( /\s*,\s*/, $args ) or ();
    foreach my $arg (@args) {
        unless ( $arg =~ /^\$/ ) {
            $arg = "'" . $arg . "'";
        }
    }

    return @args;
}

1;
