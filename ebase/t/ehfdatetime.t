#!/usr/bin/perl -w

use strict;

BEGIN {
    chdir 't' if -d 't';
    unshift @INC, '../blib/lib', 'lib/', '..';
}

package Everything::HTML::FormObject::Datetime;
use vars qw( $DB );

package main;

use vars qw( $AUTOLOAD );
use Test::More tests => 76;
use Test::MockObject;

my $package = 'Everything::HTML::FormObject::Datetime';

{
    my @imports;
    my @modules = ( 'Everything', 'Everything::HTML::FormObject' );

    for (@modules) {
        Test::MockObject->fake_module( $_,
          import => sub { push @imports, $_[0] } );
    }

    use_ok($package);

    for ( 0 .. $#modules ) {
        is( $imports[$_], $modules[$_], "Module should use $modules[$_]" );
    }
}

# doubleDigit()
{
    is( ${ [ doubleDigit(2) ] }[0], '02',
      'doubleDigit() should make one-digit numbers two-digit' );
    is( ${ [ doubleDigit(12) ] }[0], '12',
      '... should leave two-digit numbers two-digit' );
    is( scalar doubleDigit( 1, 2, 3 ), 3,
      '... should process entire lists of numbers' );
}

# makeDatetimeMenu()
{
    my $qmock = Test::MockObject->new();
    $qmock->set_always( 'popup_menu', 'pop' );

    my $result = makeDatetimeMenu( $qmock, 'prefix', '1111-2-3 4:7' );
    my ( $method, $args ) = $qmock->next_call;
    shift @$args;
    my %hash = @$args;
    is( $method, 'popup_menu', 'makeDatetimeMenu() should call popup_menu' );
    is( $hash{ -name }, 'prefix_month',
      '... setting -name to prefixed "month"' );
    is( ${ $hash{ -values } }[0], '01',
      '... setting -values to doubled 1 ...' );
    is( ${ $hash{ -values } }[11], 12,
      '... through 12 for the possible months' );
    is(
      scalar keys %{ $hash{ -labels } }, 12,
      '... passing -labels for each of them'
    );
    is( $hash{ -default }, '02', '... setting -default to the doubled month' );

    ( $method, $args ) = $qmock->next_call;
    shift @$args;
    %hash = @$args;
    is( $method, 'popup_menu', '... should call popup_menu a second time' );
    is( $hash{ -name }, 'prefix_day', '... setting -name to prefixed "day"' );
    is( ${ $hash{ -values } }[0], '01',
      '... setting -values to doubled 1 ...' );
    is( ${ $hash{ -values } }[30], 31,
      '... through 31 for the possible dates' );
    is( $hash{ -default }, '03', '... setting -default to the doubled day' );

    ( $method, $args ) = $qmock->next_call;
    shift @$args;
    %hash = @$args;
    is( $method, 'popup_menu', '... should call popup_menu a third time' );
    is( $hash{ -name }, 'prefix_year', '... setting -name to prefixed "year"' );
    ok( scalar @{ $hash{ -values } } > 1,
      '... setting -values to an array of possible years' );
    is( $hash{ -default }, 1111, '... setting -default to the year' );

    ( $method, $args ) = $qmock->next_call;
    shift @$args;
    %hash = @$args;
    is( $method, 'popup_menu', '... should call popup_menu a fourth time' );
    is( $hash{ -name }, 'prefix_hour', '... setting -name to prefixed "hour"' );
    is( ${ $hash{ -values } }[0], '00',
      '... setting -values to doubled 0 ...' );
    is( ${ $hash{ -values } }[23], 23,
      '... through 23 for the possible hours' );
    is( $hash{ -default }, '04', '... setting -default to the doubled hour' );

    ( $method, $args ) = $qmock->next_call;
    shift @$args;
    %hash = @$args;
    is( $method, 'popup_menu', '... should call popup_menu a fifth time' );
    is( $hash{ -name }, 'prefix_minute',
      '... setting -name to prefixed "minute"' );
    is( ${ $hash{ -values } }[0], '00',
      '... setting -values to doubled 0 ...' );
    is( ${ $hash{ -values } }[11], 55,
      '... through 55 for the mins. that are multiples of 5' );
    is( $hash{ -default }, '05',
      '... setting -default to the doubled, rounded-down minute' );

    is( $result, 'poppoppop at poppop',
      '... should return concantated popup_menu() calls' );
}

# paramToDatetime()
{
    my $qmock = Test::MockObject->new;
    $qmock->set_series( 'param', 1111, 22, 33, 44, 55 );

    my $result = paramToDatetime( $qmock, 'prefix' );
    my ( $method, $args ) = $qmock->next_call;
    is( $method, 'param', 'paramToDatetime() should call param()' );
    is( join ( ' ', @$args ), "$qmock prefix_year",
      '... passing it one arg (prefixed "year")' );

    ( $method, $args ) = $qmock->next_call;
    is( $method, 'param', '... should call param() a second time' );
    is( join ( ' ', @$args ), "$qmock prefix_month",
      '... passing it one arg (prefixed "month")' );

    ( $method, $args ) = $qmock->next_call;
    is( $method, 'param', '... should call param() a third time' );
    is( join ( ' ', @$args ), "$qmock prefix_day",
      '... passing it one arg (prefixed "day")' );

    ( $method, $args ) = $qmock->next_call;
    is( $method, 'param', '... should call param() a fourth time' );
    is( join ( ' ', @$args ), "$qmock prefix_hour",
      '... passing it one arg (prefixed "hour")' );

    ( $method, $args ) = $qmock->next_call;
    is( $method, 'param', '... should call param() a fifth time' );
    is( join ( ' ', @$args ), "$qmock prefix_minute",
      '... passing it one arg (prefixed "minute")' );

    is( $result, '1111-22-33 44:55:00',
      '... should return correctly fomatted datetime' );

    $qmock->set_series( 'param', 111, 22, 33, 44, 55 );
    $result = paramToDatetime( $qmock, 'prefix' );
    is( $result, '0000-00-00 00:00:00',
      '... should return "0000-00-00 00:00:00" if bad year format' );

    $qmock->set_series( 'param', 1111, 2, 33, 44, 55 );
    $result = paramToDatetime( $qmock, 'prefix' );
    is( $result, '0000-00-00 00:00:00', '... or if bad month format' );

    $qmock->set_series( 'param', 1111, 22, 3, 44, 55 );
    $result = paramToDatetime( $qmock, 'prefix' );
    is( $result, '0000-00-00 00:00:00', '... or if bad day format' );

    $qmock->set_series( 'param', 1111, 22, 33, 4, 55 );
    $result = paramToDatetime( $qmock, 'prefix' );
    is( $result, '0000-00-00 00:00:00', '... or if bad hour format' );

    $qmock->set_series( 'param', 1111, 22, 33, 44, 5 );
    $result = paramToDatetime( $qmock, 'prefix' );
    is( $result, '0000-00-00 00:00:00', '... or if bad minute format' );
}

# genObject()
{
    my $mock = Test::MockObject->new;

    my ( %gpa, @gpa, @mDM );
    $mock->fake_module(
      $package,
      getParamArray    => sub { push @gpa, \@_; return @gpa{qw( q bn f n d )} },
      makeDatetimeMenu => sub { push @mDM, \@_; return 'html2' }
    );

    my @go;
    $mock->fake_module( 'Everything::HTML::FormObject',
      genObject => sub { push @go, \@_; return 'html1' } );

    my $db = Test::MockObject->new;
    $db->set_always( 'sqlSelect', 'sql' );
    $Everything::HTML::FormObject::Datetime::DB = $db;

    $mock->{field} = '1234';
    @gpa{qw( q bn f n d )} = ( 'query', $mock, 'field', 'name', 'def1234' );
    my $result = genObject( $mock, 1, 2, 3 );
    is( @gpa, 1, 'genObject() should call getParamArray' );
    is( $gpa[0][0], 'query, bindNode, field, name, default',
      '... requesting the appropriate arguments' );
    like( join ( ' ', @{ $gpa[0] } ), qr/1 2 3$/,
      '... with the method arguments' );
    unlike( join ( ' ', @{ $gpa[0] } ), qr/$mock/,
      '... but not the object itself' );

    is( @go, 1, '... should call SUPER::genObject()' );
    is( join ( ' ', @{ $go[0] } ), "$mock query $mock field name",
      '... passing four args ($query, $bindNode, $field, $name)' );

    is( @mDM, 1, '... should call makeDatetimeMenu()' );
    is( @{ $mDM[0] }, 3, '... passing three args' );
    is( ${ $mDM[0] }[0], 'query', '... $query' );
    is( ${ $mDM[0] }[1], 'name',  '... $name' );
    is( ${ $mDM[0] }[2], 1234, '... and $date ($bindNode->{$field})' );

    $mock->{field} = '0000';
    $gpa{n} = '';
    genObject($mock);
    is( ${ $mDM[1] }[1], 'field',
      '... should set $name to $field if not defined' );
    is( ${ $mDM[1] }[2], 'def1234',
      '... should set $date to $default if $bindNode bad' );

    $mock->{field} = '';
    genObject($mock);
    is( ${ $mDM[2] }[2], 'def1234',
      '... and to $default if no $bindNode->{$field}' );

    $gpa{bn} = 'bindNode';
    genObject($mock);
    is( ${ $mDM[3] }[2], 'def1234',
      '... and to $default if $bindNode is not object' );

    $gpa{d} = 'def0000';
    genObject($mock);
    is( ${ $mDM[4] }[2], 'sql',
      '... and to the $DB->sqlSelect() call if $default is bad' );
    is(
      join ( ' ', $db->call_args(-1) ), "$db now()",
      '... passing "now()" to it'
    );

    $gpa{d} = '';
    genObject($mock);
    is( ${ $mDM[5] }[2], 'sql',
      '... and to the $DB->sqlSelect() call if no $default' );

    is( $result, "html1\nhtml2",
      '... should return parent object plus new menu html' );
}

# cgiUpdate()
{
    my $mock = Test::MockObject->new();

    my @pTD = ();
    $mock->fake_module( $package,
      paramToDatetime => sub { push @pTD, join ' ', @_ } );

    $mock->set_always( 'getBindField', 'field' );

    my $qmock = Test::MockObject->new();
    my $nmock = Test::MockObject->new();
    $nmock->set_series( 'verifyFieldUpdate', 0, 1, 0 );

    my @results;
    push @results, cgiUpdate( $mock, $qmock, 'name', $nmock, 0 );
    is( scalar @pTD, 1, 'cgiUpdate() should call paramToDatetime' );
    is( $pTD[0], "$qmock name", '... passing two args ($query, $name)' );

    my ( $method, $args ) = $mock->next_call();
    is( $method, 'getBindField', '... should call getBindField' );
    is( "@$args", "$mock $qmock name", '... passing two args ($query, $name)' );

    ( $method, $args ) = $nmock->next_call();
    is( $method, 'verifyFieldUpdate',
      '... should check verifyFieldUpdate if not $overrideVerify' );
    is( "@$args", "$nmock field", '... passing it one arg ($field)' );

    push @results, cgiUpdate( $mock, $qmock, 'name', $nmock, 0 );
    push @results, cgiUpdate( $mock, $qmock, 'name', $nmock, 1 );

    ok( !$results[0], '... should return false when verify is off' );
    ok( $results[1], '... should return true if $NODE->verifyFieldUpdate' );
    ok( $results[2], '... should return true if $overrideVerify' );
}

sub AUTOLOAD {
    my ($subname) = $AUTOLOAD =~ /([^:]+)$/;

    if ( my $sub = UNIVERSAL::can( $package, $subname ) ) {
        $sub->(@_);
    }
    else {
        warn "Cannot call <$subname> in ($package)\n";
    }
}

