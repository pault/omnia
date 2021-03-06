use Term::ReadKey;

#
#	set up the default typeversion table for the basic install
#
print "setting up the typeversion table...\n";

my $nodetypes = getNodeWhere( {}, "nodetype" );
my %exceptions = ( 'user' => 1, 'document' => 1, 'nodelet' => 1 );

for my $nodetype (@$nodetypes)
{
	next if exists $exceptions{ $nodetype->{title} };
	$Everything::DB->sqlInsert( "typeversion",
		{ typeversion_id => $nodetype->{node_id}, version => 1 } );
}

ReadMode('noecho');

my ( $password, $conf ) = ( 1 .. 2 );

do
{
	print "\nPlease set the root user password (max 10 chars): ";
	chomp( $password = ReadLine 0 );

	print "\nPlease confirm the root user password: ";
	chomp( $conf     = ReadLine 0 );
} while (
	$password ne $conf and print "\nEr...  try again.  They don't match!"
);

print "\n";
ReadMode('normal');

my $U = getNode( 'root', 'user' );
$U->{passwd} = $password;
$U->update(-1);

print "optimizing the Guest User's nodelets...\n";
my $GU         = getNode( "Guest User", "user" );
my $GUv        = $GU->getVars();
my $nodeletgrp =
	getNodeById( getNode( "system settings", "setting" )->getVars()
		->{default_nodeletgroup} );

my @newgrp;
for my $nl ( @{ $nodeletgrp->{group} } )
{
	my $nodelet = getNode( $nl );
	next unless $nodelet;
	push @newgrp, $nl if $nodelet->hasAccess( $GU, "x" );
}

$GUv->{nodelets} = join ",", @newgrp;
$GU->setVars($GUv);
$GU->update(-1);
