package Everything::MAIL;

############################################################
#
#	Everything::HTML.pm
#		A module for the HTML stuff in Everything.  This
#		takes care of CGI, cookies, and the basic HTML
#		front end.
#
############################################################

use strict;
use Everything;



sub BEGIN {
	use Exporter ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
			node2mail
			mail2node);
}
sub node2mail
{
	my ($addr, $node) = @_;
	my @addresses = (ref $addr eq "ARRAY") ? @$addr:($addr);
	my ($user) = getNodeWhere({node_id => $$node{author_user}},$NODETYPES{user});
	my $from = $$user{email};
	my $subject = $$node{title};
	my $body = $$node{doctext};
	use Mail::Sender;
	my $sender = new Mail::Sender{smtp => 'mail.egl.net', from => 'vroon@blockstackers.com'};
	$sender->MailMsg({to=>$addr,
			subject=>$subject,
			msg => $body});
	$sender->Close();                
}

sub mail2node
{
	my ($file) = @_;
	my @filez = (ref $file eq "ARRAY") ? @$file:($file);
	use Mail::Address;
	my $line = '';
	my ($from, $to, $subject, $body);
	foreach(@filez)
	{
		open FILE,"<$_" or die 'suck!\n';
		until($line =~ /^Subject\: /)
		{
			$line=<FILE>;
			if($line =~ /^From\:/)       
			{ 
				my ($addr) = Mail::Address->parse($line);
				$from = $addr->address;
			}
			if($line =~ /^To\:/)  
			{
				my ($addr) = Mail::Address->parse($line);
				$to = $addr->address;
			}
			if($line =~ /^Subject\: (.*?)/)
			{ print "hya!\n"; $subject = $1; }
			print "blah: $line" if ($line);
		}
		while(<FILE>)
		{
			my $body .= $_;
		}
		my ($user) = getNodeWhere({email=>$to},$NODETYPES{user});
		my $node;
		%$node = { author_user => getId($user),
			from_address => $from,
			doctext => $body};
        insertNode($subject,$NODETYPES{mail},-1,$node);
	}
}
1;
