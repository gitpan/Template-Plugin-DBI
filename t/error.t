#============================================================= -*-perl-*-
#
# t/error.t
#
# Test script testing error handling.
#
# This script is specific to version 1 of template. See error2.t for 
# version 2 tests.
#
# Written by Simon Matthews <sam@knowledgepool.com>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# $Id: error.t,v 1.3 2000/09/20 07:29:45 sam Exp $
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

$Template::VERSION ge '2' && do {
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
[%- USE DBI(dsn,user,pass) -%]
[%- CATCH DBI -%]Error is: [% e.info %][% END %]
[%- FOREACH user = DBI.query('SELECT * FROM foobarbaz ORDER BY id') -%]
*  [% user.id %] - [% user.name %]
[% END -%]
-- expect --

Error is: DBI execute failed: Table 'test.foobarbaz' doesn't exist
