package test::DBIx::ShowSQL;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use base qw(Test::Class);
use Test::More;

sub _use_ok : Test(1) {
  use_ok 'DBIx::ShowSQL';
} # _use_ok

__PACKAGE__->runtests;

1;
