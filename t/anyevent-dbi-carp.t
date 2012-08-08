package test::AnyEvent::DBI::Carp;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use base qw(Test::Class);
use Test::More;
use Test::MySQL::CreateDatabase qw(reset_db_set test_dsn);
use AnyEvent::DBI::Carp;

if ($ENV{SQL_DEBUG}) {
  require DBIx::ShowSQL;
}

sub _version : Test(1) {
  ok $AnyEvent::DBI::Carp::VERSION;
} # _version

sub _exec_syntax_error : Test(1) {
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my @arg;
  my $dbh = AnyEvent::DBI::Carp->new ($dsn, '', '', on_error => sub {
    my (undef, $file, $line) = @_;
    push @arg, $file, $line;
  });

  $dbh->exec ('select * from hoge', sub {
    $cv->send;
  });

  $cv->recv;

  is_deeply \@arg, [__FILE__, __LINE__ - 4];
} # _exec_syntax_error

sub _exec_syntax_error_sub : Test(1) {
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my @arg;
  my $dbh = AnyEvent::DBI::Carp->new ($dsn, '', '', on_error => sub {
    my (undef, $file, $line) = @_;
    push @arg, $file, $line;
  });

  my $code = sub {
    local $Carp::CarpLevel = $Carp::CarpLevel + 1;

    $dbh->exec ('select * from hoge', sub {
      $cv->send;
    });
  };

  $code->();

  $cv->recv;

  is_deeply \@arg, [__FILE__, __LINE__ - 4];
} # _exec_syntax_error_sub

sub _exec_syntax_error_sub_pack : Test(1) {
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my @arg;
  my $dbh = AnyEvent::DBI::Carp->new ($dsn, '', '', on_error => sub {
    my (undef, $file, $line) = @_;
    push @arg, $file, $line;
  });

  {
    package test::hoge::fuga::1;
    *code = sub {
      $dbh->exec ('select * from hoge', sub {
        $cv->send;
      });
    };
  }

  test::hoge::fuga::1->code;

  $cv->recv;

  is_deeply \@arg, [__FILE__, __LINE__ - 4];
} # _exec_syntax_error_sub_pack

sub _exec_syntax_error_sub_pack_code : Test(1) {
  reset_db_set;
  my $dsn = test_dsn 'hoge';
  my $cv = AnyEvent->condvar;

  my @arg;
  my $dbh = AnyEvent::DBI::Carp->new ($dsn, '', '', on_error => sub {
    my (undef, $file, $line) = @_;
    push @arg, $file, $line;
  });

  {
    package test::hoge::fuga::1;
    *code = sub {
      $dbh->exec ('select * from hoge', sub {
        $cv->send;
      });
    };
  }

  my $code = sub {
    test::hoge::fuga::1->code;
  };

  $code->();

  $cv->recv;

  is_deeply \@arg, [__FILE__, __LINE__ - 4 - 3];
} # _exec_syntax_error_sub_pack_code

__PACKAGE__->runtests;

# For Test::More
no warnings 'redefine';
my $kill_child = \&AnyEvent::DBI::kill_child;
*AnyEvent::DBI::kill_child = sub { local $?; $kill_child->(@_) };


1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
