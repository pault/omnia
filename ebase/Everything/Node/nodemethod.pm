=head 1 Everything::Node::nodemethod

Package that implements the base nodemethod functionality

Copyright 2000 - 2003 Everything Development Inc.

=cut

# Format: tabs = 4 spaces

package Everything::Node::nodemethod;

use strict;
use Everything::Node;

=cut

=head2 C<getIdentifyingFields>

Nodemethods can have the same title (name of function), but they are for
different types (supports_nodetype).  We want to make sure that when we search
for them, export them, or import them, we can uniquely identify them.

Returns an array ref of field names that would uniquely identify this node.
undef if none (the default title/type fields are sufficient)

=cut

sub getIdentifyingFields
{
	return ['supports_nodetype'];
}

#these functions exist to support the methodCache (in NodeCache.pm and Node.pm)
#every time a nodemethod is manipulated in the database, everyone has
#to rebuild their nodemethod cache to prevent potential corruption. 
#when we increment the version of the nodetype, the methodCache is wiped
#(on all webservers)

#sub insert {
#	my ($this, $USER) = @_;
#
#	$this->SUPER();
#	$this->{DB}->{cache}->incrementGlobalVersion($this->{type});
#}

#sub update {
#	my ($this, $USER) = @_;
#
#	$this->SUPER();
#	$this->{DB}->{cache}->incrementGlobalVersion($this->{type});
#}

#sub nuke {
#	my ($this, $USER) = @_;
#
#    $this->SUPER();
#	$this->{DB}->{cache}->incrementGlobalVersion($this->{type});
#}

#############################################################################
# End of package
#############################################################################

1;
