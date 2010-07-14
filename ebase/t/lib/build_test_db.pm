#! perl

# XXX: this file depends on the format of tables/*.sql
# run it through SQL::Translator if and when it changes!

use strict;
use warnings;

use DBI;
use File::Spec::Functions 'catfile';
use Everything::DB::sqlite;

my $db_file = catfile(qw( t ebase.db ));
unlink $db_file;

my $dbh = DBI->connect( "dbi:SQLite:dbname=$db_file", '', '' );

my @tables = Everything::DB::sqlite->base_tables;

my $nodes = join "\n", Everything::DB::sqlite->base_nodes;

for my $statement (@tables, split /\n/, $nodes )
{
	next unless $statement =~ /\S/;
	$dbh->do( $statement );
}

$dbh->disconnect();

1;
