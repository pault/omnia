package Everything::HTTP::URL;

use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
    qw/request path_info url cgi location requested_node_id requested_node_ref/
);

our @select_node_subs = ();
our @url_parsers      = ();
our $default_sub;

sub new {
    my ( $class, $args ) = @_;
    my $self = bless {}, $class;
    foreach ( keys %$args ) {
        $self->{$_} = $args->{$_};
    }
    return $self;

}

sub create_nodetype_rule {
    my ( $self, $sub, $typename ) = @_;
    my $rule = sub {
        my $node = shift;
        $node = $self->get_request->get_nodebase->getNode($node)
          unless ref $node;
        my $type = $node->{type};
        return unless $type->{title} eq $typename;
        return $sub->( $node, @_ );
    };
    push @select_node_subs, $rule;
    return $rule;
}

sub create_linknode {
    my ($self) = @_;
    my @subs = @select_node_subs;
    push @subs, $self->get_default_sub if $self->get_default_sub;
    my $linknode = sub {
        foreach (@subs) {
            my $rv = $_->(@_);
            return $rv if $rv;
        }

      }

}

sub parse_url {
    my ( $this, $r ) = @_;
    return unless @url_parsers;

    my $matches;
    my $node;
  PARSERS:
    foreach (@url_parsers) {

        if ( my $m = $_->match( $r->path_info ) ) {

            ++$matches;
            if ( $node = $_->process ) {
                last PARSERS;
            }
        }
    }
    return $matches if !$node;
    return $node;
}

sub set_default_sub {

    $default_sub = $_[1];

}

sub get_default_sub {

    $default_sub;

}

sub get_select_node_subs {

    @select_node_subs;
}

sub get_select_node_subs_ref {

    \@select_node_subs;
}

sub set_select_node_subs {

    shift;
    @select_node_subs = @_;
}

sub register_url_parser {

    push @url_parsers, $_[0];

}

sub isset_url_parsers {

    return 1 if @url_parsers;
    return;

}

1;
