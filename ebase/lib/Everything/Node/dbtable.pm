
=head1 Everything::Node::dbtable

Class representing the dbtable node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::dbtable;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::node';

use MooseX::ClassAttribute;
class_has class_nodetype => (
    reader  => 'get_class_nodetype',
    writer  => 'set_class_nodetype',
    isa     => 'Everything::Node::nodetype',
    default => sub {
        Everything::Node::nodetype->new(
            Everything::NodetypeMetaData->default_data );
    }
);

=head2 C<insert>

We need to create the table in the database.  This gets the node inserted into
the database first, then creates the table.

Allowed characters and length limits are taken from MySQL table naming
conventions.

=cut

override insert => sub {
    my ( $this, $USER ) = @_;

    my $result = $this->super($USER);
    $this->get_nodebase->createNodeTable( $this->{title} ) if $result > 0;

    return $result;
};

# MySQL reserved words as of 4.0.2-alpha

my %reserved = map { $_ => 1 }
  qw( master_server_id group regexp fulltext unlock case values delayed
  between sql_big_result double tinyint current_timestamp database numeric
  tables limit foreign sql_small_result match insert_id replace optionally
  index sql_big_selects starting current_time returns on varying day_minute
  ssl asc sql_warnings or add when usage table natural lock berkeleydb update
  using right minute_second outer null varchar columns key interval optimize
  all rename outfile desc sql_big_tables mediumint sql_log_update kill where
  as day_hour escaped if sql_auto_is_null require set create char longblob
  auto_increment from in middleint describe is analyze primary
  sql_buffer_result year_month infile float dec by join show
  sql_slave_skip_counter procedure and keys explain sql_log_off striped
  precision with option union decimal tinyblob revoke bdb mediumblob leading
  zerofill alter constraint having restrict read for long cross grant rlike
  delete real integer character int insert function hour_second privileges
  longtext partial binary sql_quote_show_create sql_max_join_size
  current_date not left order column terminated straight_join cascade else
  both into write enclosed unsigned fields distinct trailing varbinary ignore
  sql_low_priority_updates unique to innodb default low_priority
  master_log_seq drop exists smallint sql_select_limit soname then mrg_myisam
  change tinytext load mediumtext sql_safe_updates distinctrow bigint like
  use sql_log_bin day_second high_priority lines select hour_minute blob
  references last_insert_id inner purge sql_calc_found_rows databases );

=head2 C<restrictTitle>

Prevent invalid database names from being created as titles 

=over 4

=item * $node

the node containing a C<title> field to check

=back

Returns true, if the title is allowable, false otherwise.

=cut

sub restrictTitle {
    my ($this) = @_;
    my $title = $this->{title} or return;

    # limit is 61 characters, as we append '_id' to title for primary key name
    if ( length $title > 61 ) {
        Everything::logErrors( 'dbtable name must not exceed 61 characters!',
            '', '', '' );
        return;
    }

    # check for allowed characters
    if ( $title =~ tr/A-Za-z0-9_//c ) {
        Everything::logErrors(
            'dbtable name contains invalid characters.
		 	 Only alphanumerics and the underscore are allowed.  No spaces!',
            '', '', ''
        );
        return;
    }

    if ( exists $reserved{$title} ) {
        Everything::logErrors( "dbtable name '$title' is a MySQL reserved word",
            '', '', '' );
        return;
    }

    return 1;
}

=head2 C<nuke>

Overrides the base node::nuke so we can drop the database table

=cut

override nuke => sub {
    my $this   = shift;
    my $result = $this->super(shift);
    $this->{DB}->dropNodeTable( $this->{title} ) if $result > 0;

    return $result;
};

1;
