# CGI::Session::ODBC - ODBC driver for CGI::Session.
#
# Copyright (C) 2003 by Jason A. Crome, cromedome@cpan.org.
#
# This module is directly based on CGI::Session::PostgreSQL by Cosimo
# Streppone, and indirectly based on CGI::Session::MySQL module
# by Sherzod Ruzmetov.
#
# Revision History:
# - 2003/08/08 by Jason A. Crome: Initial version.
#

package CGI::Session::ODBC;

use strict;
# Inheriting necessary functionalities from the
# following libraries. Do not change it unless
# you know what you are doing!
use base qw(
    CGI::Session
    CGI::Session::ID::MD5
    CGI::Session::Serialize::Default
);

# Driver specific libraries
use vars qw($VERSION $TABLE_NAME);

$VERSION = '0.1';
$TABLE_NAME = 'sessions';

##
## Driver methods follow
##

# Stores the serialized data. Returns 1 if successful, else returns undef.
sub store
{
    my ($self, $sid, $options, $data) = @_;
    my $dbh = $self->ODBC_dbh($options);
    my $db_data;

    eval
    {
    	# Does this session already exist?
        $db_data = $dbh->selectrow_array(
            "SELECT a_session   " .
            "  FROM $TABLE_NAME " .
            " WHERE id =        " . $dbh->quote($sid)
        );
    };

    if($@)
    {
        $self->error("Couldn't fetch session data for '$sid'");
        return undef;
    }

    eval
    {
        if($db_data)
        {
        	# Update the existing session with new information
            $dbh->do(
                "UPDATE $TABLE_NAME " .
                "SET a_session=     " . $dbh->quote($self->freeze($data)) .
                "WHERE id =         " . $dbh->quote($sid)
            );
        }
        else
        {
        	# This is a new session
            $dbh->do(
                "INSERT INTO $TABLE_NAME (id, a_session) ".
                "VALUES (" . $dbh->quote($sid) . ", " . $dbh->quote($self->freeze($data)) . ") "
            );
        }
    };

    if($@)
    {
        $self->error("Error updating session '$sid': $@");
        warn("Error updating session '$sid': $@");
        return undef;
    }

    return 1;
}

# Retrieve and deserialize the session data.
sub retrieve
{
    my ($self, $sid, $options) = @_;

    # Fetch our session data.
    my $dbh = $self->ODBC_dbh($options);
	my $data;

    eval {
    	$data = $dbh->selectrow_array(
    		"SELECT a_session   " .
            "  FROM $TABLE_NAME " .
			" WHERE id =        " . $dbh->quote($sid)
	    );
	};

	if($@)
    {
        $self->error("Couldn't fetch session data for '$sid'");
        return undef;
    }

    # Deserialize and return the session data
    return $self->thaw($data);
}

# Delete the session data
sub remove
{
    my ($self, $sid, $options) = @_;
    my $dbh = $self->ODBC_dbh($options);
    my $data;

    eval
    {
    	# Does this session exist?
        $data = $dbh->selectrow_array(
            "SELECT a_session   " .
            "  FROM $TABLE_NAME " .
            " WHERE id =        " . $dbh->quote($sid)
        );
    };

    if($@) 
    {
        $self->error("Couldn't fetch session data for '$sid'");
        return undef;
    }

    eval 
    {
        $dbh->do("DELETE FROM $TABLE_NAME WHERE id = " . $dbh->quote($sid));
    };

    if($@)
    {
        $self->error("Couldn't delete session '$sid'");
        return undef;
    }

    return 1;
}

# Clean up prior to destroying the driver
sub teardown
{
    my ($self, $sid, $options) = @_;
    my $dbh = $self->ODBC_dbh($options);

    # Call commit() if we're not set to auto-commit
    $dbh->commit() unless $dbh->{AutoCommit};

    # Disconnect
    $dbh->disconnect() if $self->{ODBC_disconnect};

    return 1;
}

# Create the driver
sub ODBC_dbh 
{
    my ($self, $options) = @_;
    my $args = $options->[1] || {};
    
    return $self->{ODBC_dbh} if defined $self->{ODBC_dbh};
    $TABLE_NAME = $args->{TableName} if defined $args->{TableName};

    require DBI;

    $self->{ODBC_dbh} = $args->{Handle} || DBI->connect(
        $args->{DataSource},
        $args->{User}       || undef,
        $args->{Password}   || undef,
        { RaiseError=>1, PrintError=>1, AutoCommit=>1, LongReadLen=>32767 }
    );

    # If we're the one established the connection,
    # we should be the one who closes it
    $args->{Handle} or $self->{ODBC_disconnect} = 1;

    return $self->{ODBC_dbh};
}

1;

=pod

=head1 NAME

CGI::Session::ODBC - ODBC driver for CGI::Session

=head1 SYNOPSIS

    use CGI::Session;
    $session = new CGI::Session("driver:ODBC", undef, { Handle => $dbh });

For more examples, consult the L<CGI::Session> manual.

=head1 DESCRIPTION

CGI::Session::ODBC is a CGI::Session driver to store session data in any
ODBC-capable database.  To write your own drivers for B<CGI::Session>, 
please refer to the L<CGI::Session> manual.

=head1 STORAGE

To store session data in the ODBC-compliant database, you must first
create a suitable table for your session data to live.  In many instances,
the following SQL will accomplish this:

    CREATE TABLE sessions (
        id CHAR(32) NOT NULL,
        a_session TEXT NOT NULL
    );

You can add any number of additional columns to the table, but the columns
"id" and "a_session" are required as defined above.  If you want to store the 
session data in a table other than "sessions", you will also need to specify 
the B<TableName> attribute as an argument:

    use CGI::Session;

    $session = new CGI::Session("driver:ODBC", undef,
        { Handle => $dbh, TableName => 'my_sessions' });

There are no special provisions made for row-level locking.  ODBC is intended
to be platform independent, and to the best of the author's knowledge at the
time of this writing, there is no platform independent manner of implementing
row locking.  Please contact the author with your experiences with this module
in that regard.

=head1 COPYRIGHT

Copyright (C) 2003 by Jason A. Crome. All rights reserved.

This library is free software and can be modified and distributed under the 
same terms as Perl itself.

=head1 AUTHOR

Jason A. Crome <cromedome@cpan.org>, heavily based on the 
CGI::Session::PostgreSQL by Cosimo Streppone, which was heavily based on the 
CGI::Session::MySQL driver by Sherzod Ruzmetov, original author of 
CGI::Session.

=head1 SEE ALSO

=over 4

=item *

L<CGI::Session|CGI::Session> - CGI::Session manual

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual

=item *

L<CGI::Session::CookBook|CGI::Session::CookBook> - practical solutions for real life problems

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session

=back

=cut
