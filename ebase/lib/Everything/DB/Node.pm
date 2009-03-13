package Everything::DB::Node;

use Scalar::Util qw/reftype/;
use Moose;

use File::Find;
use File::Spec;

BEGIN {
    my $module_base = File::Spec->catfile(  qw/Everything DB Node/ );
    my @dirs = grep { -e $_ } map { File::Spec->catfile ( $_, $module_base ) } @INC;

    find ( sub { return unless /\.pm$/; my $mod = File::Spec->catfile( $module_base, $_ ); require $mod; import $mod; }, @dirs );

}

has node => ( is => 'rw', isa => 'Everything::Node::node' );
has data => ( is => 'rw', isa => 'HashRef');
has db => ( is => 'rw', isa => 'Everything::DB', required => 1 );

sub instantiate {

    my ( $factory_name, @args ) = @_;

    my $self = $factory_name->new( @args );

    my $type_id;
    if (  my $node = $self->node ) {

	$type_id = $node->get_type_nodetype;

    } else {
	$type_id= $self->data->{type_nodetype};
    }

    my $db = $self->db;

    my $hierarchy = $db->nodetype_hierarchy_by_id( $type_id );

    my $db_node_class = '';
    my $db_node_instance;

    my @try = ();
    foreach ( @$hierarchy ) {
	$db_node_class = 'Everything::DB::Node::' . $_->{title};

	eval { $db_node_instance = $db_node_class->new( { node => $self->node,  data => $self->data, storage => $self->db });
	   };
	push @try, $@ if $@;

	return $db_node_instance if $db_node_instance;
    }

    die "No modules found:  @try";

}

1;
