package Everything::HTML::FormObject::Test::Checkbox;

use base 'Everything::HTML::Test::FormObject';
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use CGI;
use SUPER;
use warnings;
use strict;

sub setup_globals {
    my $self = shift;
    $self->SUPER;
    no strict 'refs';
    *{ $self->package_under_test(__PACKAGE__) . '::DB' } = \$self->{mock};
    use strict 'refs';

}

sub test_gen_object : Test(16) {

    my $self     = shift;
    my $instance = $self->{instance};
    my $node     = $self->{node};
    my $cgi      = Test::MockObject->new;
    $cgi->set_always( 'checkbox', 'a' );
    $node->mock( 'genObject' => sub { } );
    local (
        *Everything::HTML::FormObject::Checkbox::getParamArray,
        *Everything::HTML::FormObject::Checkbox::SUPER::genObject
    );

    my @params;
    *Everything::HTML::FormObject::Checkbox::getParamArray = sub {
        push @params, "@_";
        shift;
        @_;
    };

    my ( $sub_name, $arguments );
    $node->fake_module(
        'Everything::HTML::FormObject',
        genObject => sub {
            $sub_name  = 'SUPER::genObject';
            $arguments = [@_];
            return 'html';
        }
    );
    $node->{_subs}{checkbox} = [ 'a', 'b', 'c', 'd', 'e' ];

    my $result =
      $instance->genObject( $cgi, 'bN', 'f', 'n', 'c', 'u', 'd', 'l' );
    is(
        $params[0],
        'query, bindNode, field, name, checked, unchecked, default, label'
          . " $cgi bN f n c u d l",
        'genObject() should call getParamArray() with @_'
    );
    is( $sub_name, 'SUPER::genObject', '... and SUPER::genObject()' );

    $cgi->clear;
    $result = $instance->genObject( $cgi, 'bN', 'f', 'n', 'c', 'u', 'd', 'l' );
    my ( $method, $args ) = $cgi->next_call;
    is( $method, 'checkbox', '... and $q->checkbox()' );

    like( $arguments->[3], qr/^.+:u$/, '... uses provided $unchecked' );
    like( $arguments->[3], qr/^f:.+$/, '... and $field' );
    is( $arguments->[4], 'n', '... and $name' );
    is( $args->[4],      'd', '... and $default' );
    is( $args->[6],      'c', '... and $checked' );
    is( $args->[8],      'l', '... and $label' );
    is( $result, "html\na",
        '... should return concantation of SUPER() and checkbox() calls' );

    ## test no unchecked
    $cgi->clear;

    $instance->genObject( $cgi, 'bindNode', 'field' );

    ( $method, $args ) = $cgi->next_call;
    is( $arguments->[3], 'field:0',
        '... when not provided, $unchecked defaults to 0' );
    is( $args->[6], 1, '... and $checked to 1' );
    is( $args->[4], 0, '... with no $bindNode, $default defaults to 0' );

    ## test field and checked
    $cgi->clear;
    $instance->genObject( $cgi, { f => '1' }, 'f' );
    ( $method, $args ) = $cgi->next_call;
    is( $args->[4], 1,
        '... with $bindNode and $checked eq $$bindNode{$field}, defaults to 1'
    );

    ## test field checked
    $cgi->clear;
    $instance->genObject( $cgi, { f => '0' }, 'f' );
    ( $method, $args ) = $cgi->next_call;
    is( $args->[4], 0,
        '... with $cgi and $checked ne $$bindNode{$field}, defaults to 0' );

    ## test auto
    $cgi->clear;
    $instance->genObject( $cgi, '', '', '', '', '', 'AUTO' );
    ( $method, $args ) = $cgi->next_call;
    is( $args->[4], 0, '... same when provided $default is "AUTO"' );
}

sub test_cgi_update : Test(8) {
    my $self = shift;

    my $instance = Test::MockObject::Extends->new( $self->{instance} );
    $instance->set_always( 'getBindField', 'field' );

    my $node = $self->{node};
    my $cgi  = Test::MockObject->new;

    $cgi->set_always( 'param', 345 );
    $node->set_series( 'verifyFieldUpdate', 1, 0, 0 );
    my @results;

    push @results, $instance->cgiUpdate( $cgi, 'name', $node, 0 );

    my ( $method, $args ) = $cgi->next_call;
    is( $method . $args->[1],
        'paramname', 'cgiUpdate() should call param() with $name' );

    ( $method, $args ) = $instance->next_call;
    is( join( '', $method, @{$args}[ 1 .. 2 ] ),
        "getBindField${cgi}name",
        '... should call getBindField() with $query, $name' );

    ( $method, $args ) = $node->next_call;
    is( join( '', $method, $args->[1] ),
        'verifyFieldUpdatefield',
        '... should call verifyFieldUpdate() with $field' );
    is( $node->{field}, 345,
        '... should set $NODE->{$field} to $value if true' );

    push @results, $instance->cgiUpdate( $cgi, 'name', $node, 1 );
    is( $node->{field}, 345, '... and to $unchecked if not' );

    push @results, $instance->cgiUpdate( $cgi, 'name', $node, 0 );
    is( $results[2], 0, '... should return 0' );
    is( $results[1], 1, '... unless $overrideVerify is true' );
    is( $results[0], 1, '... or $NODE->verifyFieldUpdate($field) is true' );

}

1;
