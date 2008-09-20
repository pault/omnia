package Everything::DB::Test::Live::sqlite;

use base 'Everything::DB::Test::Live';
use Test::More;
use strict;
use warnings;


sub test_startup_1_create_database : Test(startup => 2) {

    my $self = shift;

    my $config = $self->{config};

    my $storage_class = 'Everything::DB::' . $config->database_type;

    ( my $file = $storage_class ) =~ s/::/\//g;
    $file .= '.pm';
    require $file;

    my $storage = $storage_class->new();

    $self->BAILOUT("These tests cannot be run against an existing database.")
      if $storage->databaseExists( $config->database_name );

    $storage->create_database(
        $config->database_name,          $config->database_superuser,
        $config->database_superpassword, $config->database_host,
        $config->database_port
    );

    ok( !DBI->err, '...creates a database.' ) || diag DBI->err;

    $storage->grant_privileges( $config->database_name, $config->database_user,
        $config->database_password );

    ok( !DBI->err, '...grants privileges to user.' ) || diag DBI->err;

    $self->{super_storage} = $storage;

}


sub test_nodetable3_drop_field_from_table :Test(+0) {

    return "drop field from table currently unimplemented for sqlite.";
    my $self = shift;
    $self->SUPER;


}

sub test_group_table_consistency : Test(2) {
    return "Group table consistency test currently unimplemented for sqlite - sqlite seg faults.";
    my $self = shift;
    $self->SUPER;


}


## DBD::sqlite doesn't support column_info method, hence it doesn't
## work quite the same way
sub test_get_fields_hash :Test(2) {

    my $self = shift;
    my $s = $self->{ storage };
    return unless $s->can('getFieldsHash');
    my @rv = $s->getFieldsHash( 'node', 0 );
    my %rv = map { $_ => 1 } @rv; # we don't care what order they come in

    my @expected = qw/node_id type_nodetype title author_user createtime modified hits loc_location reputation lockedby_user locktime authoraccess groupaccess otheraccess guestaccess dynamicauthor_permission dynamicgroup_permission dynamicother_permission dynamicguest_permission group_usergroup/;
    my %expected = map { $_ => 1 } @expected;

    is_deeply ( \%rv, \%expected, '...returns list of fields in table.' );

    # Strip out everything except for Field in this test
    @rv = $s->getFieldsHash( 'node', 1 );

    my @expected_hashes = map { { Field => $_ } } @expected;

    is_deeply ( \@rv, \@expected_hashes, '...returns list of hashes of fields in table.' );

}


1;
