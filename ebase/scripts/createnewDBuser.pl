#!/usr/bin/perl

use strict;
use Everything;
use Term::ReadKey;

@ARGV or die "you must specify a database!";

my $db = $ARGV[0];
initEverything($db);

print "\nNew user name? ";
my $user = ReadLine 0;
chomp $user;

my ($password, $conf) = (1..2);

ReadMode('noecho');
do {
	    print "\npassword (max 10 chars): ";
		$password = ReadLine 0;
		chomp $password;
		print "\nPlease confirm the password: ";
		$conf = ReadLine 0;
		 chomp $conf;
} while ($password ne $conf and print "\nEr...  try again.  They don't match!");

if ($DB->createDatabaseUser($user, $password)) {
	print "\n$user has been created with access to database $DB->{dbname}\n";
} else {
	print "\n$user creation failed!\n";
}



