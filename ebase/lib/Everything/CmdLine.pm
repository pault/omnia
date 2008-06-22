package Everything::CmdLine;

use Everything::Config;
use Getopt::Long;
use Term::ReadKey;
use Cwd;
use Carp;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw(get_options abs_path usage_options make_nodebase readline_quick confirm_yn config);

Getopt::Long::Configure(qw/bundling/);

sub get_options {
    my ($usage_msg, $other_options) = @_;
    $other_options ||= [];
    my %opts;
    $opts{database} = $opts{port} = $opts{host} = $opts{password} = $opts{user} = '';
    GetOptions(
        \%opts,         'user|u=s', 'password|p=s', 'host|h=s',
        'database|d=s', 'port|P=s', 'type|t=s', @$other_options
    ) or usage_options($usage_msg);
    return \%opts;

}

sub usage_options {
    my ($usage_msg) = @_;
    $usage_msg ||= "Usage:\n\n";

    $usage_msg .= <<USAGE;
Also available are the following standard options:
\t -d
\t --database
\t\t the db name. In the case of sqlite, it will be the file name.
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

    print $usage_msg;
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

=cut

=head2 C<make_nodebase>

Takes a hash reference like the one returned by get_options(). Returns a nodebase object if it can get one.

=cut

sub make_nodebase {
    my ($opts) = @_;

    $$opts{type} ||= 'sqlite';
    $$opts{user} ||= $ENV{USER};
    $$opts{host} ||= 'localhost';

    my $nb =
      Everything::NodeBase->new(
        "$$opts{database}:$$opts{user}:$$opts{password}:$$opts{host}",
        1, $$opts{type} );
    croak
"Can't connect to nodebase using database '$$opts{database}', user '$$opts{user}', password '$$opts{password}', host '$$opts{host}' and type '$$opts{type}'"
      unless $nb;

    return $nb;
}

sub config {
    my ( $arg ) = @_;
    my $opts = $arg || get_options;
    my $c = Everything::Config->new;
    $c->database_name( $$opts{ database } );
    $c->database_user( $$opts{ user } );
    $c->database_password( $$opts{ password } );
    $c->database_host( $$opts{ host } );
    $c->database_port( $$opts{ port } );
    $c->database_type( $$opts{ type } );
    return $c;
}

sub readline_quick
{
	my ($question) = @_;
	print "$question ";
	my $result = ReadLine 0;
	chomp $result;
	$result;
}


sub confirm_yn {

    my ($q) = @_;
    print "$q (N/y)";
    my $ans = <STDIN>;
    return 1 if $ans =~ /^y/i;
    return 0;

}

1;
