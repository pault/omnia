
=head1 Everything::Node::htmlcode

Class representing the htmlcode node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::htmlcode;

use Moose;
use MooseX::FollowPBP; 


extends 'Everything::Node::node';
has code => ( is => 'rw' );

with 'Everything::Node::Runnable';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub {
    my $self = shift;
    return 'htmlcode', $self->super();
};

=head2 C<restrictTitle>

Prevent invalid database names from being created as titles 

=over 4

=item * $node

the node containing a C<title> field to check

=back

Returns true, if the title is allowable, false otherwise.

=cut

sub restrictTitle {
    my ($this) = @_;
    my $title = $$this{title} or return;

    if ( $title =~ tr/A-Za-z0-9_//c ) {
        Everything::logErrors(
            'htmlcode name contains invalid characters.
		 	 Only alphanumerics and the underscore are allowed.  No spaces!',
            '', '', ''
        );
        return;
    }

    return 1;
}

sub get_compilable_field {
    'code';
}

1;
