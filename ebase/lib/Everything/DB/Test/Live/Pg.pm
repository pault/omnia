package Everything::DB::Test::Live::Pg;

use base 'Everything::DB::Test::Live';
use Test::More;
use SUPER;
use strict;
use warnings;


sub test_delete_test_database : Test(shutdown => +0) {
    my $self = shift;
    undef $self->{ super_storage };
    ## sleep briefly to make sure that other "users" are disconnected
    sleep 1;
    $self->SUPER;
}

1;
