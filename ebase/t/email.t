#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	use lib '../blib/lib', '../lib', '..';
}

use Test::More tests => 1;

use_ok( 'Everything::MAIL' ) or exit;

# node2mail
# take address, node
# 	get array of addresses (can be ref)
#	get node for author of node
#	use title of node for subject
#	use doctext of node for body
#	use Mail::Sender
#	getNode 'mail settings'
#		-if that worked
#			get vars from setting
#			get mailServer from vars
#			get systemMailFrom
#		otherwise
#			use 'localhost' and 'root@localhost'
#	create new Mail::Sender object with mailserver and from
#	call MailMsg with addresses, subject, message
#	close Sender object

# mail2node
# take file
#	get array of files (can be ref)
#	use Mail::Address
#	loop through files
#		open file
#		look for 'Subject:' line
#			get 'From:' and make Mail::Address parse it, store in $from
#			get 'To:' line, parse it, store in $to
#			get 'Subject:' line, store in $subject
# 		slurp rest of file into $body (potential bug)
#		getNode of 'user' type, given registered user email address
#		getNode for new blank 'mail' node
#		insert node
#		set author, from_address, and body
#		update node
