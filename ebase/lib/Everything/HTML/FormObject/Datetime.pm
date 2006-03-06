
=head1 Everything::HTML::FormObject::Datetime

Package that implements the base Datetime functionality.

Copyright 2001 - 2003 Everything Development Inc.

=cut

package Everything::HTML::FormObject::Datetime;

use strict;
use Everything;

use Everything::HTML::FormObject;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject");

#quickie function to make an array of #s in two-digit format
sub doubleDigit
{
	map { sprintf "%.2d", $_ } @_;
}

sub makeDatetimeMenu
{
	my ( $query, $prefix, $defaultdate ) = @_;
	my ( $date, $time ) = split ' ', $defaultdate;
	my ( $year, $month, $day ) = doubleDigit split( /-/, $date );
	my ( $hour, $minute ) = doubleDigit split( /:/, $time );
	($minute) = doubleDigit( $minute - $minute % 5 );

	my @years = ( 1999 .. 2009 );
	my ( @months, @dates, @hours, @minutes );
	my %labels = (
		"01" => "Jan",
		"02" => "Feb",
		"03" => "Mar",
		"04" => "Apr",
		"05" => "May",
		"06" => "Jun",
		"07" => "Jul",
		"08" => "Aug",
		"09" => "Sep",
		10   => "Oct",
		11   => "Nov",
		12   => "Dec"
	);
	@months  = doubleDigit( 1 .. 12 );
	@dates   = doubleDigit( 1 .. 31 );
	@hours   = doubleDigit( 0 .. 23 );
	@minutes = doubleDigit( map { $_ * 5 } ( 0 .. 11 ) );

	$query->popup_menu(
		-name    => "$prefix" . "_month",
		-values  => \@months,
		-labels  => \%labels,
		-default => $month
		)
		. $query->popup_menu(
		-name    => "$prefix" . "_day",
		-values  => \@dates,
		-default => $day
		)
		. $query->popup_menu(
		-name    => "$prefix" . "_year",
		-values  => \@years,
		-default => $year
		)
		. " at "
		. $query->popup_menu(
		-name    => "$prefix" . "_hour",
		-values  => \@hours,
		-default => $hour
		)
		. $query->popup_menu(
		-name    => "$prefix" . "_minute",
		-values  => \@minutes,
		-default => $minute
		);

}

sub paramToDatetime
{
	my ( $query, $prefix ) = @_;
	my $str =
		  $query->param( $prefix . "_year" ) . "-"
		. $query->param( $prefix . "_month" ) . "-"
		. $query->param( $prefix . "_day" ) . " "
		. $query->param( $prefix . "_hour" ) . ":"
		. $query->param( $prefix . "_minute" ) . ":00";

	#return "2000-03-01 12:00:00";
	return $str if $str =~ /^\d{4}-\d{2}-\d{2} \d\d:\d\d:\d\d$/;
	"0000-00-00 00:00:00";
}

=cut


=head2 C<genObject>

This is called to generate the needed HTML for this checkbox form object.

=over 4

=item * $query

The CGI object we use to generate the HTML.

=item * $bindNode

A node ref if this checkbox is to be bound to a field on a node. undef if this
item is not bound.

=item * $field

The field on the node that this checkbox is bound to.  If $bindNode is undef,
this is ignored.

=item * $name

The name of the form object, i.e., E<lt>input type=check name=$nameE<gt>.

=item * $checked

A string value of what should be set if the checkbox is checked.

=item * $uncheched

A string value of what should be set if the checkbox is NOT checked.

=item * $default

Either 1 (checked), 0 (not checked), or "AUTO", where AUTO will set it based on
whatever the bound node's field value is.

=item * $label

A text string that is to be a visible label for the checkbox.

=back

Returns the generated HTML for this checkbox object.

=cut

sub genObject
{
	my $this = shift @_;
	my ( $query, $bindNode, $field, $name, $default ) =
		getParamArray( "query, bindNode, field, name, default", @_ );

	$name ||= $field;

	my $html =
		$this->SUPER::genObject( $query, $bindNode, $field, $name ) . "\n";

	my $date;

	#date binding:
	#first priority to the database
	if (   ref $bindNode
		&& $bindNode->{$field}
		&& $bindNode->{$field} =~ /[1-9]/ )
	{
		$date = $bindNode->{$field};
	}

	#second priority to the defined default
	elsif ( $default && $default =~ /[1-9]/ )
	{
		$date = $default;
	}

	#otherwise use "now()"
	else
	{
		$date = $DB->sqlSelect('now()');
	}

	$html .= makeDatetimeMenu( $query, $name, $date );
	return $html;
}

sub cgiUpdate
{
	my ( $this, $query, $name, $NODE, $overrideVerify ) = @_;
	my $value = paramToDatetime( $query, $name );

	my $field = $this->getBindField( $query, $name );

	# Make sure this is not a restricted field that we cannot update
	# directly.
	return 0 unless ( $overrideVerify or $NODE->verifyFieldUpdate($field) );

	$$NODE{$field} = $value;

	return 1;
}

1;

