package Everything::DB::Node::node;

use Moose;

with "Everything::DBNodeSqlRole";

has node => ( is => 'rw' );

1;

__END__
