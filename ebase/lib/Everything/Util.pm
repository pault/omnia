
=head1 Everything::Util

Utility functions

Copyright 2000 - 2002 Everything Development Company

=cut

package Everything::Util;

#	Format: tabs = 4 spaces

use strict;

use URI::Escape ();
use base 'Exporter';
our (@EXPORT_OK);
@EXPORT_OK = qw/escape unescape/;

=cut


=head2 C<escape>

This encodes characters that may interfere with HTML/perl/sql into a hex number
preceeded by a '%'.  This is the standard HTML thing to do when uncoding URLs.

=over 4

=item * $esc

the string to encode.

=back

Returns the escaped string

=cut

*escape = *URI::Escape::uri_escape;

=cut


=head2 C<unescape>

Convert the escaped characters back to normal ascii.  See escape().

Returns the first item in the array.  Basically good for doing:

  $url = unescape($url);

=cut

*unescape = *URI::Escape::uri_unescape;

#############################################################################
# end of package
#############################################################################

1;
