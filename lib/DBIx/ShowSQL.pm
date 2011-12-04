package DBIx::ShowSQL;
use strict;
use warnings;
our $VERSION = '1.0';
no warnings qw/redefine prototype/;
use Carp;
use Time::HiRes;
use DBI;

our $WARN = 1;
our $COUNT = 1;

our $SQLCount = 0;

$Carp::CarpInternal{+__PACKAGE__} = 1;

my $orig_connect = \&DBI::connect;
*DBI::connect = sub {
  my $time = [Time::HiRes::gettimeofday];

  my $return = $orig_connect->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  carp sprintf '%.2f ms | %s',
      $tv * 1000, $_[1];
  return $return;
}; # DBI::connect

my $orig_execute = \&DBI::st::execute;
*DBI::st::execute = sub {
  #my ($sth, @binds) = @_;
  my $time = [Time::HiRes::gettimeofday];

  my $return = $orig_execute->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  my $sql = $_[0]->{Database}->{Statement};
  my $bind = @_ > 1
      ? ' (' . join (', ', map { defined $_ ? $_ : '(undef)' } @_[1..$#_]) . ')'
      : '';

  $SQLCount++ if $COUNT;
  carp sprintf '%.2f ms | %s%s (rows=%d)',
      $tv * 1000, $sql, $bind, $_[0]->rows if $WARN;
  return $return;
}; # DBI::st::execute

my $orig_do = \&DBI::db::do;
*DBI::db::do = sub {
  #my ($sth, $sql, undef, @binds) = @_;
  my $time = [Time::HiRes::gettimeofday];

  my $return = $orig_do->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  my $bind = @_ > 3
      ? ' (' . join (', ', map { defined $_ ? $_ : '(undef)' } @_[3..$#_]) . ')'
      : '';

  $SQLCount++ if $COUNT;
  carp sprintf '%.2f ms | %s%s (rows=%d)',
      $tv * 1000, $_[1], $bind, $return if $WARN;
  return $return;
}; # DBI::db::do

my $orig_begin_work = \&DBI::db::begin_work;
*DBI::db::begin_work = sub {
  my $time = [Time::HiRes::gettimeofday];
  
  my $return = $orig_begin_work->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  carp sprintf '%.2f ms | DBI begin_work', $tv * 1000 if $WARN;
  return $return;
}; # DBI::db::begin_work

my $orig_commit = \&DBI::db::commit;
*DBI::db::commit = sub {
  my $time = [Time::HiRes::gettimeofday];
  
  my $return = $orig_commit->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  carp sprintf '%.2f ms | DBI commit', $tv * 1000 if $WARN;
  return $return;
}; # DBI::db::commit

my $orig_rollback = \&DBI::db::rollback;
*DBI::db::rollback = sub {
  my $time = [Time::HiRes::gettimeofday];
  
  my $return = $orig_rollback->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  carp sprintf '%.2f ms | DBI rollback', $tv * 1000 if $WARN;
  return $return;
}; # DBI::db::rollback

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Public Domain.

=cut

1;
