=head1 Everything::Node::setting

Class representing the setting node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::setting;

use strict;
use warnings;

use base 'Everything::Node::node';

use Everything::Security;
use Everything::XML (qw/genBasicTag/);
use XML::DOM;
use Scalar::Util 'reftype';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'setting', $self->SUPER( @_ );
}

=head2 C<getVars>

All setting nodes join on the setting table.  The vars field in that table
contains a string that is an '&' delimited hash.  This function will grab that
string and construct a perl hash out of it.

=cut

sub getVars
{
	my ($this) = @_;

	return $this->getHash("vars");
}

=head2 C<setVars>

This takes a hash of variables and assigns it to the 'vars' of the given node.
NOTE!  This will not update the node.  It will only update the local version of
the vars for this node instance.  If you want to update the node in the
database, you will need to call update on this node.

=over 4

=item * $varsref

the hashref to get the vars from

=back

Returns nothing.

=cut

sub setVars
{
	my ( $this, $vars ) = @_;

	$this->setHash( $vars, "vars" );

	return;
}

sub hasVars { 1 }

=head2 C<fieldToXML>

This is called when the node is being exported to XML.  The base node knows how
to export fields to XML, but if the node contains some more complex data
structures, that nodetype needs to export that data structure itself.  In this
case, we have a settings field (hash) that needs to get exported.

=over 4

=item * $DOC

an XML::DOM::Document object that this field belongs to

=item * $field

the field of this node that needs to be exported as XML

=item * $indent

string that contains the amount that this will be indented (used for formatting
purposes)

=back

Returns the XML::DOM::Element that represents this field.

=cut

sub fieldToXML
{
	my ( $this, $DOC, $field, $indent ) = @_;
	$indent ||= '';

	return $this->SUPER( $DOC, $field, $indent ) unless $field eq 'vars';

	my $VARS = XML::DOM::Element->new( $DOC, "vars" );
	my $vars = $this->getVars();
	my @raw  = keys %$vars;
	my @vars = sort { $a cmp $b } @raw;
	my $indentself  = "\n" . $indent;
	my $indentchild = $indentself . "  ";

	foreach my $var (@vars)
	{
		$VARS->appendChild( XML::DOM::Text->new( $DOC, $indentchild ) );
		my $tag = genBasicTag( $DOC, "var", $var, $$vars{$var} );
		$VARS->appendChild($tag);
	}

	$VARS->appendChild( XML::DOM::Text->new( $DOC, $indentself ) );

	return $VARS;
}

sub getNodeKeepKeys
{
	my ($this) = @_;

	my $nodekeys      = $this->SUPER();
	$nodekeys->{vars} = 1;

	return $nodekeys;
}

# vars are preserved upon import
sub updateFromImport
{
	my ( $this, $NEWNODE, $USER ) = @_;

	my $V    = $this->getVars();
	my $NEWV = $NEWNODE->getVars();

	@$NEWV{ keys %$V } = values %$V;

	$this->setVars($NEWV);
	$this->SUPER( $NEWNODE, $USER );
}

1;
