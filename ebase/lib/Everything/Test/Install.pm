package Everything::Test::Install;

use File::Spec;
use File::Temp qw/tempdir tempfile/;
use File::Path;
use File::Copy;
use IO::File;
use Test::More;

use base 'Everything::Test::Abstract';
use strict;
use warnings;

sub setup : Test(setup) {
    my $self = shift;
    $self->{instance} = $self->{class}->new;

}

sub test_check_everything_dir : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'check_everything_dir' ) || return;
    my $temp = tempdir( CLEANUP => 1 );
    ok(
        !$self->{instance}->check_everything_dir($temp),
        '...returns false if cannot verify directory.'
    );
    mkpath(
        [ map { File::Spec->catfile( $temp, $_ ) } qw/nodeballs web images/ ] );
    ok( $self->{instance}->check_everything_dir($temp),
        '...returns true if it can.' );
}

sub test_amend_template : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'amend_template' ) || return;
    my ( $fh, $template ) = tempfile( UNLINK => 1 );
    print $fh 'This is a [% one %] this is a [% two %]';

    seek $fh, 0, 0;

    my ( $fh1, $outfile ) = tempfile( UNLINK => 1 );

    $self->{instance}
      ->amend_template( { one => 'big', two => 'small' }, $template, $outfile );

    seek $fh1, 0, 0;

    local $/;
    my $text = <$fh1>;
    is( $text, 'This is a big this is a small', '...amends template files.' );
}

sub create_index : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'create_index' ) || return;
    return "Can't find index.in file." unless -e 'web/index.in';
    my $webdir = tempdir( CLEANUP => 1 );
    my $user = $ENV{USER};

    $self->{instance}->create_index(
        {
            edir     => '.',
            webdir   => $webdir,
            owner    => $user,
            group    => $user,
            database => 'thing',
            user     => 'duh',
            password => 'duh',
            type     => 'duh'
        }
    );

    my $fh = IO::File->new( "$webdir/index.pl", 'r' );

    local $/;

    my $index = <$fh>;

    like(
        $index, qr/
my \$dbname   = \$ENV{EVERYTHING_DBNAME}   ||= 'thing';
my \$dbtype   = \$ENV{EVERYTHING_DBTYPE}   ||= 'duh';
my \$user     = \$ENV{EVERYTHING_USER}     ||= 'duh';
my \$password = \$ENV{EVERYTHING_PASSWORD} ||= 'duh';
my \$host     = \$ENV{EVERYTHING_HOST}     ||= '';
/, '...creates the index file.'
    );

}

sub test_create_apache_cgi_conf : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'create_apache_cgi_conf' ) || return;
    return "Can't find everything-apache-cgi.conf.in file."
      unless -e 'web/everything-apache-cgi.conf.in';

    my $edir = tempdir( CLEANUP => 1 );
    my $webdir = 'blahblah';

    mkdir "$edir/web";
    copy( 'web/everything-apache-cgi.conf.in', "$edir/web/everything-apache-cgi.conf.in" );

    my $rv = $self->{instance}->create_apache_cgi_conf( $edir, $webdir );

    my $fh = IO::File->new( "$edir/web/everything-apache-cgi.conf", 'r' );

    local $/;

    my $conf = <$fh>;

    like( $conf, qr/<Directory blahblah>/, '...creates the apache conf file.' );

    is( $rv, "$edir/web/everything-apache-cgi.conf",
        '...returns the name of the conf file.' );
}

sub test_create_apache_handler_conf : Test(4) {
    my $self = shift;
    can_ok( $self->{class}, 'create_apache_handler_conf' ) || return;
    return "Can't find everything-apache-handler.conf.in file."
      unless -e 'web/everything-apache-cgi.conf.in';

    my $edir = tempdir( CLEANUP => 1 );
    mkdir "$edir/web";
    copy( 'web/everything-apache-handler.conf.in', "$edir/web/everything-apache-handler.conf.in" );

    my $options = {
        edir     => $edir,
        database => 'thing',
        user     => 'duh',
        password => 'duh',
        type     => 'duh'
    };

    my $rv = $self->{instance}->create_apache_handler_conf($options);

    is(
        $rv,
        "$edir/web/everything-apache-handler.conf",
        '...creates apache configuraton file.'
    );

    my $fh = IO::File->new( "$edir/web/everything-apache-handler.conf", 'r' );

    local $/;

    my $conf = <$fh>;

    $fh->close;

    like(
        $conf, qr/
        PerlSetVar everything-database thing
        PerlSetVar everything-database-user duh
        PerlSetVar everything-database-password duh
        PerlSetVar everything-database-host 
        PerlSetVar everything-database-options dbtype
        PerlAddVar everything-database-options duh
        PerlAddVar everything-database-options authtype
        PerlAddVar everything-database-options 
        SetHandler perl-script
        PerlResponseHandler \+Everything::HTTP::Apache
/s,
        '...creates the apache conf file.'
    );

    # test location directive
    $options->{location} = 'blahblah';
    $self->{instance}->create_apache_handler_conf($options);

    $fh = IO::File->new( "$edir/web/everything-apache-handler.conf", 'r' );

    local $/;

    $conf = <$fh>;

    like(
        $conf,
        qr/<Location blahblah>.*database thing.*<\/Location>/s,
        '...sets the location directive.'
    );
}

sub test_create_storage : Test(2) {

}

sub test_create_nodebase : Test(1) {

}

sub test_install_base_nodes : Test(3) {

}

sub test_install_sql_tables : Test(1) {

}

sub test_install_nodetypes : Test(1) {

}

sub test_install_nodes : Test(1) {

}

1;
