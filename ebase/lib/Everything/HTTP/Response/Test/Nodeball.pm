package Everything::HTTP::Response::Test::Nodeball;

use base 'Everything::Test::Abstract';
use Test::MockObject;
use Test::More;
use IO::File;
use SUPER;
use strict;
use warnings;

sub startup : Test(startup => +0) {

    my $self = shift;
    my $class = $self->module_class;

    Test::MockObject->fake_module(
        'Apache2::Const',
        import => sub {
            no strict 'refs';
            *{ $class . '::OK' }        = sub { 'ok status code' };
            *{ $class . '::FORBIDDEN' } = sub { 'forbidden status code' };
            use strict 'refs';
        }
    );

    $self->SUPER;

}

sub setup :Test(setup) {
    my $self = shift;
    my $mock = Test::MockObject->new;
    $mock->set_always( get_user => $mock );
    $mock->set_always( get_node => $mock );
    $mock->set_true(qw/hasAccess/);
    $self->{ mock } = $mock;
    $self->{instance} = $self->{class}->new( { request => $mock } );

}

sub test_status_code : Test(2) {
    my $self = shift;
    my $i = $self->{instance};
    $i->allowed( 1 );
    is ( $i->status_code, 'ok status code', '...returns OK if download allowed.');
    $i->allowed( 0 );
    is ( $i->status_code, 'forbidden status code', '...returns FORBIDDEN if download allowed.');

}

sub test_content : Test(3) {
    my $self = shift;

    my $mock = $self->{ mock };
    $mock->set_always( get_request => $mock );
    $mock->set_always( get_nodebase => $mock );
    $mock->set_always( get_node => $mock );
    $mock->set_always( get_title => 'a nodeball title' );

    my @args = ();

    local *Everything::Storage::Nodeball::export_nodeball_to_file;
    *Everything::Storage::Nodeball::export_nodeball_to_file = sub {
        push @args, @_;
        my $file = $_[2];
        my $fh = IO::File->new( $file, 'w' );
        print $fh "nodeball contents";
        return 1;
    };

    my $i = $self->{ instance };
    $i->allowed( 1 );

    is( my $rv = $i->content, 'nodeball contents', '... returns contents written to file.' );
    is ( $args[1], 'a nodeball title', '...title of a nodeball.' );
    my %headers = $i->headers;
    is_deeply( \%headers, { 'Content-Disposition' => 'attachment; filename=a-nodeball-title.nbz' }, '...sets the Content-Disposition header' );
}

sub  test_headers :Test(2) {

    my $self = shift;
    my $i = $self->{instance};
    my %headers = $i->headers;
    is_deeply( \%headers, {}, '...returns an empty list when initialised.' );

    $i->add_header( Foo => 'Bar' );
    %headers = $i->headers;
    is_deeply( \%headers, { Foo => 'Bar' }, '...returns one header when added.' );


}

1;
