#==============================================================================
# 
# Template::Plugin::DBI
#
# DESCRIPTION
#
# A Template Plugin to provide access to a DBI data source
#
# AUTHOR
#   Simon Matthews <sam@knowledgepool.com>
#
# COPYRIGHT
#
#   Copyright (C) 1999 Simon Matthews.  All Rights Reserved
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#------------------------------------------------------------------------------
#
# $Id: DBI.pm,v 1.9 1999/12/17 06:43:54 sam Exp $
# 
#==============================================================================

package Template::Plugin::DBI;

require 5.004;

use strict;
use vars qw(@ISA $VERSION $DEBUG $AUTOLOAD);
use Template::Constants qw(:status);
use DBI;
use Data::Dumper;

# we are going to be a plug in so.....
use Template::Plugin;

# we are a Template::Iterator so that we can be called in a FOREACH context
use Template::Iterator;
use Template::Exception;

@ISA = qw(Template::Plugin Template::Iterator);

$VERSION = sprintf("%02.2f", sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/) - 1);

$DEBUG = 0;

#==============================================================================
#                      -----  CLASS METHODS -----
#==============================================================================

#==============================================================================
#
# new($context, \@params)
# 
# Returns a new DBI Plugin that will then be used to provide access to a number
# of methods that can then be used from within a Template
#
# By default a new unconfigured object is returned.  However it is possible
# to pass either a single string that is taken to be a DBI connect string, or
# a hash containing a number of configuration values
#
#==============================================================================

sub new {
	my $self    = shift;
	my $context = shift;
	my $class   = ref($self) || $self;

	# check to see if we got a valid context so that we can throw errors
	unless (ref $context) {

		$context = undef;
		# warn "context is invalid [$context]\n" if $DEBUG;
		# $context = new Template::Exception;
	}

	$self = bless { _CONTEXT => $context, ERRSTR => '' }, $class;

	$self->{ _POSITION } = [];


	# call connect now if we have a parameter
	# note this may fail (which could be ok) if the parameter is a HASH
	# that does not contain the connection details at this time
	$self->connect(@_) if @_;

	print STDERR "New returns [$self]\n" if $DEBUG;
	# return this object
	return $self;
}


#==============================================================================
#
# sub DESTROY
#
# Called automatically on the death of the object. Simply disconnects the 
# database handle cleanly
#
#==============================================================================

sub DESTROY {
	my $self = shift;

	# check that we finish all open statement handles
	print STDERR "DESTROY [$self]\n" if $DEBUG;

	$self->{ _STH }->finish() if $self->{ _STH };

	# check if we are a clone
	if ($self->{ _CLONE } && $self->{ _PARENT }) {
		$self->{ _PARENT }->_clone_died();
		return;
	}

	# we only do this if we created the connection
	$self->{ _DBH }->disconnect() if $self->{ _DBH };
	
}


#==============================================================================
#
# AUTOLOAD
#
# Automagically returns data from ourself
#
#==============================================================================

sub AUTOLOAD {
	my $self   = shift;
	my $method = $AUTOLOAD;

	# ignore the destuctor
	$method =~ /::DESTROY$/ && return;

	# save a copy of the ARGS as the function may need them
	my (@args) = @_;

	my $param = shift(@args);

	print STDERR "Autoload for $AUTOLOAD on $self\n" if $DEBUG;

	my $context = $self->{ _CONTEXT } || return;

	# remove the package prefix
	$method =~ s/.*:://;

	# translate the name to uppercase
	$method =~ tr/a-z/A-Z/;

	# check that the data exists in self
	if (defined( $self->{ $method })) {
		return $self->{ $method } || '';
	} else {
		# try to call the method on DBI so that errstr etc will work as
		# advertised
		eval { return DBI->$method(@_); };

		return $self->_throw("no such method: $method");
	}
}

#==============================================================================
#
# first()
#
# returns the value of 'FIRST' in the current position HASH
# 
#==============================================================================

sub first { 
	my $self = shift;
	$self->_position_hash('FIRST');
}


#==============================================================================
#
# last()
#
# returns the value of 'LAST' in the current position HASH
# 
#==============================================================================

sub last {
	my $self = shift;
	$self->_position_hash('LAST');
}


#==============================================================================
#
# count()
#
# returns the value of 'COUNT' in the current position HASH
# 
#==============================================================================

sub count {
	my $self = shift;
	$self->_position_hash('COUNT');
}


#==============================================================================
#
# connect($dbi_connect, $dbi_user, $dbi_password)
#
# or
#
# connect( { data_source = 'dbi:driver:database' 
#			 username    = 'foo' 
#			 password    = 'bar' } )
#
# returns a database handle
#
#==============================================================================

sub connect {
	my $self = shift;
	my $init = shift;
	my @connect = ();

	print STDERR "REF init is [", ref $init, "]\n" if $DEBUG;

	if (ref $init eq 'HASH') {

		my $dsn = $init->{ data_source } || 
				  $init->{ connect } || 
				  $init->{ dbi_connect } || 
				  $init->{ db_connect } ||
				  return $self->_throw('data source not defined');

		push(@connect, $dsn);

		# get the username parameter
		push(@connect, 
				$init->{ username } || 
				$init->{ user } || 
				$init->{ dbi_username } || 
				$init->{ db_username } ||
				'');

		# get the password parameter
		push(@connect, 
				$init->{ password } || 
				$init->{ passwd } || 
				$init->{ dbi_password } || 
				$init->{ db_password } ||
				'');

	} elsif ($init) {

		@connect = ($init, @_);
	
	} else {

		return $self->_throw('connection parameters not defined');

	}

	print STDERR "sub connect [", join('] [', @connect), "]\n"
		if $DEBUG;

	# call the internal connect method to do the connection
	# return $self->_connect(@connect) || 
		   # $self->_throw('connection failed');

	$self->_connect(@connect);

	if ($self->{ _DBH }) {
		return ('', STATUS_OK);
	};

	return (undef, $self->_throw('connection failed'));

}


#==============================================================================
#
# sub disconnect()
#
# Disconnects the current active database connection
#
#==============================================================================

sub disconnect {
	my $self = shift;


}

#==============================================================================
#
# sub finish()
#
# Disconnects the current active database connection
#
#==============================================================================

sub finish {
	my $self = shift;


}

#==============================================================================
#
# sub prepare( $sql )
#
# Sets up the object ready to be iterated over by a template FOREACH
#
#==============================================================================

sub prepare {
	my $self    = shift;
	my $sql     = shift || return (undef, STATUS_OK);

	# get a database connection
	my $dbh = $self->_connect() || return $self->_throw('connection failed');

	my $clone = $self->_clone();

	$clone->{ _STH } = $dbh->prepare($sql) || do {
		warn "Failed to prepare [$sql]\n";
		return $self->_throw("Prepare failed: $DBI::errstr");
	};

	# return $self;
	return $clone;
}


#==============================================================================
#
# sub execute( @params )
#
#==============================================================================

sub execute {
	my $self = shift;
	my @params = @_;

	print STDERR "Execute called\n" if $DEBUG;

	# get the current statement handle
	my $sth = $self->{ _STH } || 
		return $self->_throw("No query prepared");

	$sth->execute(@params) || do {
		# warn "Execute failed\n";
		return $self->_throw("Execute failed: $DBI::errstr");
	};

	# return us as an iterator when we do an execute if all is OK
	# this means that we can use execute directly in the template
	return ($self, STATUS_OK);
}


#==============================================================================
#
# sub quote( $value [, $data_type ])
#
# returns a quoted string (correct for the connected database) from the value
# passed in
#
#==============================================================================

sub quote {
	my $self = shift;
	my $dbh = $self->_connect() || return $self->_throw('connection failed');
	
	# do the quote of the value
	my $value = $dbh->quote(@_);

	return wantarray ?  ($value, STATUS_OK) : $value;
}


#==============================================================================
#
# do(sql_statement)
#
# Does the sql statement without returning a record set
#
#==============================================================================

sub do {
	my $self    = shift;
	my $sql     = shift || return (undef, STATUS_OK);

	# get a database connection
	my $dbh = $self->_connect() || return $self->_throw('connection failed');


	return $dbh->do($sql) || $self->_throw('do failed');

	my $result = $dbh->do($sql);

	return ($result, STATUS_OK) if $result;

	return $self->_throw('do failed');

}

#==============================================================================
#
# query(sql_query)
#
#
#==============================================================================

sub query {
	my $self    = shift;
	my $query   = shift;

	# call prepare - which will return a clone
	my ($clone, $status) = $self->prepare($query);

	# if prepare fails it will be throwing an error which will be in $status
	return $status unless $clone;

	# call execute to action the query that we have prepared
	return $clone->execute();

}


#==============================================================================
#
# get_first()
# 
# Is called when we are being used in an Iterator context
#
# What we do is to read the first row and put it into our row cache
# We then call next to read then next row and return some data
#
#==============================================================================

sub get_first {
	my $self = shift;

	# set some status variables into $self
	$self->{ _POSITION }->{ FIRST } = 2;
	$self->{ _POSITION }->{ LAST }  = 0;
	$self->{ _POSITION }->{ COUNT } = 0;

	print STDERR "Get first called\n" if $DEBUG;

	# get the first row
	$self->_fetchrow();

	return $self->get_next();
}


#==============================================================================
#
# get_next()
#
# called repeatedly to access successive elements in the data (in our case
# each record from the DBI handle)
#
#==============================================================================

sub get_next {
	my $self  = shift;

	print STDERR "get_next called\n" if $DEBUG;

	my $pos = $self->{ _POSITION };

	# we are getting the next row so increment the count
	$pos->{ COUNT } = $pos->{ COUNT } + 1;

	# decrement the first inidcator
	$pos->{ FIRST } = $pos->{ FIRST } - 1 if $pos->{ FIRST };

	# get the row cache which is the data that will be returned
	# if there is no row cache then we are about to return nothing so
	# restore the sth state
	my $hash = $self->{ _ROWCACHE } || do {
		print STDERR "Nothing in rowcache so returning DONE\n" if $DEBUG;

		# there is no more data so......
		return (undef, STATUS_DONE);
	};

	# look ahead to the next row so that the rowcache is refilled
	$self->_fetchrow();

	# process any fixup handlers on our data
	if (defined($self->{ _FIXUP })) {

		# check each fixup handler
		foreach (keys %{$self->{ _FIXUP }}) {

			# if data with the same name as the fixup exists then call it
			# to process the data
			if (exists $hash->{ $_ }) {
				$hash->{ $_ } = &{$self->{ _FIXUP }->{ $_ }}($hash->{ $_ });
			}
		}
	}

	# change 'undef' in the hash to prevent undef warnings
	foreach (keys %$hash) {
		$hash->{ $_ } = '' unless defined($hash->{$_});
	}

	# praise be . . . . we have data
	return ($hash, STATUS_OK);
}


#==============================================================================
#
# sub _connect()
#
# Used internally to do the connecting to the DBI database.
#
#==============================================================================

sub _connect {
	my $self = shift;
	my @connect = @_;

	my $check = join(':', @connect);

	# if we have no connect data assume the current connection
	$check = $self->{ _DBH_CONNECT_DETAILS } unless $check;

	print STDERR "_connect [$check]\n" if $DEBUG;

	# check for a defined database handle
	if ($self->{ _DBH }) {

		print STDERR "We already have a connection\n" if $DEBUG;

		return $self->{ _DBH } if $self->{ _DBH_CONNECT_DETAILS } eq $check;

		# if we get here then the current cached connection needs to be deleted
		$self->{ _DBH }->disconnect();
		delete $self->{ _DBH_CONNECT_DETAILS };

	} elsif (! @connect) {

		# no existing DBH and no connect params provided
		$self->{ _DBH } = undef;
		return undef;

	}

	DBI->trace(0);
	print STDERR "Connecting for [$check]\n" if $DEBUG;
	# if we make it to here then we need to make a new connection

	$self->{ _DBH } = DBI->connect( $connect[0],
									$connect[1],
									$connect[2],
			 					  { PrintError => 0 }) 
					  || return $self->_throw('DBI->connect failed _connect');

	# store the details of the connection
	$self->{ _DBH_CONNECT_DETAILS } = $check;

	return $self->{ _DBH };

}

#==============================================================================
#
# _clone_died
#
# When one of the clones dies then we need to pop the position hash so that
# we are returning the correct position information
#
#==============================================================================

sub _clone_died {
	my $self = shift;

	shift( @{ $self->{ _POSITION } } );

}


#==============================================================================
#
# _clone()
#
# Create a clone from ourself that can safely be used to start a new query
#
#==============================================================================

sub _clone {
	my $self = shift;
	my $class = ref($self) || return;

	my $clone = {};

	foreach (qw(_CONTEXT _DBH _FIXUP _DBH_CONNECT_DETAILS)) {
		$clone->{ $_ } = $self->{ $_ } if exists $self->{ $_ };
	}

	# created a clone
	$clone->{ _CLONE } = 1;

	# give it a family tree
	$clone->{ _PARENT } = $self;

	$clone->{ _POSITION } = {
		FIRST => 0,
		LAST  => 0,
		COUNT => 0 };

	bless $clone, $class;

	# print "Created clone position [", $clone->{ _POSITION }, "]\n";

	# save the location of the current child's position
	unshift( @{ $self->{ _POSITION } }, $clone->{ _POSITION } );

	print STDERR "Creating clone [$clone]\n" if $DEBUG;

	return $clone;

}

#==============================================================================
#
# _position_hash($name)
#
# returns the named value from the current position HASH
#
#==============================================================================

sub _position_hash {
	my $self = shift;
	my $name = shift || return;

	print "_position_hash($name) called\n" if $DEBUG;

	# get the position
	my $pos = $self->{ _POSITION } || $self->{ _POSITION } || return;

	# if what we have is an arrayref then this is the factory so
	# get the first element (which should be a HASH)
	if (ref($pos) eq 'ARRAY') {
		$pos = @$pos[0];
	}

	# check that we now have a HASH
	unless (ref($pos) eq 'HASH') {
		return;
	}

	return $pos->{ $name };
}


#==============================================================================
#
# _fetchrow()
#
#==============================================================================

sub _fetchrow {
	my $self = shift;

	# clear the rowcache
	$self->{ _ROWCACHE } = undef;

	# get the previous copy of the Satement Handle or we consider our work done
	my $sth = $self->{ _STH } || do {
		print STDERR "Failed to get STH\n" if $DEBUG;
		return;
	};

	my $hash = $sth->fetchrow_hashref() || do {

		$self->{ _POSITION }->{ LAST } = 1;
		print STDERR "Failed to get any data from the STH\n" if $DEBUG;
		# we failed to get any data from the sth so......
		# finish the sth
		$sth->finish();

		# and then return DONE
		return;

	};

	# put the data into the rowcache
	$self->{ _ROWCACHE } = $hash;

	return;
}


#==============================================================================
# sub _throw($error)
#
# Returns an error either using the context that we got when we were created
# otherwise we create a new exception and return that
#
#==============================================================================

sub _throw {
	my $self = shift;
	# my $type = shift || return undef;
	my $err  = shift || return undef;

	# print STDERR "Throw called\n";

	$self->{ ERRSTR } = $err;

	return (undef, Template::Exception->new('DBI', $err) );

}

1;

__END__

=head1 NAME

Template::Plugin::DBI - Template Plugin interface to the DBI.pm module

=head1 SYNOPSIS

    [% USE DBI('dbi:driver:database', 'username', 'password') %]

    [% FOREACH row = DBI.query( 'select col from table' ) %]

    Here comes the data [% row.col %]

    [% END %]

=head1 DESCRIPTION

This plugin provides an interface between a Template processor and DBI.  This
provides a simple method of including data from a DBI data source into a 
template to be processed by the Template module.

The DBI object can be initialised as follows:

    [% USE DBI %]

This creates an uninitialised DBI object.  It can be initialised when it is 
created by passing parameters that will be passed to the DBI connect call.

    [% USE DBI('dbi:driver:database','username','password') %]

This will create a fully initialised DBI object.

=head1 OBJECT METHODS

=head2 connect

connect(data_source, username, password)
connect(data_source = 'dbi:driver:database' username = 'foo' password = 'bar' )

Establishes a database connection.

The connect method accepts both the positional and named parameter syntax as
shown.  

The connect method provides for connecting to a data source explicitly, this 
can be used to reconnect an exisiting object to a different data source.

=head2 query( sql query string )

The query method returns data from the database given the provided sql query 
string.  It does this in an efficient manner by only retrieving a single row
at a time and returning this data to the Template through the 
Template::Iterator interface.  This means that you can do this:

    [% FOREACH DBI.query('select * from users') %]

    Each row can be processed here

    [% END %]

=head2 prepare

Prepare a query for later execution.  This will return a clone of the current
Template::Plugin::DBI object.  You can use this thus:

[% user_query = DBI.prepare("select * from users where id = ?") %]

In order to get data back from the database for the query you should use
execute (see below)

=head2 execute

Execute a previously prepared query.  Given the example above you would call
this with a FOREACH to select each of the records retuned.

[% FOREACH user = user_query.execute('sam') %]
[% user.name %]
[% END %]

=head2 do

Do executes a sql statement where there will be no records returned.  It will
return true if the statement was successful

[% IF DBI.do("delete from users where uid = 'sam'") %]
Oh No the user was deleted
[% END %]

=head2 quote

=head1 REQUIRES

Perl 5.005, Template-Toolkit 1.00, DBI

=head1 SEE ALSO

perldoc Template

perldoc DBI

=head1 AUTHOR

Simon A Matthews, sam@knowledgepool.com

=head1 COPYRIGHT

Copyright (C) 1999 Simon Matthews.  All Rights Reserved

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 STILL TO DO

FIXUP Handlers
	- how to install
	- ALL type to process all
	- UNDEF magic should be optional ?

DBI method access
	- commit ?
	- rollback ?

Tests

DBI errors being thrown

Statement and DBH methods



