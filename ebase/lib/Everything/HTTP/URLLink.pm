package Everything::HTTP::URLLink;

use strict;
use warnings;
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/subs default_sub e/);

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    $self->set_subs([]);
    foreach (keys %$args) {
	$self->{$_} = $args->{$_};
    }
    return $self;

}


sub create_nodetype_rule {
    my ($self, $sub, $typename) = @_;
    my $rule = sub {
	my $node = shift;
	$node = $self->get_e->get_nodebase->getNode($node) unless ref $node;
	my $type = $node->{type};
	return unless $type->{title} eq $typename;
	return $sub->($node, @_);
	};
    push @{$self->get_subs}, $rule;
    return $rule;
}

sub create_linknode {
    my ($self) = @_;
    my @subs = @{ $self->get_subs };
    push @subs, $self->get_default_sub if $self->get_default_sub;
    my $linknode = sub {
	foreach (@subs) {
	    my $rv = $_->(@_);
	    return $rv if $rv;
	}

    }

}

sub set_default {
    my ($self, $package) = @_;
    no strict 'refs';

    my $sub = *{$package . '::linkNode'}{CODE};
    $self->set_default_sub($sub);


}


1;
