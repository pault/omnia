use Everything::Template::Provider;
use Everything::NodeBase::Cached;
use Carp;
use Data::Dumper;

use Test::More tests => 4;

my $p = Everything::Template::Provider->new( {nodebase => bless( {}, 'Everything::NodeBase')} );

isa_ok( $p, 'Everything::Template::Provider' );
isa_ok( $p, 'Template::Provider' );
isa_ok( $p, 'Template::Base' );

my $nb = $p->get_nodebase;

isa_ok( $nb, 'Everything::NodeBase' ) || diag Dumper $p;
