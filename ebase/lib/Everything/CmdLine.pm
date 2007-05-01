package Everything::CmdLine;

use Getopt::Long;
use Cwd;
use Carp;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw(get_options abs_path);

Getopt::Long::Configure(qw/bundling/);

sub get_options {
    my ($usage_msg) = @_;
    my %opts;
    GetOptions(
        \%opts,         'user|u=s', 'password|p=s', 'host|h=s',
        'database|d=s', 'port|P=s', 'type|t=s'
    ) or usage_options($usage_msg);
    return \%opts;

}

sub usage_options {
    my ($usage_msg) = @_;
    $usage_msg ||= "Usage:\n\n";

    $usage_msg .= <<USAGE;
Takes the following options:
\t -d
\t --database
\t\t the db name. In the case of sqlite, it will be the file name of the test db, it will not be deleted on completion.  If no name is specified a temporary file will be used if possible. The temporary file will be deleted on completion.  In the case of mysql or postgresql, it is the name of the database to use.
\t -u
\t --user
\t\tthe db user.
\t -p
\t --password
\t\t the password for the db user.
\t -t
\t --type
\t\t the db type (mysql|Pg|sqlite). Defaults to sqlite.
\t -h
\t --host
\t\t the db host.
\t -P
\t --port
\t\t the port number on which the db is listening.

USAGE

    warn $usage_msg;
    exit 1;
}

=head2 C<abs_path>

Get the absolute path of the file or directory.

=cut

sub abs_path {
    my ($file) = @_;

    #thank you Perl Cookbook!
    $file =~ s{ ^ ~ ( [^/]* ) }
	{ $1
		? (getpwnam($1))[7]
			: ( $ENV{HOME} || $ENV{LOGDIR}
					|| (getpwuid($>))[7]
			  )
	}ex;

    return Cwd::abs_path($file);

}

1;
