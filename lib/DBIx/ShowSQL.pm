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
$Colored = -t STDERR unless defined $Colored;

if ($ENV{SQL_DEBUG}) {
  $WARN = 1;
  $COUNT = 1;
}

sub import {
  $WARN = 1 unless defined $WARN;
  $COUNT = 1 unless defined $COUNT;
} # import

sub with_color ($$) {
  if ($Colored) {
    return Term::ANSIColor::colored ([$_[0]], $_[1]);
  } else {
    return $_[1];
  }
} # with_color

sub _ltsv_escape ($) {
  if ($EscapeMethod eq 'perl') {
    my $v = $_[0];
    if ($Colored) {
      eval {
        $v =~ s/([^\x20-\x5B\x5D-\x7E])/with_color 'bright_magenta', (ord $1 > 0xFF ? sprintf '\x{%04X}', ord $1 : sprintf '\x%02X', ord $1)/ge;
      }; # for old buggy version of Perl ("Malformed UTF-8" fatal warning)
    } else {
      eval {
        $v =~ s/([^\x20-\x5B\x5D-\x7E])/ord $1 > 0xFF ? sprintf '\x{%04X}', ord $1 : sprintf '\x%02X', ord $1/ge;
      }; # for old buggy version of Perl ("Malformed UTF-8" fatal warning)
    }
    return $v;
  } else { # asis
    return $_[0];
  }
}

sub carp (@) {
  my $location = Carp::shortmess;
  $location =~ s/^\s*at\s*//;
  my $line = 0;
  if ($location =~ s/\s*line\s*(\d+)\.?\s*$//) {
    $line = $1;
  }
  if ($Colored) {
    print STDERR map { s/((?:\t|^)[^:]+)/with_color 'green', $1/ge; $_ } @_;
    print STDERR Term::ANSIColor::color ('white');
  } else {
    print STDERR @_;
  }
  print STDERR "\tcaller_file_name:" . _ltsv_escape $location;
  print STDERR "\tcaller_line:$line";
  print STDERR Term::ANSIColor::color ('reset') if $Colored;
  print STDERR "\n";
} # carp

our $SQLCount ||= 0;

$Carp::CarpInternal{+__PACKAGE__} = 1;

my $orig_connect = \&DBI::connect;
*DBI::connect = sub {
  my $time = [Time::HiRes::gettimeofday];

  my $return = $orig_connect->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  if ($WARN) {
    carp with_color 'bright_black', sprintf "time:%.2f\tsql:%s",
        $tv * 1000, _ltsv_escape $_[1];
  }
  return $return;
}; # DBI::connect

my $BoundParams = {};

my $orig_execute = \&DBI::st::execute;
*DBI::st::execute = sub {
  my ($sth, @binds) = @_;
  my $time = [Time::HiRes::gettimeofday];

  my $return = $orig_execute->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  my $sql = $sth->{Database}->{Statement};
  if (@binds == 0 and $BoundParams->{$sth}) {
    @binds = @{$BoundParams->{$sth}};
    delete $BoundParams->{$sth};
  }
  my $bind = @binds
      ? '(' . join (', ', map { defined $_ ? $_ : '(undef)' } @binds) . ')'
      : '';

  $SQLCount++ if $COUNT;
  $sql = _ltsv_escape $sql;
  if ($Colored) {
    $sql =~ s/((?:[Ff][Rr][Oo][Mm]|[Ii][Nn][Tt][Oo]|^[Uu][Pp][Dd][Aa][Tt][Ee])\s*)(\S+)/$1 . with_color 'blue', $2/ge;
  }
  carp sprintf "time:%.2f\tsql:%s\tsql_binds:%s\trows:%d",
      $tv * 1000, $sql, _ltsv_escape $bind, $_[0]->rows if $WARN;
  return $return;
}; # DBI::st::execute

my $orig_bind_param = \&DBI::st::bind_param;
*DBI::st::bind_param = sub {
  my ($sth, $i, $value, @args) = @_;

  my $return = $orig_bind_param->(@_);

  $BoundParams->{$sth}->[$i-1] = $value;

  return $return;
}; # DBI::st::bind_param

my $orig_do = \&DBI::db::do;
*DBI::db::do = sub {
  #my ($sth, $sql, undef, @binds) = @_;
  my $time = [Time::HiRes::gettimeofday];

  my $return = $orig_do->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  my $bind = @_ > 3
      ? '(' . join (', ', map { defined $_ ? $_ : '(undef)' } @_[3..$#_]) . ')'
      : '';

  $SQLCount++ if $COUNT;
  carp sprintf "time:%.2f\tsql:%s\tsql_binds:%s\trows:%d",
      $tv * 1000, _ltsv_escape $_[1], _ltsv_escape $bind, $return if $WARN;
  return $return;
}; # DBI::db::do

my $orig_begin_work = \&DBI::db::begin_work;
*DBI::db::begin_work = sub {
  my $time = [Time::HiRes::gettimeofday];
  
  my $return = $orig_begin_work->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  carp sprintf "time:%.2f\toperation_class:DBI\toperation_method:begin_work",
      $tv * 1000 if $WARN;
  return $return;
}; # DBI::db::begin_work

my $orig_commit = \&DBI::db::commit;
*DBI::db::commit = sub {
  my $time = [Time::HiRes::gettimeofday];
  
  my $return = $orig_commit->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  carp sprintf "time:%.2f\toperation_class:DBI\toperation_method:commit",
      $tv * 1000 if $WARN;
  return $return;
}; # DBI::db::commit

my $orig_rollback = \&DBI::db::rollback;
*DBI::db::rollback = sub {
  my $time = [Time::HiRes::gettimeofday];
  
  my $return = $orig_rollback->(@_);

  my $tv = Time::HiRes::tv_interval ($time);
  carp sprintf "time:%.2f\toperation_class:DBI\toperation_method:rollback",
      $tv * 1000 if $WARN;
  return $return;
}; # DBI::db::rollback

=head1 AUTHOR

Wakaba <wakaba@suikawiki.org>.

=head1 LICENSE

Public Domain.

=cut

1;
