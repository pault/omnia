
BEGIN {
    require 'Test/More.pm';
    if ( !-e 't/conf/httpd.conf' ) {
        Test::More->import(
            skip_all => 'Needs proper apache configuration to run.' );
    }
}

use Apache::Test '-withtestmore';
use Apache::TestRequest qw(GET);
use Apache::TestUtil;
use Apache2::Const ':common';
use Proc::ProcessTable;

use strict;
use warnings;

my $table     = Proc::ProcessTable->new;
my $conf_file = Apache::Test::vars->{t_conf};
my $flag =
  grep { /.*apache.*$conf_file/ } map { $_->cmndline } @{ $table->table };

plan
  tests => 4,
  need {
    "Correct apache process must be running." => sub { $flag }
  };

my $response = GET '/';
ok( $response->is_success, '...root directory should return OK.' );

$response = GET '/nonsense/url';
ok( $response->code == NOT_FOUND, "...doesn't find a non-existing url." );

$response = GET '/?node_id=1';
ok( $response->is_success, '...if we ask for node 1, get OK response.' );

# test simple
$response = GET '/node/1';
ok( $response->is_success,
    '...if we ask for node 1 with url schema, get OK response.' );

