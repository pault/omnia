package Everything::DB::Node::nodegroup;

use Moose;

extends 'Everything::DB::Node::node';

override retrieve_node => sub {

    my ( $self, $args ) = @_;
    my $node_data = super;

    return unless $node_data;
    my $nb = $$args{ nodebase };
    my $db = $nb->get_storage;

    my $group_table;
    if (  $group_table = $db->retrieve_group_table( $$node_data{type_nodetype} ) ) {
	my $cursor = $db->sqlSelectMany(
					'node_id', $group_table,
					$group_table . "_id=$$node_data{node_id}",
					'ORDER BY orderby'
				       );

	my @group;
	while ( my $nid = $cursor->fetchrow() ) {
	    push @group, $nid;
	}
	$cursor->finish();

	$$node_data{group} = \@group if @group;
    }


    return $node_data;
};


around update_node => sub {
    my $orig = shift;
    my $self = shift;
    my ($node) = @_;


    my $node_id = $self->$orig( $node );
    my $storage = $self->storage; 		use Data::Dumper; warn Dumper $node->{group} if $$node{title} eq 'gods';
    my $group = $node->restrict_type( $node->{group} );

    my %DIFF;
    my $updated  = 0;
    my $table    = $node->isGroup();

    # This returns an array ref of the list of node_id's contained in
    # the group

    my $orgGroup = $node->selectGroupArray();

    # We need to determine how many nodes have been inserted or removed
    # from the group.  We create a hash for each node_id.  For each one
    # that exists in the orginal group, we subract one.  For each one
    # that exists in our current group, we add one.  This way, if any
    # nodes have been removed, they will be negative (exist in the orginal
    # group, but not in the current) and any new nodes will be positive.
    # If there is no change for a particular node, it will be zero
    # (subtracted once for being in the original group, added once for
    # being in the current group).

    # orgGroup is the group in the db
    # $group is node_id's in the updated node not yet in the database.

    # $DIFF{ node_id } will be negative if in dbgroup, but not in
    # current nodegroup

    # $DIFF{ node_id } will be positive if not in dbgroup, but is in
    # current nodegroup

    # $DIFF{ node_id } will be zero if both in dbgroup, and in
    # current nodegroup. That is no change.

    foreach (@$orgGroup) {
        $DIFF{$_} = 0 unless exists $DIFF{$_};
        $DIFF{$_}--;
    }
    foreach (@$group) {
        $DIFF{$_} = 0 unless exists $DIFF{$_};
        $DIFF{$_}++;
    }

    my $sql;

    # Actually remove the nodes from the group
    foreach my $member ( keys %DIFF ) {
        my $diff = $DIFF{$member};

        if ( $diff < 0 ) {
            my $abs = abs($diff);

            # diff is negative, so we need to remove abs($diff) number
            # of entries.
            my $maxrank =
              $storage
              ->sqlSelect( 'max(rank)', $table, "${table}_id=? and node_id=?",
                "limit $abs", [ $node->{node_id}, $member ] );

            next unless $maxrank;

            my $count = $maxrank - $abs;

            my $deleted = $storage->sqlDelete(
                $table,
                "${table}_id = ? AND node_id = ? and rank > ?",
                [ $node->{node_id}, $member, $count ]
            );

            Everything::logErrors(
                "Wrong number of group members deleted! $deleted")
              unless $deleted == $abs;

            $updated = 1;
        }
        elsif ( $diff > 0 ) {

            # diff is positive, so we need to insert $diff number
            # of new members for this particular node_id.

            # Find what the current max rank of the group is.
            my $rank =
              $storage->sqlSelect( 'max(rank)', $table, $table . "_id=?",
                '', [ $node->{node_id} ] );

            $rank ||= 0;

            for ( my $i = 0 ; $i < $diff ; $i++ ) {
                $rank++;

                $storage->sqlInsert(
                    $table,
                    {
                        $table . "_id" => $node->{node_id},
                        rank           => $rank,
                        node_id        => $member,
                        orderby        => 0,
                    }
                );

                $updated = 1;
            }
        }
    }

    unless ($updated) {

        # There were no additions, nor were any nodes removed.  However,
        # the order may have changed.  We need to check for that.
        for my $i ( 0 .. $#$group ) {
            $updated = 1, last unless $$group[$i] == $$orgGroup[$i];
        }
    }

    if ($updated) {

        # Ok, we have removed and inserted what we needed.  Now we need to
        # reassign the orderby;

        # Clear everything to zero orderby for this group.  We need to do
        # this so that we know which ones we have updated.  If a node was
        # inserted into the middle, all of the orderby's for nodes after
        # that one would need to be incremented anyway.  This way, we reset
        # everything and update each member one at a time, and we are
        # guaranteed not to miss anything.
        $storage->sqlUpdate(
            $table,
            { orderby => 0 },
            $table . "_id=$node->{node_id}"
        );

        my $orderby = 0;
        foreach my $id (@$group) {

            # This select statement here is only needed to get a specific row
            # and single out a node in the group.  If the database supported
            # "LIMIT #" on the update, we could just say update 'where
            # orderby=0 LIMIT 1'.  So, until the database supports that we
            # need to find the specific one we want using select
            my $rank =
              $storage->sqlSelect( 'rank', $table,
                $table . "_id=$node->{node_id} and node_id=$id and orderby=0",
                'LIMIT 1' );

            my $sql =
                $table
              . "_id=$node->{node_id} and node_id=$id and "
              . "rank=$rank";
            $storage->sqlUpdate( $table, { orderby => $orderby }, $sql );

            $orderby++;
        }
    }

    $node->{group} = $group;

    #remove from groupCache
    $node->groupUncache();

    return $node_id;
};

override construct_node_data_from_hash => sub {

    my ( $self, $NODE ) = @_;

    super;
    my $db = $self->storage;

    my $group_table;
    if (  $group_table = $db->retrieve_group_table( $$NODE{type_nodetype} ) ) {
	my $cursor = $db->sqlSelectMany(
					'node_id', $group_table,
					$group_table . "_id=$$NODE{node_id}",
					'ORDER BY orderby'
				       );

	my @group;
	while ( my $nid = $cursor->fetchrow() ) {
	    push @group, $nid;
	}
	$cursor->finish();

	$$NODE{group} = \@group if @group;
    }

    return 1;
};


=head2 group_table

Returns the name of the group table for this nodegroup.

=cut

sub group_table {

    my $self = shift;
    my $storage = $self->storage;
    return $storage->retrieve_group_table( $self->node->get_type_nodetype );

}

1;

__END__
