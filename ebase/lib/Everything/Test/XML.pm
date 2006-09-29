package Everything::Test::XML;

use strict;
use Test::More;
use Test::MockObject;
use SUPER;

use base 'Everything::Test::Abstract';

sub startup : Test(startup => +0) {
    my $self = shift;
    my $mock = Test::MockObject->new;

    $self->{le} = [];
    $mock->fake_module( 'Everything',
        logErrors => sub { push @{ $self->{le} }, [@_] } );
    $mock->fake_module('XML::DOM');

    $self->SUPER;
    $self->{mock} = $mock;

}

sub test_readtag : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'readTag' );

}

sub test_initXMLParser : Test(2) {
    my $self    = shift;
    my $package = $self->{class};

    can_ok( $package, 'initXMLParser' );
    my $unfixed = Everything::XML::_unfixed();
    $unfixed->{foo} = 'bar';
    Everything::XML::initXMLParser();
    is( keys( %{ Everything::XML::_unfixed() } ),
        0, 'initXMLParser() should clear unfixed keys' );
}

sub test_fix_nodes : Test(7) {
    my $self    = shift;
    my $package = $self->{class};
    my $mock    = $self->{mock};

    can_ok( $package, 'fixNodes' );

    my ( @gn, @gnret );

    no strict 'refs';
    local *{ __PACKAGE__ . '::fixNodes' };
    *{ __PACKAGE__ . '::fixNodes' } = \&{ $self->{class} . '::fixNodes' };
    local *{ __PACKAGE__ . '::_unfixed' };
    *{ __PACKAGE__ . '::_unfixed' } = \&{ $self->{class} . '::_unfixed' };
    use strict 'refs';

    local *Everything::XML::getNode;
    *Everything::XML::getNode = sub {
        push @gn, [@_];
        return shift @gnret;
    };

    my $unfixed = _unfixed();
    $unfixed->{foo} = 'bar';

    fixNodes(0);
    is( @{ $self->{le} },
        0, 'fixNodes() should log nothing unless error flag is set' );

    fixNodes(1);
    is( @{ $self->{le} }, 1, '... but should log with error flag' );

    @gnret = ($mock) x 4;

    $mock->set_series( applyXMLFix => 1, 0, 1 )->set_true('commitXMLFixes')
      ->clear();
    $unfixed->{foo} = [ 1, 2 ];

    fixNodes('printflag');
    my ( $method, $args ) = $mock->next_call();
    is( $method, 'applyXMLFix', '... calling applyXMLFix() for all unfixed' );
    is( join( '-', @$args ),
        "$mock-1-printflag", '... with fix and print error' );
    is_deeply( $unfixed, { foo => [1] }, '... saving only unfixed nodes' );

    $mock->clear();

    $unfixed = { bar => [] };
    fixNodes('printflag');
    is( $mock->next_call(2), 'commitXMLFixes', '... committing fixes' );

}

sub test_xml2node : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'xml2node' );
}

sub test_xmlfile2node : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'xmlfile2node' );
}

sub test_gen_basic_tag : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'genBasicTag' );
}

sub test_parse_basic_tag : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'parseBasicTag' );
}

sub test_path_xml_where : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'patchXMLwhere' );
}

sub test_make_xml_safe : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'makeXmlSafe' );
}

sub test_unmake_xml_safe : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'unMakeXmlSafe' );
}

sub test_get_field_type : Test(1) {
    my $self    = shift;
    my $package = $self->{class};
    can_ok( $package, 'getFieldType' );
}

1;
