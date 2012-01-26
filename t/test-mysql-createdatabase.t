package test::Test::MySQL::CreateDatabase;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use base qw(Test::Class);

BEGIN { $Test::MySQL::CreateDatabase::DEBUG = 1 if $ENV{MOCO_DEBUG} };

use Test::MySQL::CreateDatabase qw(
    reset_db_set test_dsn dsn2dbh copy_schema_from_file
    execute_inserts_from_file extract_schema_sql_from_file
);
use Test::MoreMore;

sub _copy_schema_from_file : Test(3) {
    reset_db_set;
    my $dsn = test_dsn 'mytest';
    my $dbh = dsn2dbh $dsn;
    my $f = file(__FILE__)->dir->subdir('data')->file('mysql-createdatabase-schema1.sql');
    copy_schema_from_file $f => $dbh;

    ok $dbh->do('SHOW CREATE TABLE hoge1');
    ok $dbh->do('SHOW CREATE TABLE hoge2');
    ng $dbh->do('SHOW CREATE TABLE hoge3');
}

sub _extract_schema_sql_from_file : Test(1) {
    my $f = file(__FILE__)->dir->subdir('data')->file('mysql-createdatabase-schema2.sql');
    my $result = extract_schema_sql_from_file $f;
    eq_or_diff $result, [
        'CREATE DATABASE hoge',
        qq"CREATE TABLE foo (\n  bar int, baz int\n)",
        'INSERT INTO foo (bar, baz) VALUES (1, 4)',
        'CREATE DATABASE hoge',
        qq"CREATE TABLE foo (\n  bar int, baz int\n)",
        'INSERT INTO foo (bar, baz) VALUES (1, 4)',
    ];
}

sub _execute_inserts_from_file : Test(2) {
    reset_db_set;
    my $dsn = test_dsn 'mytest';
    my $dbh = dsn2dbh $dsn;
    my $f = file(__FILE__)->dir->subdir('data')->file('mysql-createdatabase-schema1.sql');
    copy_schema_from_file $f => $dbh;

    my $f2 = file(__FILE__)->dir->subdir('data')->file('mysql-createdatabase-inserts1.sql');
    execute_inserts_from_file $f2 => $dbh;

    ng $dbh->do('SHOW CREATE TABLE hoge3');
    my $sth = $dbh->prepare('SELECT COUNT(*) AS count FROM hoge1');
    $sth->execute;
    my $data = $sth->fetchall_arrayref({});
    is $data->[0]->{count}, 2;
}

__PACKAGE__->runtests;

1;
