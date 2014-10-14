use strict;
use warnings;
use Path::Tiny;
use lib path (__FILE__)->parent->parent->child ('lib')->stringify;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use Test::MySQL::CreateDatabase qw(reset_db_set test_dsn);
use AnyEvent::DBI::Hashref;

if ($ENV{SQL_DEBUG}) {
  require DBIx::ShowSQL;
}

test {
  my $c = shift;
  ok $AnyEvent::DBI::Hashref::VERSION;
  done $c;
} n => 1, name => 'version';

# ------ exec_as_hashref ------

test {
  my $c = shift;
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
    test {
      is_deeply $rows, [
        [1],
        [2],
      ];
      is $rc, 2;
    } $c;
    $cv->end;
  });

  $cv->begin;
  $dbh->exec_as_hashref ('select * from foo order by id asc', sub {
    my ($dbh, $rows, $rc) = @_;
    test {
      is_deeply $rows, [
        {id => 1},
        {id => 2},
      ];
      is $rc, 2;
    } $c;
    $cv->end;
  });
  $cv->end;

  $cv->cb (sub {
    test {
      done $c;
      undef $c;
      undef $dbh;
    } $c;
  });
} n => 4, name => 'exec_as_hashref';

test {
  my $c = shift;
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
    test {
      is $rows, undef;

      $called++;
    } $c;
    $cv->end;
  });

  $cv->begin;
  $dbh->exec_as_hashref ('select * from foo', sub {
    my ($dbh, $rows, $rc) = @_;
    test {
      is $rc, 2;
    } $c;
    $called++;
    $cv->end;
  });

  $cv->end;
  $cv->cb (sub {
    test {
      is $called, 2;
      done $c;
      undef $c;
      undef $dbh;
    } $c;
  });
} n => 3, name => 'exec_as_hashref_syntax_error';

test {
  my $c = shift;
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my $dbh = AnyEvent::DBI->new ($dsn, '', '', on_error => sub { });
  $dbh->exec ('create table foo (id int)', sub {});
  $dbh->exec ('insert into foo (id) values (1), (2)', sub {});

  $cv->begin;

  $cv->begin;
  $dbh->exec_as_hashref ('select * from hoge', 12, sub { # sic!
    my ($dbh, $rows, $rc) = @_;
    test {
      is $rows, undef;
    } $c;
    $cv->end;
  });

  $cv->begin;
  $dbh->exec_as_hashref ('select * from foo', sub {
    my ($dbh, $rows, $rc) = @_;
    test {
      is $rc, 2;
    } $c;
    $cv->end;
  });

  $cv->end;
  $cv->cb (sub {
    test {
      done $c;
      undef $c;
      undef $dbh;
    } $c;
  });
} n => 2, name => 'exec_as_hashref_bind_error';

# ------ exec_or_fatal_as_hashref ------

test {
  my $c = shift;
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
    test {
      is_deeply $rows, [
        [1],
        [2],
      ];
      is $rc, 2;
    } $c;
    $cv->end;
  });

  $cv->begin;
  $dbh->exec_or_fatal_as_hashref ('select * from foo order by id asc', sub {
    my ($dbh, $rows, $rc) = @_;
    test {
      is_deeply $rows, [
        {id => 1},
        {id => 2},
      ];
      is $rc, 2;
    } $c;
    $cv->end;
  });
  $cv->end;

  $cv->cb (sub {
    test {
      done $c;
      undef $c;
      undef $dbh;
    } $c;
  });
} n => 4, name => 'exec_or_fatal_as_hashref';

test {
  my $c = shift;
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my $dbh = AnyEvent::DBI->new ($dsn, '', '');
  $dbh->exec ('create table foo (id int)', sub {});
  $dbh->exec ('insert into foo (id) values (1), (2)', sub {});

  $cv->begin;

  $cv->begin;
  $dbh->exec_or_fatal_as_hashref ('select * from hoge', sub { # sic!
    my ($dbh, $rows, $rc) = @_;
    test {
      is $rows, undef;
    } $c;
    $cv->end;
  });

  $cv->begin;
  $dbh->exec_or_fatal_as_hashref ('select * from foo', sub {
    my ($dbh, $rows, $rc) = @_;
    test {
      is $rows, undef;
    } $c;
    $cv->end;
  });

  $cv->end;
  $cv->cb (sub {
    test {
      done $c;
      undef $c;
      undef $dbh;
    } $c;
  });
} n => 2, name => 'exec_or_fatal_as_hashref_syntax_error' if 0; # XXX die in async

test {
  my $c = shift;
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
    test {
      is $rows, undef;
    } $c;
    $cv->end;
  });

  $cv->begin;
  $dbh->exec_or_fatal_as_hashref ('select * from foo', 12, sub {
    my ($dbh, $rows, $rc) = @_;
    test {
      is $rows, undef;
    } $c;
    $cv->end;
  });

  $cv->end;
  $cv->cb (sub {
    test {
      done $c;
      undef $c;
      undef $dbh;
    } $c;
  });
} n => 2, name => 'exec_or_fatal_as_hashref_bind_error' if 0; # XXX die in async

run_tests;

=head1 LICENSE

Copyright 2012-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
