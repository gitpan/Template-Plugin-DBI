#============================================================= -*-perl-*-
#
# t/prepare.t
#
# Test script testing prepare queries.
#
# Written by Simon Matthews <sam@knowledgepool.com>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# $Id: prepare.t,v 1.3 2000/09/20 07:32:16 sam Exp $
#
#========================================================================

use strict;
use DBI;
use lib qw( . ./t ../blib/lib );
use vars qw( $DEBUG );
$^W = 1;
use Template::Test;

$DEBUG = 1;

my $dsn = $ENV{ DBI_DSN } || do {
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
[% users = DBI.prepare("select * from usr where id = ?") -%]
[% FOREACH uid = ['sam' 'abw'] -%]
[% FOREACH user = users.execute( uid ) -%]
*  [% user.id %] - [% user.name %]
[% END %]
[%- END %]
-- expect --
*  sam - Simon Matthews
*  abw - Andy Wardley

-- test --
[% USE DBI(dsn,user,pass) -%]
[% users = DBI.prepare("select * from usr where id = ?") -%]
[% groups = DBI.prepare("select * from grp where id = ?") -%]
[% FOREACH uid = ['sam' 'abw' 'hans'] -%]
[% FOREACH user = users.execute( uid ) -%]
*  [% user.id %] - [% FOREACH group = groups.execute( user.grp ) %][% group.name %][% END %]
[% END %]
[%- END %]

-- expect --
*  sam - The Foo Group
*  abw - The Foo Group
*  hans - The Bar Group
