#============================================================= -*-perl-*-
#
# t/count.t
#
# Test script testing loop counters on queries
#
# Written by Simon Matthews <sam@knowledgepool.com>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# $Id: count.t,v 1.3 2000/09/20 07:28:27 sam Exp $
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
[% FOREACH user = DBI.query('SELECT * FROM usr ORDER BY id') -%]
[% DBI.count %] *  [% user.id %] - [% user.name %]
[% END %]
-- expect --
1 *  abw - Andy Wardley
2 *  hans - Hans von Lengerke
3 *  mrp - Martin Portman
4 *  sam - Simon Matthews

-- test --
[% USE DBI(dsn,user,pass) -%]
[% FOREACH group = DBI.query('SELECT * FROM grp 
                              ORDER BY id') -%]
[% loop.count %] Group: [% group.id %]
[% FOREACH user = DBI.query("SELECT * FROM usr 
                             WHERE grp='$group.id'
                             ORDER BY id") -%]
 [% loop.count %] User: [% user.name %] ([% user.id %])
[% END -%]

[% END %]

-- expect --
1 Group: bar
 1 User: Hans von Lengerke (hans)
 2 User: Martin Portman (mrp)

2 Group: foo
 1 User: Andy Wardley (abw)
 2 User: Simon Matthews (sam)


-- test --

