#============================================================= -*-perl-*-
#
# t/nested.t
#
# Test script testing nested queries.
#
# Written by Simon Matthews <sam@knowledgepool.com>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# $Id: nested.t,v 1.4 2000/09/20 07:31:16 sam Exp $
#
#========================================================================

use strict;
use DBI;
use lib qw( . ./t ../blib/lib );
use vars qw( $DEBUG );
$^W = 1;
use Template::Test;

$DEBUG = 0;

my $dsn = $ENV{ DBI_DSN } || do {
	warn "DBI_DSN should be set to point to a test database\n";
	print "1..1\nnot ok\n";
	exit;
};

my $user = $ENV{ DBI_USER } || '';
my $pass = $ENV{ DBI_PASS } || '';

# $Template::Parser::DEBUG = 1;
# $Template::Directive::PRETTY = 1;
my $dbh = init_database($dsn,$user,$pass);

test_expect(\*DATA, undef, { dsn  => $dsn,
							 user => $user,
							 pass => $pass });

cleanup_database($dbh);


#------------------------------------------------------------------------

sub init_database {

    my $dbh = DBI->connect(@_)
	|| die "DBI connect() failed: $DBI::errstr\n";

    sql_query($dbh, 'CREATE TABLE grp ( 
                         id Char(16), 
                         name Char(32) 
                     )');

    sql_query($dbh, 'CREATE TABLE usr  ( 
                         id Char(16), 
                         name Char(32),
                         grp Char(16)
                     )');

    sql_query($dbh, "INSERT INTO grp 
                     VALUES ('foo', 'The Foo Group')");
    sql_query($dbh, "INSERT INTO grp 
                     VALUES ('bar', 'The Bar Group')");

    sql_query($dbh, "INSERT INTO usr 
		     VALUES ('abw', 'Andy Wardley', 'foo')");
    sql_query($dbh, "INSERT INTO usr 
		     VALUES ('sam', 'Simon Matthews', 'foo')");
    sql_query($dbh, "INSERT INTO usr 
		     VALUES ('hans', 'Hans von Lengerke', 'bar')");
    sql_query($dbh, "INSERT INTO usr 
		     VALUES ('mrp', 'Martin Portman', 'bar')");
    $dbh;
}


sub cleanup_database {
    my $dbh = shift;

    sql_query($dbh, 'DROP TABLE usr');
    sql_query($dbh, 'DROP TABLE grp');
    
    $dbh->disconnect();
};


sub sql_query {
    my ($dbh, $sql) = @_;

    my $sth = $dbh->prepare($sql) 
	|| warn "prepare() failed: $DBI::errstr\n";

    $sth->execute() 
	|| warn "execute() failed: $DBI::errstr\n";
    
    $sth->finish();
}

#------------------------------------------------------------------------

__DATA__
[% USE DBI(dsn,user,pass) -%]
[% FOREACH group = DBI.query('SELECT * FROM grp ORDER BY id') -%]
*  [% group.id %] - [% group.name %]
[% END %]

-- expect --
*  bar - The Bar Group
*  foo - The Foo Group

-- test --
[% USE DBI(dsn,user,pass) -%]
[% FOREACH group = DBI.query('SELECT * FROM grp 
                              ORDER BY id') -%]
*  [% group.id %] - [% group.name %]
[% FOREACH user = DBI.query("SELECT * FROM usr 
                             WHERE grp='$group.id'
                             ORDER BY id") -%]
   - [% user.name %] ([% user.id %])
[% END %]
[% END %]

-- expect --
*  bar - The Bar Group
   - Hans von Lengerke (hans)
   - Martin Portman (mrp)

*  foo - The Foo Group
   - Andy Wardley (abw)
   - Simon Matthews (sam)

-- test --
[% USE DBI(dsn,user,pass) -%]
[% INCLUDE groupinfo FOREACH group = DBI.query('SELECT * FROM grp 
                                                ORDER BY id') -%]
[% BLOCK groupinfo -%]
*  [% group.id %] - [% group.name %]
[% INCLUDE userinfo %]
[% END %]

[% BLOCK userinfo -%]
[% FOREACH user = DBI.query("SELECT * FROM usr 
                             WHERE grp='$group.id'
                             ORDER BY id") -%]
   - [% user.name %] ([% user.id %])
[% BREAK IF user.id == 'hans' -%]
[% END -%]
[% END %]

-- expect --
*  bar - The Bar Group
   - Hans von Lengerke (hans)

*  foo - The Foo Group
   - Andy Wardley (abw)
   - Simon Matthews (sam)


-- test --
[% USE DBI(dsn,user,pass) -%]
[% FOREACH group = DBI.query('SELECT * FROM grp 
                              ORDER BY id') -%]
3 Group: [% group.id %]
[% FOREACH user = DBI.query("SELECT * FROM usr 
                             WHERE grp='$group.id'
                             ORDER BY id") -%]
   User: [% user.name %] ([% user.id %])
[% END -%]
[% "last group" IF loop.last %]
[% END %]

-- expect --
3 Group: bar
   User: Hans von Lengerke (hans)
   User: Martin Portman (mrp)

3 Group: foo
   User: Andy Wardley (abw)
   User: Simon Matthews (sam)
last group
