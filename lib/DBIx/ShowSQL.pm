package DBIx::ShowSQL;
use strict;
use warnings;
our $VERSION = '1.0';
no warnings qw/redefine prototype/;
use Carp ();
use Time::HiRes;
use DBI;
use Term::ANSIColor ();

our $WARN;
our $COUNT;
our $EscapeMethod ||= 'perl';
our $Colored;
$Colored = -t STDIN unless defined $Colored;

if ($ENV{SQL_DEBUG}) {
  $WARN = 1;
  $COUNT = 1;
}

sub import {
  $WARN = 1 unless defined $WARN;
  $COUNT = 1 unless defined $COUNT;
} # import

sub _escape ($) {
    if ($EscapeMethod eq 'perl') {
        my $v = $_[0];
        eval {
          $v =~ s/([^\x20-\x5B\x5D-\x7E])/ord $1 > 0xFF ? sprintf '\x{%04X}', ord $1 : sprintf '\x%02X', ord $1/ge;
        }; # for old buggy version of Perl ("Malformed UTF-8" fatal warning)
        return $v;
    } else { # asis
        return $_[0];
    }
}

sub with_color ($$) {
  if ($Colored) {
    return Term::ANSIColor::colored ([$_[0]], $_[1]);
  } else {
    return $_[1];
  }
} # with_color

sub carp (@) {
  if ($Colored) {
    Carp::carp (@_, Term::ANSIColor::color ('white'));
    print STDERR Term::ANSIColor::color ('reset');
  } else {
    Carp::carp (@_);
  }
} # carp

our $SQLCount ||= 0;

$Carp::CarpInternal{+__PACKAGE__} = 1;

my $orig_connect = \&DBI::connect;
*DBI::connect = sub {
  my $time = [Time::HiRes::gettimeofday];

  my $return = $orig_connect->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  if ($WARN) {
      carp with_color 'bright_black', sprintf '%.2f ms | %s', $tv * 1000, $_[1];
  }
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
      ? ' (' . join (', ', map { defined $_ ? _escape $_ : '(undef)' } @_[1..$#_]) . ')'
      : '';

  $SQLCount++ if $COUNT;
  if ($Colored) {
      $sql =~ s/((?:[Ff][Rr][Oo][Mm]|[Ii][Nn][Tt][Oo]|^[Uu][Pp][Dd][Aa][Tt][Ee])\s*)(\S+)/$1 . with_color 'blue', $2/ge;
  }
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
      ? ' (' . join (', ', map { defined $_ ? _escape $_ : '(undef)' } @_[3..$#_]) . ')'
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
