##
## Before `make install' is performed this script should be runnable with
## `make test'. After `make install' it should work as `perl 1.t'
##

BEGIN {
    # If you want to run ODBC tests, perform the following steps:
    # 1) Create the following table in your ODBC-compliant database:
    #    CREATE TABLE sessions (
    #        id CHAR(32) NOT NULL,
    #        a_session TEXT NOT NULL
    #    );
    # 2) Change %options below to something suitable for your database
    #    installation.
    # 3) Comment out the following three lines:

    use Test::More tests => 1;
    use_ok('CGI::Session::ODBC');
    exit();

    # Check if DB_File is avaialble. Otherwise, skip this test
    eval 'require DBI';
    if ($@)
    {
        print "1..0\n";
        exit(0);
    }

    eval 'require DBD::ODBC';
    if ($@)
    {
        print "1..0\n";
        exit(0);
    }

    require Test;
    Test->import();

    plan(tests => 14);
};

##
## Begin the ODBC testing
##

use CGI::Session;
ok(1);

# Change these to suit your particular configuration:
my %options = (
    DataSource => "DBI:ODBC:your_dsn_name",
    User        => "user",
    Password    => "pw"
);

my $s = new CGI::Session("driver:ODBC", undef, \%options );

# Session exist?
ok($s);

# Valid Session ID?
ok($s->id);

# Can we store session data ok?
$s->param(author=>'Jason A. Crome', name => 'CGI::Session::ODBC', version=>'0.1');
ok($s->param('author'));
ok($s->param('name'));
ok($s->param('version'));
$s->param(-name=>'email', -value=>'cromedome@cpan.org');
ok($s->param(-name=>'email'));

# Make sure session is still valid
ok(!$s->expire() );
$s->expire("+10m");
ok($s->expire());

# Try to create a new session, make sure it's the existing session
my $sid = $s->id();
$s->flush();
my $s2 = new CGI::Session("driver:ODBC", $sid, \%options);

# Make sure session and it's data are valid
ok($s2);
ok($s2->id() eq $sid);
ok($s2->param('email'));
ok($s2->param('author'));
ok($s2->expire());

# Delete the session
$s2->delete();

