
#
#	set up the default typeversion table for the basic install
#
print "setting up the typeversion table...\n";

my $nodetypes = getNodeWhere ( {}, "nodetype");
my %exceptions = ( 'user' => 1, 'document' => 1, 'nodelet' => 1 );

foreach (@$nodetypes) { 
	next if exists $exceptions{$$_{title}};
	$DB->sqlInsert("typeversion", { typeversion_id => $$_{node_id}, version => 1 } ) 
}

use Term::ReadKey;

ReadMode('noecho');

my ($password, $conf) = (1..2);

do {
	print "\nPlease set the root user password (max 10 chars): ";
	$password = ReadLine 0;
	chomp $password;
	print "\nPlease confirm the root user password: ";
	$conf = ReadLine 0;
	chomp $conf;
} while ($password ne $conf and print "\nEr...  try again.  They don't match!"); 	
print "\n";
ReadMode('normal');

my $U = getNode('root','user');
$$U{passwd} = $password;
$U->update(-1);

print "optimizing the Guest User's nodelets...\n";
my $GU = getNode("Guest User","user");
my $GUv = $GU->getVars();
my $nodeletgrp = getNodeById(getNode("system settings","setting")->getVars()->{default_nodeletgroup});
my @newgrp;
foreach(@{$nodeletgrp->{group}})
{
  my $nodelet = getNode($_);
  next unless $nodelet;
  push @newgrp,$_ if $nodelet->hasAccess($GU,"x");
}
$GUv->{nodelets} = join ",",@newgrp;
$GU->setVars($GUv);
$GU->update(-1);
