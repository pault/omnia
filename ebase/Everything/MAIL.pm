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

	return unless $addr;
	$node = getNode($node);
	return unless $node;
	
	my @addresses = (UNIVERSAL::isa( $addr, 'ARRAY') ? @$addr : $addr);

	my $body    = $node->{doctext} || "";
	Everything::logErrors('Sending email with empty body') unless $body =~ /\S/;

	my $subject = $node->{title} || "";
	Everything::logErrors('Sending email with empty subject') unless $subject =~ /\S/;

	use Mail::Sender;

	my $SETTING = getNode('mail settings', 'setting');
	my ($mailserver, $from);

	if ($SETTING)
	{
		my $MAILSTUFF = $SETTING->getVars();
		($mailserver, $from) = @$MAILSTUFF{qw( mailserver systemMailFrom )};
	}

	unless($mailserver and $from)
	{
		Everything::logErrors('Can\'t find the mail settings; sending email with default server parameters');
		$mailserver ||= 'localhost';
		$from       ||= 'root@localhost';
	}

	my $sender = Mail::Sender->new({ smtp => $mailserver, from => $from });

	foreach my $out_addr (@addresses)
	{

		unless($sender)
		{
			Everything::logErrors('','Mail::Sender creation failed!');
			return;
		}

		my $res = $sender->MailMsg({
			to      => $out_addr,
			msg     => $body,
			subject => $subject,
		});

		if(int($res) < 0)
		{
			Everything::logErrors("MailMsg failed with code: $res");
		}

	}

	$sender->Close();                
}

sub mail2node
{
	my ($files) = @_;

	unless($files)
	{
		Everything::logErrors('No input files for mail2node!');

		#Nothing to do here!
		return;
	}

	$files = [$files] unless UNIVERSAL::isa( $files, 'ARRAY' );

	use Mail::Address;

	my ($from, $to, $subject, $body);
	foreach my $file (@$files)
	{
		unless(open FILE,"<$file")
		{
			Everything::logErrors("mail2node could not open file: $file");
			next; 
		}
		$from = $to = $subject = $body = '';

		while(<FILE>)
		{
			my $line = $_ || "";
			unless($subject){
				if ($line =~ /^From\:/)       
				{ 
					my ($addr) = Mail::Address->parse($line);
					$from      = $addr->address;

				}elsif ($line =~ /^To\:/)  
				{
					my ($addr) = Mail::Address->parse($line);
					$to = $addr->address;

				}elsif($line =~ /^Subject\: (.*)/)
				{
					$subject = $1;
				}
			}else
			{
				#Need to add the newline to preserve it correctly
				$body.=$line."\n";
			}
		
		}

		close(FILE);

		unless($subject)
		{

			Everything::logErrors("mail2node: $file doesn't appear to be a valid mail file");
			next;
		}

		my ($user, $node);

		unless($to)
		{
			Everything::logErrors("mail2node: No 'To:' parameter specified. Defaulting to user 'root'"); 
			$user = getNode("root","user");
		}else{

			$user = getNode({ email => $to }, getType('user'));

			unless($user)
			{
				Everything::logErrors("mail2node can't find user for email $to. Reverting to user 'root'");
				$user ||= getNode("root","user");
			}

		}
		$node = getNode($subject, 'mail', 'create force');

		unless($node)
		{
			Everything::logErrors("","mail2node: Node creation of type mail failed!");
			next;
		}

		$node->{doctext}      = $body;
		$node->{author_user}  = getId($user);

		if($from =~ /^From:(.*)/){
			$node->{from_address} = $1;
		}
		$node->{title} = $subject;

		unless($node->insert(-1))
		{
			Everything::logErrors("mail2node: Node insertion failed!");
			next;
		}
	}

	return 1;
}

#############################################################################
#	End of Package
#############################################################################

1;
