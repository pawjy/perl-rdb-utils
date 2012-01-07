package test::AnyEvent::DBI::Hashref;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use base qw(Test::Class);
use Test::More;
use Test::MySQL::CreateDatabase qw(reset_db_set test_dsn);
use AnyEvent::DBI::Hashref;

if ($ENV{SQL_DEBUG}) {
  require DBIx::ShowSQL;
}

sub _version : Test(1) {
  ok $AnyEvent::DBI::Hashref::VERSION;
} # _version

# ------ exec_as_hashref ------

sub _exec_as_hashref : Test(4) {
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my $dbh = AnyEvent::DBI->new ($dsn, '', '');
  $dbh->exec ('create table foo (id int)', sub {});
  $dbh->exec ('insert into foo (id) values (1), (2)', sub {});

  $cv->begin;

  $cv->begin;
  $dbh->exec ('select * from foo order by id asc', sub {
    my ($dbh, $rows, $rc) = @_;
    is_deeply $rows, [
      [1],
      [2],
    ];
    is $rc, 2;

    $cv->end;
  });

  $cv->begin;
  $dbh->exec_as_hashref ('select * from foo order by id asc', sub {
    my ($dbh, $rows, $rc) = @_;
    is_deeply $rows, [
      {id => 1},
      {id => 2},
    ];
    is $rc, 2;

    $cv->end;
  });
  $cv->end;

  $cv->recv;
} # _exec_as_hashref

sub _exec_as_hashref_syntax_error : Test(3) {
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my $dbh = AnyEvent::DBI->new ($dsn, '', '', on_error => sub { });
  $dbh->exec ('create table foo (id int)', sub {});
  $dbh->exec ('insert into foo (id) values (1), (2)', sub {});

  my $called;
  $cv->begin;

  $cv->begin;
  $dbh->exec_as_hashref ('select * from hoge', sub {
    my ($dbh, $rows, $rc) = @_;
    is $rows, undef;

    $called++;
    $cv->end;
  });

  $cv->begin;
  $dbh->exec_as_hashref ('select * from foo', sub {
    my ($dbh, $rows, $rc) = @_;
    is $rc, 2;

    $called++;
    $cv->end;
  });

  $cv->end;
  $cv->recv;

  is $called, 2;
} # _exec_as_hashref_syntax_error

sub _exec_as_hashref_bind_error : Test(2) {
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my $dbh = AnyEvent::DBI->new ($dsn, '', '', on_error => sub { });
  $dbh->exec ('create table foo (id int)', sub {});
  $dbh->exec ('insert into foo (id) values (1), (2)', sub {});

  $cv->begin;

  $cv->begin;
  $dbh->exec_as_hashref ('select * from hoge', 12, sub {
    my ($dbh, $rows, $rc) = @_;
    is $rows, undef;

    $cv->end;
  });

  $cv->begin;
  $dbh->exec_as_hashref ('select * from foo', sub {
    my ($dbh, $rows, $rc) = @_;
    is $rc, 2;

    $cv->end;
  });

  $cv->end;
  $cv->recv;
} # _exec_as_hashref_bind_error

# ------ exec_or_fatal_as_hashref ------

sub _exec_or_fatal_as_hashref : Test(4) {
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my $dbh = AnyEvent::DBI->new ($dsn, '', '');
  $dbh->exec ('create table foo (id int)', sub {});
  $dbh->exec ('insert into foo (id) values (1), (2)', sub {});

  $cv->begin;

  $cv->begin;
  $dbh->exec ('select * from foo order by id asc', sub {
    my ($dbh, $rows, $rc) = @_;
    is_deeply $rows, [
      [1],
      [2],
    ];
    is $rc, 2;

    $cv->end;
  });

  $cv->begin;
  $dbh->exec_or_fatal_as_hashref ('select * from foo order by id asc', sub {
    my ($dbh, $rows, $rc) = @_;
    is_deeply $rows, [
      {id => 1},
      {id => 2},
    ];
    is $rc, 2;

    $cv->end;
  });
  $cv->end;

  $cv->recv;
} # _exec_or_fatal_as_hashref

sub _exec_or_fatal_as_hashref_syntax_error : Test(2) {
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my $dbh = AnyEvent::DBI->new ($dsn, '', '');
  $dbh->exec ('create table foo (id int)', sub {});
  $dbh->exec ('insert into foo (id) values (1), (2)', sub {});

  $cv->begin;

  $cv->begin;
  $dbh->exec_or_fatal_as_hashref ('select * from hoge', sub {
    my ($dbh, $rows, $rc) = @_;
    is $rows, undef;

    $cv->end;
  });

  $cv->begin;
  $dbh->exec_or_fatal_as_hashref ('select * from foo', sub {
    my ($dbh, $rows, $rc) = @_;
    is $rows, undef;

    $cv->end;
  });

  $cv->end;
  $cv->recv;
} # _exec_or_fatal_as_hashref_syntax_error

sub _exec_or_fatal_as_hashref_bind_error : Test(2) {
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my $dbh = AnyEvent::DBI->new ($dsn, '', '');
  $dbh->exec ('create table foo (id int)', sub {});
  $dbh->exec ('insert into foo (id) values (1), (2)', sub {});

  $cv->begin;

  $cv->begin;
  $dbh->exec_or_fatal_as_hashref ('select * from hoge', 12, sub {
    my ($dbh, $rows, $rc) = @_;
    is $rows, undef;

    $cv->end;
  });

  $cv->begin;
  $dbh->exec_or_fatal_as_hashref ('select * from foo', sub {
    my ($dbh, $rows, $rc) = @_;
    is $rows, undef;

    $cv->end;
  });

  $cv->end;
  $cv->recv;
} # _exec_or_fatal_as_hashref_bind_error

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
