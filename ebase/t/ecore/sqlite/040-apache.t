
# BEGIN {
#     require 'Test/More.pm';
#     if ( !-e 't/conf/httpd.conf' ) {
#         Test::More->import(
#             skip_all => 'Needs proper apache configuration to run.' );
#     }
# }

use Apache::Test '-withtestmore';
use Apache::TestRequest qw(GET);
use Apache::TestUtil;
use File::Temp;
use File::Copy;
use Apache2::Const ':common';
use IO::File;

use lib 't/lib';
use DBTestUtil qw(config_file nodebase);
use Proc::ProcessTable;

use strict;
use warnings;

### write t/conf/extra.conf.in

my $config_file = '../' . config_file();


my $temp_file = File::Temp->new( CLEANUP => 1 );

print $temp_file "GGGGGGGGGGGGG ";

copy ( config_file(), "$temp_file" );

my $nb = nodebase();

my $fh = IO::File->new( 't/conf/extra.conf.in', 'w' );

print $fh <<APACHECONF;
<Perl>
use lib '\@SERVERROOT\@/../lib';
</Perl>

SetHandler perl-script
PerlSetVar everything-config-file $config_file
PerlResponseHandler +Everything::HTTP::Apache
PerlAddVar everything-config-file $temp_file

<Location /images>
        SetHandler default-handler
</Location>

APACHECONF

$fh->close;

### start apache server

system ( 't/TEST', '-clean' );
system ( 't/TEST', '-start-httpd' );

### grab a copy of the same nodebase apache is using

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

