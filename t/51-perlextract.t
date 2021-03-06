#! /usr/bin/perl -w
use lib '../lib';
use strict;
use Test::More tests => 297;

use_ok('Locale::Maketext::Extract');
my $Ext = Locale::Maketext::Extract->new();

# Standard Perl parser
my @perl_alias_terms = qw/l _ translate maketext gettext __/;
run_tests('perl - ', \@perl_alias_terms);

SKIP: {
    # PPI parser
    skip( 'PPI unavailable', 43 ) unless eval { require PPI };
    $Ext = Locale::Maketext::Extract->new(
        plugins => { 'Locale::Maketext::Extract::Plugin::PPI' => '*' } );
    my $maketext_aliases = ['_'];
    run_tests('ppi - ', $maketext_aliases);
}

sub run_tests {
    my ($prefix, $alias_terms) = @_;
    isa_ok( $Ext => 'Locale::Maketext::Extract' );
    foreach my $alias ( @$alias_terms ) {
        test_extract_on_alias($alias, $prefix);
    }
}

sub test_extract_on_alias {
    my ($alias, $prefix) = @_;
    #### BEGIN PERL TESTS ############
    extract_ok( $alias.'("123")' => 123, $prefix . 'Simple extraction' );
    
    extract_ok( $alias.'("[_1] is happy")' => '%1 is happy',
                $prefix . '[_1] to %1' );
    extract_ok( $alias.'("%1 is happy")' => '%1 is happy',
                $prefix . '%1 verbatim', 1 );

    extract_ok( $alias.'("[*,_1] counts")' => '%*(%1) counts',
                $prefix . '[*,_1] to %*(%1)' );
    extract_ok( $alias.'("%*(%1) counts")' => '%*(%1) counts',
                $prefix . '%*(%1) verbatim', 1 );

    extract_ok( $alias.'("[*,_1,_2] counts")' => '%*(%1,%2) counts',
                $prefix . '[*,_1,_2] to %*(%1,%2)' );
    extract_ok( $alias.'("[*,_1,_2] counts")' => '[*,_1,_2] counts',
                $prefix . '[*,_1,_2] verbatim', 1 );
    extract_ok( $alias.q(('foo\$bar')) => 'foo\\$bar',
                $prefix . 'Escaped \$ in q' );
    extract_ok( $alias.q(("foo\$bar")) => 'foo$bar',
                $prefix . 'Normalized \$ in qq' );

    extract_ok( $alias.q(('foo\x20bar')) => 'foo\\x20bar',
                $prefix . 'Escaped \x in q' );
    extract_ok( $alias.q(("foo\x20bar")) => 'foo bar',
                $prefix . 'Normalized \x in qq' );

    extract_ok( $alias.q(('foo\nbar')) => 'foo\\nbar',
                $prefix . 'Escaped \n in qq' );
    extract_ok( $alias.q(("foo\nbar")) => "foo\nbar",
                $prefix . 'Normalized \n in qq' );
    extract_ok( $alias.qq(("foo\nbar")) => "foo\nbar",
                $prefix . 'Normalized literal \n in qq' );

    extract_ok( $alias.q(("foo\nbar")) => "foo\nbar",
                $prefix . 'Trailing \n in qq' );
    extract_ok( $alias.qq(("foobar\n")) => "foobar\n",
                $prefix . 'Trailing literal \n in qq' );

    extract_ok( $alias.q(('foo\bar')) => 'foo\\bar', $prefix . 'Escaped \ in q' );
    extract_ok( $alias.q(('foo\\\\bar')) => 'foo\\bar',
                $prefix . 'Normalized \\\\ in q' );
    extract_ok( $alias.q(("foo\bar")) => "foo\bar",
                $prefix . 'Interpolated \b in qq' );

    extract_ok( q([% loc( 'foo "bar" baz' ) %]) => 'foo "bar" baz',
                $prefix . 'Escaped double quote in text' );

    extract_ok( $alias.q((q{foo bar})) => "foo bar",  $prefix . 'No escapes' );
    extract_ok( $alias.q((q{foo\bar}))  => 'foo\\bar', $prefix . 'Escaped \ in q' );
    extract_ok( $alias.q((q{foo\\\\bar})) => 'foo\\bar',
                $prefix . 'Normalized \\\\ in q' );
    extract_ok( $alias.q((qq{foo\bar})) => "foo\bar",
                $prefix . 'Interpolated \b in qq' );
    
    
    extract_ok( q(my $x = ).$alias.q(('I "think" you\'re a cow.') . "\n";) =>
                    'I "think" you\'re a cow.',
                $prefix . "Handle escaped single quotes"
    );
    extract_ok( q(my $x = ).$alias.q(("I'll poke you like a \"cow\" man.") . "\n";) =>
                    'I\'ll poke you like a "cow" man.',
                $prefix . "Handle escaped double quotes"
    );

    extract_ok( $alias.q(("","car")) => '', $prefix . 'ignore empty string' );
    extract_ok( $alias.q(("0"))      => '', $prefix . 'ignore zero' );

    extract_ok( <<'__EXAMPLE__' => "123\n", "Simple extraction (heredoc)" );
_(<<__LOC__);
123
__LOC__
__EXAMPLE__

    extract_ok(
        <<'__EXAMPLE__' => "foo\\\$bar\\\'baz\n", "No escaped of \$ and \' in singlequoted terminator (heredoc)" );
_(<<'__LOC__');
foo\$bar\'baz
__LOC__
__EXAMPLE__

    extract_ok(
        <<'__EXAMPLE__' => "foo\$bar\n", "Normalized \$ in doublequoted terminator (heredoc)" );
_(<<"__LOC__");
foo\$bar
__LOC__
__EXAMPLE__

    extract_ok( <<'__EXAMPLE__' => "foo\nbar\n", "multilines (heredoc)" );
_(<<__LOC__);
foo
bar
__LOC__
__EXAMPLE__

    extract_ok( <<'__EXAMPLE__' => "example\n", "null identifier (heredoc)" );
_(<<"");
example

__EXAMPLE__

    extract_ok(
        <<'__EXAMPLE__' => "example\n", "end() after the heredoc (heredoc)" );
_(<<__LOC__
example
__LOC__
);
__EXAMPLE__

    write_po_ok(
        <<'__EXAMPLE__' => <<'__EXPECTED__', "null identifier with end after the heredoc (heredoc)" );
_(<<""
example

);
__EXAMPLE__
#: :1
msgid "example\n"
msgstr ""
__EXPECTED__

    write_po_ok(
         <<'__EXAMPLE__' => <<'__EXPECTED__', "q with multilines with args" );
_(q{example %1
with multilines
},20);
__EXAMPLE__
#. (20)
#: :1
msgid ""
"example %1\n"
"with multilines\n"
msgstr ""
__EXPECTED__

    write_po_ok(
        <<'__EXAMPLE__' => <<'__EXPECTED__', "null terminator with multilines with args (heredoc)" );
_(<<"", 15)
example %1
with multilines

__EXAMPLE__
#. (15)
#: :1
msgid ""
"example %1\n"
"with multilines\n"
msgstr ""
__EXPECTED__

    write_po_ok(
        <<'__EXAMPLE__' => <<'__EXPECTED__', "null terminator with end after the heredoc with args (heredoc)" );
_(<<"", 10)
example %1

__EXAMPLE__
#. (10)
#: :1
msgid "example %1\n"
msgstr ""
__EXPECTED__

    write_po_ok(
             <<'__EXAMPLE__' => <<'__EXPECTED__', "two _() calls (heredoc)" );
_(<<"", 10)
example1 %1

_(<<"", 5)
example2 %1

__EXAMPLE__
#. (10)
#: :1
msgid "example1 %1\n"
msgstr ""

#. (5)
#: :4
msgid "example2 %1\n"
msgstr ""
__EXPECTED__

    write_po_ok( <<'__EXAMPLE__' => <<'__EXPECTED__', "concat (heredoc)" );
_('exam'.<<"", 10)
ple1 %1

__EXAMPLE__
#. (10)
#: :1
msgid "example1 %1\n"
msgstr ""
__EXPECTED__

    write_po_ok(
        <<'__EXAMPLE__' => <<'__EXPECTED__', "two _() calls with concat over multiline (heredoc)" );
_('example' .
<<"", 10)
1 %1

_(<<"", 5)
example2 %1

__EXAMPLE__
#. (10)
#: :1
msgid "example1 %1\n"
msgstr ""

#. (5)
#: :5
msgid "example2 %1\n"
msgstr ""
__EXPECTED__

    write_po_ok(
             <<'__EXAMPLE__' => <<'__EXPECTED__', "i can concat the world!" );
_(
'\$foo'
."\$bar"
.<<''
\$baz

)
__EXAMPLE__
#: :2
msgid "\\$foo$bar\\$baz\n"
msgstr ""
__EXPECTED__

    #### END PERL TESTS ############

}

sub extract_ok {
    my ( $text, $expected, $info, $verbatim ) = @_;
    $Ext->extract( '' => $text );
    $Ext->compile($verbatim);
    my $result = join( '', %{ $Ext->lexicon } );
    is( $result, $expected, $info );
    $Ext->clear;
}

sub write_po_ok {
    my ( $text, $expected, $info, $verbatim ) = @_;
    my $po_file = 't/5-extract.po';

    # create .po
    $Ext->extract( '' => $text );
    $Ext->compile($verbatim);
    $Ext->write_po($po_file);

    # read .po
    open( my $po_handle, '<', $po_file ) or die("Cannot open $po_file: $!");
    local $/ = undef;
    my $result = <$po_handle>;
    close($po_handle);
    unlink($po_file) or die("Cannot unlink $po_file: $!");

    # cut the header from result
    my $start_expected = length( $Ext->header );
    $start_expected++ if ( $start_expected < length($result) );

    # check result vs expected
    is( substr( $result, $start_expected ), $expected, $info );
    $Ext->clear;
}
