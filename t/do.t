#============================================================= -*-perl-*-
#
# t/nested.t
#
# Test script testing nested queries.
#
# Written by Andy Wardley <abw@cre.canon.co.uk>
#
# Modifications by Simon Matthews <sam@knowledgepool.com>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# $Id: do.t,v 1.1 1999/12/17 06:40:06 sam Exp $
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
[%- result = DBI.do("insert into usr values ('numb','Numb Nuts','bar')") -%]
[% FOREACH user = DBI.query('SELECT * FROM usr ORDER BY id') -%]
*  [% user.id %] - [% user.name %]
[% END %]
-- expect --
*  abw - Andy Wardley
*  hans - Hans von Lengerke
*  mrp - Martin Portman
*  numb - Numb Nuts
*  sam - Simon Matthews
-- test --
[% USE DBI(dsn,user,pass) -%]
[%- IF DBI.do("delete from usr where id = 'numb'") -%]
Oh no deleted the user !
[% END %]
-- expect --
Oh no deleted the user !
-- test --
[% USE DBI(dsn,user,pass) -%]
[% FOREACH user = DBI.query('SELECT * FROM usr ORDER BY id') -%]
*  [% user.id %] - [% user.name %]
[% END %]
-- expect --
*  abw - Andy Wardley
*  hans - Hans von Lengerke
*  mrp - Martin Portman
*  sam - Simon Matthews


