package Everything::HTTP::URL::Deconstruct;

use strict;
use base 'Everything::HTTP::URL';
use Data::Dumper;
use List::MoreUtils qw(zip);
use URI;
use SUPER;

__PACKAGE__->mk_accessors(
    qw(re path_vars schema rule attributes tokens urlifier requested_node_id requested_node_ref url_gen matches nodebase )
);

#### DISPATCH TABLE FOR DECODING URLS
##
## The key is the name of the attribute in the url schema and which is
## preceded by the colon.  It must return a list of the Node attribute
## we want to match, followed by the value of the node attribute

my $decode_attributes = {
    type => sub {
        my ( $self, $attribute_value ) = @_;
        my $type = $self->get_nodebase->getType( $attribute_value->[1] );
        return 'type_nodetype', $type->{node_id};
    },
    __DEFAULT__ => sub { return @{ $_[1] }; },

};

### expects a node and attribute name as arguments
### returns a single value which is the value of the attribute
my $encode_attributes = {
    type => sub {
        my ($node) = @_;
        my $type = $node->{DB}->getType( $node->{type_nodetype} );
        return $type->{title};
    },
    __DEFAULT__ => sub { return $_[0]->{ $_[1] } },
};

sub process {
    my $self        = shift;
    my @matches     = @{ $self->get_matches };
    my %node_params = ();
    while ( my ( $attribute, $value ) = splice @matches, 0, 2 ) {

        my $action = $decode_attributes->{ $attribute->[0] }
          || $decode_attributes->{__DEFAULT__};
        ( $attribute, $value ) =
          $action->( $self, compulsory_value( $attribute, $value ) );
        $node_params{$attribute} = $value;

    }

    my $node = $self->make_requested_node_ref( \%node_params );
    return $node;

}

sub compulsory_value {
    my ( $attribute, $value ) = @_;
    return $attribute if defined $attribute->[1];
    return [ $attribute->[0], $value ];

}

sub set_schema {
    my ( $self, $schema ) = @_;
    $self->set_rule($schema);
    $self->tokenize;
    $self->make_regex;
    $self->make_urlifier;

}

sub make_urlifier {
    my ($self)   = @_;
    my @tokens   = @{ $self->get_tokens };
    my $location = $self->get_location;
    my $urlifier = sub {
        my $node        = shift;
        my @url         = ();
        my @tokens_copy = @tokens;
        while ( my ( $token, $var ) = splice( @tokens_copy, 0, 2 ) ) {
            if ( $token eq 'TEXT' ) {
                push @url, $var;
            }
            elsif ( $token eq 'ATTRIBUTE' ) {
                my $attribute_sanitizer = $encode_attributes->{ $var->[0] }
                  || $encode_attributes->{__DEFAULT__};
                push @url, $attribute_sanitizer->( $node, $var->[0] );
            }
        }
        my $url = $location . '/' . join '/', @url;
        return $url;
    };
    $self->set_urlifier($urlifier);
}

sub make_url_gen {
    my $self     = shift;
    my $urlifier = $self->get_urlifier;
    my $url_gen  = sub {
        my ( $REF, $noquotes, $node ) = @_;
        my $base = $urlifier->($node);
        my $url = URI->new( $base, 'http' );
        $url->query_form($REF) if $REF && %$REF;
        my $url_string = $url->as_string;
        return $url_string if $noquotes;
        return '"' . $url_string . '"';
    };
    return $self->set_url_gen($url_gen);
}

sub make_link_node {
    my $self = shift;
    sub {

        my ( $node, $title, $params, $scripts ) = @_;
        my $link;

        return "" unless defined($node);

        # We do this instead of calling getRef, because we only need the node
        # table data to create the link.
        $node = $self->get_nodebase->getNode( $node, 'light' )
          unless ( ref $node );

        return "" unless ref $node;

        $title ||= $$node{title};

        my $tags = "";

        separate_params( $params, \$tags );

        my $scripts = handle_scripts($scripts);

        $link = "<a href=" . $self->get_url_gen->( $params, '', $node ) . $tags;
        $link .= " " . $scripts if ( $scripts ne "" );
        $link .= ">$title</a>";

        return $link;

      }

}

sub handle_scripts {
    my ($SCRIPTS) = @_;
    return '' unless $SCRIPTS && %$SCRIPTS;
    my @scripts;
    foreach my $key ( keys %$SCRIPTS ) {
        push @scripts, $key . "=" . '"' . $$SCRIPTS{$key} . '"';
    }
    return '' unless @scripts;
    return join ' ', @scripts;

}

sub separate_params {
    my ( $PARAMS, $tags_ref ) = @_;
    foreach my $key ( keys %$PARAMS ) {
        next unless ( $key =~ /^-/ );
        my $pr = substr $key, 1;
        $$tags_ref .= " $pr=\"$$PARAMS{$key}\"";
        delete $$PARAMS{$key};
    }

}

sub make_url {
    my ( $self, $node ) = @_;
    $self->get_urlifier->($node);

}

#### tokenize
##   Takes no arguments Splits the schema into tokens.  This
##   takes the form of a list in the following form:
##
##   ATTRIBUTE, [ attribute_name, attribute_value ], TEXT, 'PLAINTEXT'

sub tokenize {
    my ($self) = @_;
    my $spec = $self->get_rule;
    $spec =~ s/^\///;

    my @elements = split '/', $spec,
      -1;    # Final negative arg ensures trailing slashes are properly handled.
    my @attributes = ();
    my @tokens = map {
        my @rv = ();
        if (/^:(.*)/) {
            my ( $attribute, $value ) = split /\?/, $1;
            if ($value) {
                @rv = ( 'ATTRIBUTE', [ $attribute, $value ] );
            }
            else {
                @rv = ( 'ATTRIBUTE', [$attribute] );
            }

        }
        else {
            @rv = ( 'TEXT', $_ );
        }
        @rv;
    } @elements;

    $self->set_tokens( \@tokens );

}

### make_requrested_node_ref
##
## takes a hash ref that contains node
## attribute, value pairs.  amends the everything request object that
## can be accessed by get_e.
##
## Returns nothing of consequence.

sub make_requested_node_ref {
    my ( $self, $matches ) = @_;

    my $nodes = $self->get_nodebase->getNodeWhere($matches);

    return unless $nodes;
    if ( @$nodes == 1 ) {
        $self->set_requested_node_id( $nodes->[0]->{node_id} );

        return $self->set_requested_node_ref( $nodes->[0] );
    }
    elsif ( @$nodes == 0 ) {
        die "Not found";
    }
    else {
        warn "I've found...\n";
        warn "$$_{node_id} $$_{title} \n" foreach @$nodes;
        die "Too many nodes";
    }
}

sub require_param {
    my ( $self, $name, $value ) = @_;

    if ( $value =~ /\.\*/ ) {
        $value =~ s/\.\*/[^;&]\*/g;
    }

    return qr/(?=.*?(?:[;&?])($name)=($value)(?:[;&]|$))/;
}

sub make_regex {
    my $self      = shift;
    my @tokens    = @{ $self->get_tokens };
    my @path_vars = ();
    my $re        = '^';
    while ( my ( $token, $var ) = splice( @tokens, 0, 2 ) ) {
        if ( $token eq 'TEXT' ) {
            $re .= '/' . $var;
        }
        elsif ( $token eq 'ATTRIBUTE' ) {
            push @path_vars, $var;
            $re .= '/' . '(\w+)';

        }
    }
    $self->set_path_vars( \@path_vars );
    $self->set_re(qr($re));
}

sub match {
    my ( $self, $req ) = @_;

    # create a careful splitter that maps the path names
    # conveniently into the result...
    my $re = $self->get_re;

    my @res = $req =~ $re;

    if (@res) {

        # two steps because I'm not sure about order of execution
        my $n = $self->get_path_vars;

        my @path = splice @res, 0, scalar @$n;

        my @matches = zip( @$n, @path );
        return $self->set_matches( \@matches );
    }
    else {
        return;
    }
}

1;

__END__


=head1 NAME

Everythning::URL::Deconstruct - match-and-extract stuff from HTTP request strings and returns an Everything::HTTP::Request object or a CGI object.

=head1 SYNOPSIS

  use Everything::HTTP::URLProcess::Deconstruct;
  my $r = Apache->request;
  my $e = Everything::HTTP::Request->new;
  my $processor = Everything::HTTP::URLProcess::Deconstruct->new({r => $r, e => $e});

  $processor->set_schema('/path/text/:node_id');

  $processor->make_url_gen;
  *Everything::HTML::linkNode = $processor->make_link_node;

  my $url = $r->path_info;
  $processor->process($path_info);


=head1 SCHEMA SYNTAX

The syntax is similar to that used in CGI::Applicaton.

A schema consists of text and node attributes. Node attributes are preceded by a colon ':'.

  /some/location/:title
  
Will match all urls of the form /some/location and will attempt to find nodes with 'title'.

  /some/location/:type?container/:title

Will match nodes that have type container and title of 'title'.

=cut


=head2 C<< $m->require_param NAME, VALUE >>

NOT USED

This internal method returns the regular expression
to match a HTTP query parameter and its name.

NAME is the name of the key into which the value will
be captured.

VALUE is the regular expression that will match
the value.

=cut


=head2 C<< $m->make_regex >>

This is the internal method that implements the meat
of the request decoder. It creates a regular expression
that will match and capture the request fields.

=cut


=head2 C<< $m->match($url) >>

This is also an internal method.

Returns a list of captured values
if the request matches.

If the request matches but does not capture anything,
a single 1 is returned. This is ugly but such is life.

=cut

=head2 C<< $m->process($url) >>

Takes a URL.  Amends the Everything::HTTP::Request object in place setting the requested node to the appropriate values.

=cut


=head1 THANKS

Thanks to Corion on perlmonks for providing the idea for this code: http://www.perlmonks.org/?node_id=563146

=cut

