
=head1 Everything::Mail

=cut

package Everything::Mail;

use strict;
use Everything qw/getNode/;
use IO::File;
use Mail::Sender;
use Mail::Address;
use Scalar::Util 'reftype';

use base 'Exporter';
our @EXPORT_OK = qw(node2mail mail2node);

sub node2mail
{
	my ( $addr, $node ) = @_;

	return unless $addr;
	$node = getNode($node);
	return unless $node;

	my @addresses = ( reftype( $addr ) || '' ) eq 'ARRAY' ? @$addr : $addr;

	my $body = $node->{doctext} || '';
	Everything::logErrors('Sending email with empty body')
		unless $body =~ /\S/;

	my $subject = $node->{title} || '';
	Everything::logErrors('Sending email with empty subject')
		unless $subject =~ /\S/;

	my $from = $node->{from_address} || '';

	my $SETTING = getNode( 'mail settings', 'setting' );
	my $mailserver;

	if ($SETTING)
	{
		my $MAILSTUFF = $SETTING->getVars();
		$mailserver = $MAILSTUFF->{mailserver};
		$from ||= $MAILSTUFF->{systemMailFrom};
	}

	unless ( $mailserver and $from )
	{
		Everything::logErrors( "Can't find the mail settings;"
				. 'sending email with default server parameters' );
		$mailserver ||= 'localhost';
		$from       ||= 'root@localhost';
	}

	my $sender = Mail::Sender->new( { smtp => $mailserver, from => $from } )
		or Everything::logErrors( '', 'Mail::Sender creation failed!' );
	return unless $sender;

	foreach my $out_addr (@addresses)
	{
		my $res = $sender->MailMsg(
			{
				to      => $out_addr,
				msg     => $body,
				subject => $subject,
			}
		);

		if ( int($res) < 0 )
		{
			Everything::logErrors("MailMsg failed with code: $res");
		}
	}

	$sender->Close();
}

sub mail2node
{
	my ($files) = @_;

	# Nothing to do here!
	return Everything::logErrors('No input files for mail2node!') unless $files;

	$files = [$files] unless ( reftype( $files ) || '' ) eq 'ARRAY';

	my ( $from, $to, $subject, $body );
	foreach my $file (@$files)
	{
	    my $fh;
		unless ( $fh = IO::File->new("< $file") )
		{
			Everything::logErrors("mail2node could not open '$file': $!");
			next;
		}
		$from = $to = $subject = $body = '';

		while (<$fh>)
		{
			my $line = $_ || "";
			unless ($subject)
			{
				if ( $line =~ /^From\:/ )
				{
					my ($addr) = Mail::Address->parse($line);
					$from = $addr->address;

				}
				elsif ( $line =~ /^To\:/ )
				{
					my ($addr) = Mail::Address->parse($line);
					$to = $addr->address;

				}
				elsif ( $line =~ /^Subject\: (.*)/ )
				{
					$subject = $1;
				}
			}
			else
			{

				$body .= $line;
			}

		}

		$fh->close;

		unless ($subject)
		{
			Everything::logErrors( "mail2node: "
					. "$file doesn't appear to be a valid mail file" );
			next;
		}

		my ( $user, $node );

		unless ($to)
		{
			Everything::logErrors( "mail2node: "
					. "No 'To:' parameter specified. Defaulting to user 'root'"
			);
			$user = getNode( "root", "user" );
		}
		else
		{
			$user = getNode( { email => $to }, getType('user') );

			unless ($user)
			{
				Everything::logErrors( "mail2node: "
						. "can't find user for email $to. Reverting to user 'root'"
				);
				$user ||= getNode( "root", "user" );
			}

		}
		$node = getNode( $subject, 'mail', 'create force' );

		unless ($node)
		{
			Everything::logErrors( "",
				"mail2node: " . "Node creation of type mail failed!" );
			next;
		}

		$node->{doctext}     = $body;
		$node->{author_user} = getId($user);

		if ( $from =~ /^From:(.*)/ )
		{
			$node->{from_address} = $1;
		}
		$node->{title} = $subject;

		unless ( $node->insert(-1) )
		{
			Everything::logErrors("mail2node: Node insertion failed!");
			next;
		}
	}

	return 1;
}

1;
