#==============================================================================
# 
# Template::Plugin::DBI
#
# DESCRIPTION
#
#   A Template Toolkit plugin to provide access to a DBI data source.
#
# AUTHOR
#   Simon Matthews <sam@knowledgepool.com>
#
#   Many updates thanks to Andy Wardley for tidying up the interface
#
# COPYRIGHT
#
#   Copyright (C) 1999-2000 Simon Matthews.  All Rights Reserved
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#------------------------------------------------------------------------------
#
# $Id: DBI.pm,v 1.11 2000/09/20 07:35:22 sam Exp $
# 
#==============================================================================

package Template::Plugin::DBI;

require 5.004;

use strict;
use Template::Plugin;
use Template::Exception;
use DBI;

use vars qw(@ISA $VERSION $DEBUG $AUTOLOAD);
use base qw( Template::Plugin Template::Base );

$VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/) - 1;
$DEBUG    = 0 unless defined $DEBUG;


    
#========================================================================
#                      -----  CLASS METHODS -----
#========================================================================

# sub load {

	# print STDERR "Class [$_[0]]\n";
	# return $_[0];

# }

#------------------------------------------------------------------------
# new($context, @params)
# 
# Returns a new DBI Plugin that will then be used to provide access to a 
# number of methods that can then be used from within a Template
#
# By default a new unconfigured object is returned.  However it is possible
# to pass either a single string that is taken to be a DBI connect string, or
# a hash containing a number of configuration values
#------------------------------------------------------------------------

sub new {
    my $class   = shift;
    my $context = shift;

	my $self;

	print STDERR "DBI new class is [$class]\n" if $DEBUG;

	if (ref $class) {
		$self = $class;
		$class = ref $self;

	} else {
    	$self = bless {
		_CONTEXT => $context, 
    	}, $class;
	}

    $self->connect(@_) if @_;

	return $self;
}


#========================================================================
#                        -- PUBLIC OBJECT METHODS --
#========================================================================

#------------------------------------------------------------------------
# connect($data_source, $username, $password)
# connect( { data_source = 'dbi:driver:database' 
#	     username    = 'foo' 
#	     password    = 'bar' } )
#
# Connection method for the plugin which makes a DBI connection.  Returns
# a DBI handle or undef on error.
#------------------------------------------------------------------------

sub connect {
    my $self = shift;
    my $init = shift;
    my @connect = ();

    print STDERR "REF init is [", ref $init, "]\n" if $DEBUG;
    
    if (ref $init eq 'HASH') {
        # get the data source
	my $dsn = 
	        $init->{ data_source } 
	     || $init->{ connect } 
	     || $init->{ dbi_connect }
	     || $init->{ db_connect } 
	     || return $self->_throw('data source not defined');
	push(@connect, $dsn);

	# get the username parameter
	push(@connect, 
	        $init->{ username } 
	     || $init->{ user } 
	     || $init->{ dbi_username } 
	     || $init->{ db_username } 
	     || '');

	# get the password parameter
	push(@connect, 
	        $init->{ password } 
	     || $init->{ passwd } 
	     || $init->{ dbi_password } 
	     || $init->{ db_password } 
	     || '');
    } elsif ($init) {
		@connect = ($init, @_);
    }
    else {
		return $self->_throw('connection parameters not defined');
    }

    $self->_connect(@connect);

	return '';
}


#------------------------------------------------------------------------
# prepare($sql)
#
# Prepare a query and store the live statement handle internally for
# subsequent execute() calls.
#------------------------------------------------------------------------

sub prepare {
    my $self = shift;
    my $sql  = shift || return undef;

    my $dbh = $self->{ _DBH }
	|| return $self->_throw('no connection');

    my $sth = $dbh->prepare($sql) 
	|| return $self->_throw("Prepare failed: $DBI::errstr");
    
    # create wrapper object around handle to return to template client
    return ($self->{ _STH } = Template::Plugin::DBI::Query->new($sth));
}


#------------------------------------------------------------------------
# execute(@params)
#
# Execute the current statement handle created by prepare().
#------------------------------------------------------------------------

sub execute {
    my $self = shift;

    my $sth = $self->{ _STH } 
	|| return $self->_throw('no query prepared');

    $sth->execute(@_) 
}



#------------------------------------------------------------------------
# query($sql, @params)
#
# Prepare and execute a query in one.
#------------------------------------------------------------------------

sub query {
    my $self = shift;
    my $sql  = shift || return undef;

    my $dbh = $self->{ _DBH }
	|| return $self->_throw('no connection');
    my $sth = $dbh->prepare($sql) 
	|| return $self->_throw("Prepare failed: $DBI::errstr");
    
    $sth->execute(@_) 
	|| return $self->_throw("DBI execute failed: $DBI::errstr");

    $self->{ _LAST_RESULT } = Template::Plugin::DBI::Iterator->new($sth);
}


#------------------------------------------------------------------------
# do($sql)
#
# Prepares and executes an sql statement.
#------------------------------------------------------------------------

sub do {
    my $self = shift;
    my $sql  = shift || return '';

    # get a database connection
    my $dbh = $self->{ _DBH }
	|| return $self->_throw('no connection');

    return $dbh->do($sql) 
	|| $self->_throw("DBI do failed: $DBI::errstr");
}


#------------------------------------------------------------------------
# quote($value [, $data_type ])
#
# Returns a quoted string (correct for the connected database) from the 
# value passed in.
#------------------------------------------------------------------------

sub quote {
    my $self = shift;

    my $dbh = $self->{ _DBH }
	|| return $self->_throw('no connection');

    $dbh->quote(@_);
}


#------------------------------------------------------------------------
# error($error)
#
# Returns the current internal error value stored in ERRSTR if called
# without any arguments.  If $error is specified then this value is 
# used to update ERRSTR and undef is returned.
#------------------------------------------------------------------------

sub error {
    my $self = shift;

    if (@_) {
	$self->{ ERRSTR } = join('', @_);
        return undef;
    }
    else {
	return $self->{ ERRSTR };
    }
}


#------------------------------------------------------------------------
# DESTROY
#
# Called automatically on the death of the object. Simply disconnects the 
# database handle cleanly
#------------------------------------------------------------------------

sub DESTROY {
    my $self = shift;
    undef $self->{ _LAST_RESULT };
    $self->{ _DBH }->disconnect() if $self->{ _DBH };
}


#------------------------------------------------------------------------
# AUTOLOAD
#
# Delegates all undefined method calls to the most recent result 
# iterator.
#------------------------------------------------------------------------

sub AUTOLOAD {
    my $self   = shift;
    my $method = $AUTOLOAD;
    my $result;

    $method =~ s/.*:://;
    return if $method eq 'DESTROY';

    # delegate to the most recent result iterator
    $result = $self->{ _LAST_RESULT }
        || return $self->_throw("no such method: $method");

    $result->$method(@_);
}



#------------------------------------------------------------------------
# disconnect()
#
# Disconnects the current active database connection
#------------------------------------------------------------------------

sub disconnect {
    my $self = shift;
    $self->{ _DBH }->disconnect() if $self->{ _DBH };
}



#========================================================================
#                    --- PRIVATE OBJECT METHODS ---
#========================================================================

#------------------------------------------------------------------------
# _connect($dsn, $user, $pass)
#------------------------------------------------------------------------

sub _connect {
    my $self    = shift;
    my @connect = @_;
    my $check   = join(':', @connect);


    # if we have no connect data assume the current connection
    $check = $self->{ _DBH_CONNECT_DETAILS } unless @connect;

    # check for a defined database handle
    if ($self->{ _DBH }) {

	# connection may be cached
	return($self->{ _DBH })
	    if $self->{ _DBH_CONNECT_DETAILS } eq $check;

	$self->{ _DBH }->disconnect();
	delete $self->{ _DBH_CONNECT_DETAILS };
    }
    elsif (! @connect) {
	# no existing DBH, and no connect params provided
	return undef;
    }

    $self->{ _DBH } = DBI->connect( $connect[0],
				    $connect[1],
				    $connect[2],
				  { PrintError => 0 }) 
	|| return $self->_throw("DBI connect failed: $DBI::errstr");

    # store the details of the connection
    $self->{ _DBH_CONNECT_DETAILS } = $check;

    return $self->{ _DBH };
}


#------------------------------------------------------------------------
# _throw($error)
#
# Stores the error internally in ERRSTR and returns an (undef, exception)
# pair.
#------------------------------------------------------------------------

sub _throw {
    my $self = shift;
    my $err  = shift || return undef;

	$self->{ ERRSTR } = $err;

	if ($Template::VERSION ge '2') {
   		die Template::Exception->new('DBI', $err);
	} else {
		return (undef, Template::Exception->new('DBI', $err) );
	}
}


#========================================================================
# Template::Plugin::DBI::Query
#========================================================================

package Template::Plugin::DBI::Query;
use base qw( Template::Plugin );

sub new {
    my ($class, $sth, $parent) = @_;
    bless \$sth, $class;
}

sub execute {
    my $self = shift;

    $$self->execute(@_) 
	|| return $self->_throw("DBI execute failed: $DBI::errstr");

    Template::Plugin::DBI::Iterator->new($$self);
}



#========================================================================
# Template::Plugin::DBI::Iterator;
#========================================================================

package Template::Plugin::DBI::Iterator;

use Template::Iterator;
use base qw( Template::Iterator );
use vars qw( $AUTOLOAD  $DEBUG);

sub new {
    my ($class, $sth, $params) = @_;
    my $self = bless { 
	_STH => $sth,
    }, $class;

    return $self;
}

sub DESTROY {
    my $self = shift;
    my $sth  = $self->{ _STH };
    $sth && $sth->finish();
}


sub AUTOLOAD {
    my $self   = shift;
    my $method = $AUTOLOAD;

    $method =~ s/.*:://;
    return if $method eq 'DESTROY';

    $method =~ tr/a-z/A-Z/;

    print STDERR "AUTOLOAD $method => ", $self->{ $method }, "\n" if $DEBUG;

    return exists $self->{ $method }
	? $self->{ $method }
	: undef;
}


#------------------------------------------------------------------------
# get_first()
#
# Initialises iterator to read from statement handle.  We maintain a 
# one-record lookahead buffer to allow us to detect if the current 
# record is the last in the series.
#------------------------------------------------------------------------

sub get_first {
    my $self = shift;

    # set some status variables into $self
    $self->{ FIRST } = 2;
    $self->{ LAST }  = 0;
    $self->{ COUNT } = 0;

    print STDERR "get_first() called\n" if $DEBUG;

    # get the first row
    $self->_fetchrow();

    print STDERR "get_first() calling get_next()\n" if $DEBUG;

    return $self->get_next();
}


#------------------------------------------------------------------------
# get_next()
#
# Called to read remaining result records from statement handle.
#------------------------------------------------------------------------

sub get_next {
    my $self = shift;
    my ($data, $fixup);

    print STDERR "get_next() called\n" if $DEBUG;

    # we are getting the next row so increment the count
    $self->{ COUNT } = $self->{ COUNT } + 1;

    # decrement the 'first-record' flag
    $self->{ FIRST }-- if $self->{ FIRST };

    # we should have a row already cache in _ROWCACHE
    return (undef, Template::Constants::STATUS_DONE)
	unless $data = $self->{ _ROWCACHE };

    print STDERR "get_next() calling _fetchrow()\n" if $DEBUG;

    # look ahead to the next row so that the rowcache is refilled
    $self->_fetchrow();

    # process any fixup handlers on the data
    if (defined($fixup = $self->{ _FIXUP })) {
	foreach (keys %$fixup) {
	    $data->{ $_ } = &{ $fixup->{$_} }($data->{ $_ })
		if exists $data->{ $_ };
	}
    }

    print STDERR "get_next() returning $data (STATUS_OK)\n" if $DEBUG;

    return ($data, Template::Constants::STATUS_OK);
}



#------------------------------------------------------------------------
# _fetchrow()
#
# Retrieve a record from the statement handle and store in row cache.
#------------------------------------------------------------------------

sub _fetchrow {
    my $self = shift;
    my $sth  = $self->{ _STH };

    my $data = $sth->fetchrow_hashref() || do {
	$self->{ LAST } = 1;
	$self->{ _ROWCACHE } = undef;
	$sth->finish();
	return;
    };
    $self->{ _ROWCACHE } = $data;
    return;
}

1;

__END__

=head1 NAME

Template::Plugin::DBI - Template Plugin interface to the DBI.pm module

=head1 SYNOPSIS

    [% USE DBI('dbi:driver:database', 'username', 'password') %]

    [% USE DBI(data_source = 'dbi:driver:database',
               username    = 'username', 
               password    = 'password') %]

    [% FOREACH item = DBI.query( 'SELECT rows FROM table' ) %]
       Here's some row data: [% item.field %]
    [% END %]

    [% DBI.prepare('SELECT * FROM user WHERE manager = ?') %]
    [% FOREACH user = DBI.execute('sam') %]
       ...

    [% query = DBI.prepare('SELECT * FROM user WHERE manager = ?') %]
    [% FOREACH user = query.execute('sam') %]
       ...

    [% IF DBI.do("DELETE FROM users WHERE uid = 'sam'") %]
       Oh No!  The user was deleted!
    [% END %]

=head1 DESCRIPTION

This Template Toolkit plugin module provides an interface to the Perl
DBI/DBD modules, allowing you to integrate SQL queries into your template
documents.

A DBI plugin object can be created as follows:

    [% USE DBI %]

This creates an uninitialised DBI object.  You can then open a connection
to a database using the connect() method.

    [% DBI.connect('dbi:driver:database', 'username', 'password') %]

The DBI plugin can be initialised when created by passing parameters to
the constructor, called from the USE directive.

    [% USE DBI('dbi:driver:database','username','password') %]

Methods can then be called on the plugin object using the familiar dotted
notation.  e.g.

    [% FOREACH item = DBI.query( 'SELECT rows FROM table' ) %]
       Here's some row data: [% item.field %]
    [% END %]

See L<OBJECT METHODS> below for further details.

An alternate variable name can be provided for the plugin as per regular
Template Toolkit syntax:

    [% USE mydb = DBI('dbi:driver:database','username','password') %]

    [% FOREACH item = mydb.query( 'SELECT rows FROM table' ) %]
       Here's some row data: [% item.field %]
    [% END %]

The disconnect() method can be called to explicitly disconnect the current
database.  This is called automatically when the plugin goes out of scope.

=head1 OBJECT METHODS

=head2 connect($data_source, $username, $password)

Establishes a database connection.  This method accepts both positional 
and named parameter syntax.  e.g. 

    [% db = DBI.connect(data_source, username, password) %]
    [% db = DBI.connect(data_source = 'dbi:driver:database'
                        username    = 'foo' 
                        password    = 'bar' ) %]

The connect method allows you to connect to a data source explicitly.
It can also be used to reconnect an exisiting object to a different
data source.

=head2 query($sql)

This method submits an SQL query to the database and creates an iterator 
object to return the results.  This may be used directly in a FOREACH 
directive as shown below.  Data is automatically fetched a row at a time
from the query result set as required for greater efficiency.

    [% FOREACH row = DBI.query('select * from users') %]
       Each [% row.whatever %] can be processed here
    [% END %]

=head2 prepare($sql)

Prepare a query for later execution.  This returns a compiled query
object (of the Template::Plugin::DBI::Query class) on which the
execute() method can subsequently be called.  The compiled query is
also cached internally, allowing the execute() method call to also be
made on the parent DBI object.

    [% user_query = DBI.prepare(
		      'SELECT * FROM users WHERE id = ?') %]

=head2 execute(@args)

Execute a previously prepared query.  This method can be called on the 
parent DBI object to execute the query most recently compiled via 
prepare().  It can also be called directly on the query object returned
by prepare().  Returns an iterator object which can be used directly in
a FOREACH directive.

    [% user_query = DBI.prepare(
		      'SELECT * FROM users WHERE manager = ?') %]

    [% FOREACH user = user_query.execute('sam') %]
       [% user.name %]
    [% END %]

    [% FOREACH user = DBI.execute('sam') %]
       [% user.name %]
    [% END %]


=head2 do($sql)

Do executes a sql statement where there will be no records returned.  It will
return true if the statement was successful

    [% IF DBI.do("DELETE FROM users WHERE uid = 'sam'") %]
       Oh No the user was deleted
    [% END %]

=head2 quote($value, $type)

Calls the quote() method on the underlying DBI handle to quote the value
specified in the appropriate manner for its type.

=head2 disconnect()

Disconnects the current database.

=head2 error()

Returns the current error value, if any.

=head1 PRE-REQUISITES

Perl 5.005, Template-Toolkit 2.00-beta3, DBI 1.02

=head1 SEE ALSO

For general information on the Template Toolkit and DBI modules, see
L<Template> and L<DBI>.

=head1 AUTHOR

Simon A Matthews, E<lt>sam@knowledgepool.comE<gt>

=head1 COPYRIGHT

Copyright (C) 1999 Simon Matthews.  All Rights Reserved

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=begin todo

=head1 STILL TO DO

=over 4

=item FIXUP Handlers

  - how to install
  - ALL type to process all
  - UNDEF magic should be optional ?

=item DBI method access

  - commit ?
  - rollback ?

=item Tests

=item DBI errors being thrown

=item Statement and DBH methods

=back

=end




