package Everything::MAIL;

############################################################
#
#	Everything::MAIL.pm
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
	my $user = getNode($$node{author_user});
	my $subject = $$node{title};
	my $body = $$node{doctext};
	use Mail::Sender;

	my $SETTING = getNode('mail settings', 'setting');
	my ($mailserver, $from);
	if ($SETTING) {
		my $MAILSTUFF = $SETTING->getVars();
		$mailserver = $$MAILSTUFF{mailServer};
		$from = $$MAILSTUFF{systemMailFrom};
	} else {
		$mailserver = "localhost";
		$from = "root\@localhost";
	}


	my $sender = new Mail::Sender{smtp => $mailserver, from => $from};
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

		my $user = getNode({email=>$to}, getType("user"));
		my $node = getNode($subject, "mail", "create force");
		
		$node->insert(-1);
		$$node{author_user} = getId($user);
		$$node{from_address} = $from;
		$$node{doctext} = $body;
		
		$node->update(-1);
	}
}

#############################################################################
#	End of Package
#############################################################################

1;
