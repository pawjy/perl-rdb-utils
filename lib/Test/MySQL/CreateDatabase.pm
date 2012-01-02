package Test::MySQL::CreateDatabase;
use strict;
use warnings;
our $VERSION = '1.0';
use Test::mysqld;
use Test::More;
use DBI;
use Exporter::Lite;

our @EXPORT_OK;

our $DEBUG;

my $mysqld;
push @EXPORT_OK, qw(mysqld);
sub mysqld () {
    return $mysqld if $mysqld;
    
    warn "Initializing Test::mysqld...\n" if $DEBUG;
    $mysqld = eval {
        Test::mysqld->new(
            mysqld => $ENV{MYSQLD} || Test::mysqld::_find_program(qw/mysqld bin libexec/),
            mysql_install_db => $ENV{MYSQL_INSTALL_DB} || Test::mysqld::_find_program(qw/mysql_install_db bin scripts/) . ($^O eq 'darwin' ? '' : ' '),
            my_cnf => {
                'skip-networking' => '',
                'innodb_lock_wait_timeout' => 2,
            },
        );
    } or BAIL_OUT($Test::mysqld::errstr);
    warn "done.\n" if $DEBUG;
    return $mysqld;
}

sub test_dbh_do ($) {
    my $dbh = DBI->connect(mysqld->dsn(dbname => 'mysql'))
        or BAIL_OUT($DBI::errstr);
    $dbh->do(shift || die) or BAIL_OUT($DBI::errstr);
}

our $DBNumber = 1;

push @EXPORT_OK, qw(reset_db_set);
sub reset_db_set () {
    $DBNumber++;
}

push @EXPORT_OK, qw(test_dsn);
sub test_dsn ($) {
    my $name = shift || die;
    $name .= '_' . $DBNumber . '_test';
    my $sql = sprintf 'CREATE DATABASE `%s`', $name;
    warn "$sql\n" if $DEBUG;
    test_dbh_do $sql;
    return mysqld->dsn(dbname => $name);
}

push @EXPORT_OK, qw(dsn2dbh);
sub dsn2dbh ($) {
    return DBI->connect($_[0], {RaiseError => 1});
}
push @EXPORT_OK, qw(copy_schema_from_test_db);

sub copy_schema_from_test_db ($$$$) {
    my ($orig_dsn, $user, $password, $new_dbh) = @_;
    my $dbname;
    if ($orig_dsn =~ /\bdbname=([0-9A-Za-z_]+?_test)\b/) {
        $dbname = $1;
    } else {
        warn "Can't copy schema from |$orig_dsn|\n";
        return;
    }
    my $command = qq[mysqldump --no-data=true -u\Q$user\E -p\Q$password\E \Q$dbname\E];
    warn $command, "\n" if $DEBUG;
    my $schema = `$command`;

    while ($schema =~ /\b(CREATE TABLE.*?);/sg) {
        my $sql = $1;
        warn "$sql\n" if $DEBUG;
        my $sth = $new_dbh->prepare($sql);
        $sth->execute;
    }
}

push @EXPORT_OK, qw(copy_schema_from_file);
sub copy_schema_from_file ($$) {
    my ($f, $new_dbh) = @_;
    my $schema = $f->slurp;
    while ($schema =~ /\b(CREATE TABLE.*?);/sg) {
        my $sql = $1;
        warn "$sql\n" if $DEBUG;
        my $sth = $new_dbh->prepare($sql);
        $sth->execute;
    }
}

push @EXPORT_OK, qw(execute_inserts_from_file);
sub execute_inserts_from_file ($$) {
    my ($f, $new_dbh) = @_;
    my $schema = $f->slurp;
    while ($schema =~ /\b(INSERT.*?);/sg) {
        my $sql = $1;
        warn "$sql\n" if $DEBUG;
        my $sth = $new_dbh->prepare($sql);
        $sth->execute;
    }
}

1;
