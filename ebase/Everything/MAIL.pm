package Everything::MAIL;

############################################################
#
#	Everything::MAIL.pm
#
############################################################

use strict;
use Everything;

BEGIN
{
	use Exporter ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw( node2mail mail2node );
}

sub node2mail
{
	my ($addr, $node) = @_;
	my @addresses = (UNIVERSAL::isa( $addr, 'ARRAY') ? @$addr : $addr);
	my $body    = $node->{doctext};
	my $user    = getNode($node->{author_user});
	my $subject = $node->{title};

	use Mail::Sender;

	my $SETTING = getNode('mail settings', 'setting');
	my ($mailserver, $from);

	if ($SETTING)
	{
		my $MAILSTUFF = $SETTING->getVars();
		($mailserver, $from) = @$MAILSTUFF{qw( mailserver systemMailFrom )};
	}
	else
	{
		$mailserver = 'localhost';
		$from       = 'root@localhost';
	}

	my $sender = Mail::Sender->new({ smtp => $mailserver, from => $from });

	$sender->MailMsg({
		to      => $addr,
		msg     => $body,
		subject => $subject,
	});

	$sender->Close();                
}

sub mail2node
{
	my ($files) = @_;
	$files = [$files] unless UNIVERSAL::isa( $files, 'ARRAY' );

	use Mail::Address;

	my ($from, $to, $subject, $body);
	foreach my $file (@$files)
	{
		open FILE,"<$file" or die 'suck!\n';
		my $line = '';
		until ($line =~ /^Subject\: /)
		{
			$line = <FILE>;
			if ($line =~ /^From:/)       
			{ 
				my ($addr) = Mail::Address->parse($line);
				$from      = $addr->address;
			}
			if ($line =~ /^To:/)  
			{
				my ($addr) = Mail::Address->parse($line);
				$to = $addr->address;
			}
			if ($line =~ /^Subject\: (.*?)/)
			{
				$subject = $1;
			}
			print "blah: $line" if $line;
		}

		$body .= $_ while <FILE>;

		my $user = getNode({ email => $to }, getType('user'));
		my $node = getNode($subject, 'mail', 'create force');

		$node->insert(-1);
		$node->{doctext}      = $body;
		$node->{author_user}  = getId($user);
		$node->{from_address} = $from;

		$node->update(-1);
	}
}

#############################################################################
#	End of Package
#############################################################################

1;
