#============================================================= -*-perl-*-
#
# t/basic.t
#
# basic test of the operation of the plugin using dbi:ExampleP
# this returns a list of files in the current directory
#
# Written by by Simon Matthews <sam@knowledgepool.com>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# $Id: basic.t,v 1.2 2000/09/20 07:26:07 sam Exp $
#
#========================================================================

use strict;
# use lib qw( ../blib/lib blib/lib);

use Template;

use Cwd;

$| = 1;
my $tests = 2;

my $t = 0;


print "1..$tests\n";


my $dir = cwd();

sub ok ($$) {
    my($n, $ok) = @_;
    ++$t;
    die "sequence error, expected $n but actually $t"
                if $n and $n != $t;
    ($ok) ? print "ok $t\n" : print "not ok $t\n";
    warn "# failed test $t at line ".(caller)[2]."\n" unless $ok;
}


my $proc =<<EOF;
[%- USE DBI('dbi:ExampleP:') -%]
[%- FOREACH entry = DBI.query("select name from $dir") -%]
[%- entry.name %]
[% END -%]
EOF

my $template = new Template;
ok(0, $template);

my $replace = {};
my $out = '';

$replace->{ dir } = $dir;

$template->process(\$proc, $replace, \$out) || die "Failed:" . $template->error();

chomp($out);
# print STDERR "template output [$out]\n";

opendir DIR, $dir;
my @files = readdir DIR;
closedir DIR;

my $dirfiles = join("\n", @files) . "\n";

# print "Dir [$dirfiles]\n";

ok(0, $out eq $dirfiles);
