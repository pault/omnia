package Everything::Node::Test::Parseable;


use base 'Test::Class';
use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::Exception;
use Scalar::Util 'blessed';
use SUPER;

use strict;

{
    package Node::Parseable;

    use Moose;
    with 'Everything::Node::Parseable';
}


sub startup_parseable : Test(startup) {
    my $self = shift;
    $self->{class} = 'Node::Parseable';
    $self->{instance} = $self->{class}->new;
}


sub test_do_args : Test(2) {

    my $self = shift;
    can_ok( $self->{class}, 'do_args' ) || return;
    my $arg             = "first, sec ond   ,third";
    my $expected_result = [ q{'first'}, q{'sec ond'}, q{'third'} ];
    my $do_args         = \&{ $self->{class} . '::do_args' };
    is_deeply( [ $do_args->($arg) ],
        $expected_result,
        'do_args turns comma-delimited  arguments into an array' );

}

sub test_createAnonSub : Test(2) {

    my $self = shift;
    can_ok( $self->{class}, 'createAnonSub' ) || return;
    my $arg = "some random data";
    like( $self->{instance}->createAnonSub($arg),
        qr/^\s*sub\s*\{\s*$arg\s*\}/s, 'createAnonSub wraps args in sub{}' );

}

sub test_parse : Test(20) {
    my $self = shift;

    my $test_suite = htmlcode_hash();
    foreach ( keys %$test_suite ) {

        $self->{instance}->{title} = 'Fake Node';
	$self->{instance}->{node_id} = 222;
        $self->{instance}->{code} = $test_suite->{$_}->{input};
        my $rv        = $self->{instance}->parse($self->{instance}->{code});
        my $main_code = $test_suite->{$_}->{output};
        like( $rv, $main_code, "Should wrap $_ code in the right way." );

        ## We also need to test the wrap code:
        my $start_wrap = qr/^\s*my\s+\$result;\s+\$result\s*\.=\s*/s;
        like( $rv, $start_wrap, 'Should start the eval block properly' );

        my $error_code = qr//;

        unless ( $_ eq 'TEXT' ) {

            $error_code =
qr/\s*Everything::logErrors\('',\s+ \$@,\s+ '',\s+ \{\s+ title\s+ =>\s* 'Fake\\\sNode',\s+node_id\s+ =>\s+ '222'\s+ \}\)\s*if\s+\(\$@\);
/sx;
        }
        my $final_code = qr/\s+return\s+\$result\s*;\s*$/sx;
        like( $rv, qr/$error_code$final_code/,
            'Should end the eval block properly' );
        like(
            $rv,
            qr/$start_wrap$main_code$error_code$final_code/,
            'The whole lot'
        );
    }

}

sub htmlcode_hash {
    {
        TEXT => {
            input  => q/Some "text" <html> text's stuff/,
            output => qr/'Some "text" <html> text\\'s stuff'\s*;/s

        },

        HTMLCODE => {
            input  => q/[{anhtmlcodething:   one, two  ,three  }]/,
            output =>
qr/\s*eval\s*\{\s*\$this->anhtmlcodething\s*\(\s*'one'\s*,\s*'two'\s*,\s*'three'\s*\)\s+\}\s+\|\|\s+''\s*;/s

        },

        PERL1 => {
            input  => q/[% do { "$stuff" = %thing{3} } while ($x == 2) %]/,
            output =>
qr/\s*eval\s*\{\s* do \{ "\$stuff" = %thing\{3\} \} while \(\$x == 2\)\s*\}\s+\|\|\s+''\s*;/s
        },

        PERL2 => {
            input  => q/[" do { $stuff = "%thing{3}" } while ($x == 2) "]/,
            output =>
qr/\s*eval\s*\{\s* do \{ \$stuff = "%thing\{3\}" \} while \(\$x == 2\)\s*\}\s+\|\|\s+''\s*;/s
        },

### Note the html code does not allow spaced between < and the name of
### the htmlsnippet
        HTMLSNIPPET => {
            input  => q/[<htmlsnippettext>]/,
            output =>
qr/eval\s*\{\s*\$this->htmlsnippet\s*\(\s*'htmlsnippettext'\s*\)\s*\}\s+\|\|\s+''\s*;/s

        },
    }

}

sub test_make_eval_text : Test(2) {
    return 'unimplemented';
    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};
    can_ok( $class, 'make_eval_text' ) || return;
    my $make_eval_text = \&{ $class . '::make_eval_text' };
    my $tokens = [ [ PERL => 'one' ], [ TEXT => 'two' ], [ TEXT => 'three' ] ];
    is(
        $make_eval_text->($tokens), 'my $result;

$result .= one

$result .= two

$result .= three

return $result;', 'Making up the eval text'
    );

}

# tokenise - does it tokenise properly
sub test_tokenise : Test(13) {
    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};
    can_ok( $class, 'tokenise' ) || return "Can't tokenise";
    my $tokenise = \&{ $class . '::tokenise' };
    my @input    = discrete_snippets();

    my $tokens = [];
    foreach (@input) {
        my $result = $tokenise->($_);
        push @$tokens, @$result;
    }
    is(
        $tokens->[0]->[1],
        'ahtmlcodebit:one, two   , three  ',
        "Tokenise a single expression"
    );
    is( $tokens->[1]->[1], ' $pure @perl',    "Tokenise a single expression" );
    is( $tokens->[2]->[1], ' $pure @perl',    "Tokenise a single expression" );
    is( $tokens->[3]->[1], 'somehtmlsnippet', "Tokenise a single expression" );
    is( $tokens->[4]->[1], q{random's text"!$},
        "Tokenise a single expression" );

    my $input = trial_text();
    ok( $tokens = $tokenise->($input), "Run tokenise" );

    is( $tokens->[0]->[1], '<some text> ',       "Tokenising a block of text" );
    is( $tokens->[1]->[1], 'htmlcode:one',       "Tokenising a block of text" );
    is( $tokens->[2]->[1], "\nsome more text ",  "Tokenising a block of text" );
    is( $tokens->[3]->[1], ' &then some @perl ', "Tokenising a block of text" );
    is( $tokens->[4]->[1], " finally\n ",        "Tokenising a block of text" );
    is( $tokens->[5]->[1], 'asnippet',           "Tokenising a block of text" );

}

sub discrete_snippets {

    (
        '[{ahtmlcodebit:one, two   , three  }]',
        '[% $pure @perl%]',
        '[" $pure @perl"]',
        '[<somehtmlsnippet>]',
        q{random's text"!$},
      )

}


sub test_tokens_to_perl : Test(12) {
    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};

    can_ok( $class, 'tokens_to_perl' ) || return;
    my @snippets       = discrete_snippets();
    my $tokenise       = \&{ $class . '::tokenise' };
    my $code_up_tokens = \&{ $class . '::tokens_to_perl' };

    my $tokens = [];
    foreach (@snippets) {
        my $toke;
        ok( $toke = $tokenise->($_) );
        push @$tokens, @$toke;
    }

    $tokens = $code_up_tokens->($tokens, sub {} );
    is( ref $tokens, 'ARRAY', "tokens_to_perl tokens returns an array ref." );
    my @encoded = @$tokens;
    is(
        $encoded[0]->[1],
        q! eval {$this->ahtmlcodebit('one', 'two', 'three') } || '';! . "\n",
        "Encoding HTMLCODE"
    );
    is(
        $encoded[1]->[1],
        qq! eval { \n \$pure \@perl\n} || '';\n!,
        "Encoding PERL"
    );
    is(
        $encoded[2]->[1],
        qq! eval { \n \$pure \@perl\n} || '';\n!,
        "Encoding PERL"
    );
    is(
        $encoded[3]->[1],
        qq! eval {\$this->htmlsnippet('somehtmlsnippet')} || '';\n!,
        "Encoding HTMLSNIPPET"
    );
    is( $encoded[4]->[1], q{ 'random\'s text"!$';}, "Encoding TEXT" );
}

sub test_add_error_text : Test(8) {
    my $self     = shift;
    my $class    = $self->{class};
    my $instance = $self->{instance};

    can_ok( $class, 'add_error_text' ) || return;
    my $add_error_text = \&{ $class . '::add_error_text' };
    my $error_code     =
qr/\s*Everything::logErrors\('',\s+ \$@,\s+ '',\s+ \{\s+ title\s+ =>\s* 'Fake\\\sNode',\s+node_id\s+ =>\s+ '222'\s+ \}\)\s*if\s+\(\$@\);
/sx;
    my $current_node = { title => 'Fake Node', node_id => 222 };
    ### set up our encoded text
    my @snippets = discrete_snippets();

    my $tokenise = \&{ $class . '::tokenise' };
    my @tokens   = ();
    foreach (@snippets) {
        my $toke;
        ok( $toke = $tokenise->($_) );
        push @tokens, @$toke;
    }

    my $code_up_tokens = \&{ $class . '::tokens_to_perl' };
    my $encoded_tokens = $code_up_tokens->( \@tokens );
    is( ref $encoded_tokens, 'ARRAY', "Code up tokens returns an array ref." );
    my $error_text = $add_error_text->( $current_node );
    like( $error_text, qr/Everything::logErrors/, "Add error text works" );

}

sub trial_text {

    q/<some text> [{htmlcode:one}]
some more text [% &then some @perl %] finally
 [<asnippet>] and Title:[{morehtmlcode}]/

}

1;

