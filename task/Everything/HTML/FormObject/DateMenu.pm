package Everything::HTML::FormObject::DateMenu;

#############################################################################
#	Everything::HTML::FormObject::DateMenu
#		Package that implements the base DateMenu functionality.
#
#	Copyright 2001 Everything Development Inc.
#	Format: tabs = 4 spaces
#
#############################################################################

use strict;
use Everything;
use Everything::HTML::FormObject::FormMenu;

use vars qw( @ISA );
@ISA = ('Everything::HTML::FormObject::FormMenu');

#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This generates the HTML necessary to make date selection form widgets.
#		Note that, if bound to a node field, this method assumes a data in the
#		ISO standard format YYYY-MM-DD.  If unbound, it uses localtime().
#
#	Parameters
#		Besides the parameters of Everything::Node::FormObject::genParam(), 
#		this takes:
#
#		$range - the number of years before and after the current year to
#			display
#
#	Returns
#		The generated HTML for this object
#
sub genObject
{
	my $this = shift;
	my ($query, $bindNode, $field, $name, $range) =
		getParamArray('query, bindNode, field, name, range', @_);
	my $html = $this->SUPER($query, $bindNode, $field, $name) . "\n";
	$range ||= 5;

	my ($year, $month, $day);

	# month and day can't have leading zeroes or they won't be selected properly
	if (defined($bindNode) and exists($bindNode->{$field})) {
		($year, $month, $day) = split(/-/, $bindNode->{$field});
		$month += 0;
		$day += 0;
	} else {
		($year, $month, $day) = (localtime)[5, 4, 3];
		$year += 1900;
		$month++;
	}

	$this->addArray([1 .. 31]);
	$html .= $this->genPopupMenu($query, $name . '_day', $day);
	$this->clearMenu();

	my $months = { 1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April',
		5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August', 9 => 'September', 
		10 => 'October', 11 => 'November', 12 => 'December'
	};

	$this->addArray([1 .. 12]);
	$this->addLabels($months);
	$html .= $this->genPopupMenu($query, $name . '_month', $month);
	$this->clearMenu();

	$this->addArray([($year - $range) .. ($year + $range)]);
	$html .= $this->genPopupMenu($query, $name . '_year', $year);
	
	return $html;
}

##############################################################################
#	Sub
#		cgiUpdate
#
#	Purpose
#		Updates the bound node field.  This also performs some sanity checks to
#		make sure that the selected date is valid.  Note that it does not
#		currently verify the day of the month with the month.
#
#	Parameters
#		Same as those of Everything::Node::FormMenu::cgiUpdate()
#
#	Returns
#		1 on success, 0 otherwise (verification failed)
#
sub cgiUpdate
{
	my ($this, $query, $name, $bindNode, $overrideVerify) = @_;
	my ($year, $month, $day);

	# pad the month and the day back into two-digit format
	$year = $query->param($name . '_year');
	$month = $query->param($name . '_month');
	$day = $query->param($name . '_day');

	return 0 unless ($day =~ /^(?:0?[1-9]|[12][0-9]|3[01])$/);
	return 0 unless ($month =~ /^(?:0?[1-9]|1[0-2])$/);
	return 0 unless ($year =~ /^\d{4}$/);

	my $field = $this->getBindField($query, $name);
	$bindNode->{$field} = sprintf("$year-%02d-%02d", $month, $day);
	return 1;
}

#############################################################################
# End of package
#############################################################################

1;
