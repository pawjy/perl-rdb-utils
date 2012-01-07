package AnyEvent::DBI::Hashref;
our $VERSION = '1.0';

package AnyEvent::DBI;
use strict;
use warnings;
use AnyEvent::DBI;

for my $cmd_name (qw(exec_as_hashref exec_or_fatal_as_hashref)) {
  eval 'sub ' . $cmd_name . '{
    my $cb = pop;
    splice @_, 1, 0, $cb, (caller)[1,2], "req_' . $cmd_name . '";
    &_req
  }';
}

our $DBH;

sub req_exec_as_hashref {
  my (undef, $st, @args) = @{+shift};
   my $sth = $DBH->prepare_cached ($st, undef, 1)
       or die [$DBI::errstr];

   my $rv = $sth->execute (@args)
       or die [$sth->errstr];

   [1, $sth->{NUM_OF_FIELDS} ? $sth->fetchall_arrayref(+{}) : undef, $rv]
}

sub req_exec_or_fatal_as_hashref {
  my (undef, $st, @args) = @{+shift};
   my $sth = $DBH->prepare_cached ($st, undef, 1)
       or do { my $str = $DBI::errstr; $DBH->disconnect; die [$str, 1] };

   my $rv = $sth->execute (@args)
      or do { my $str = $sth->errstr; $DBH->disconnect; die [$str, 1] };

   [1, $sth->{NUM_OF_FIELDS} ? $sth->fetchall_arrayref(+{}) : undef, $rv]
}

1;

=head1 NAME

AnyEvent::DBI::Hashref - exec_hashref method for AnyEvent::DBI

=head1 SYNOPSIS

  use AnyEvent::DBI::Hashref;
  my $dbh = AnyEvent::DBI->new (...);
  $dbh->exec_as_hashref ('select * from hoge limit 1', sub {
    my ($dbh, $rows, $rv) = @_;
    if ($rows) {
      warn $rows->[0]->{id}, $rows->[0]->{value};
    }
  });
  ...

=head1 DESCRIPTION

The C<AnyEvent::DBI::Hashref> module defines two additional methods to
L<AnyEvent::DBI>: C<exec_as_hashref>, which behaves like
C<fetchall_arrayref(+{})> as the C<exec> method behaves like
C<fetchall_arrayref()>, and C<req_exec_or_fatal_as_hashref>, which, in
addition, handles any SQL execution error as fatal error such that
subsequent (queued) SQL requests are also result in fatal errors.

=head1 SEE ALSO

L<AnyEvent::DBI>.

=head1 ACKNOWLEDGEMENTS

This module contains codes from the L<AnyEvent::DBI> module, whose
authors are: Marc Lehmann <schmorp@schmorp.de> and Adam Rosenstein
<adam@redcondor.com>.

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

This module is licensed under the same terms as perl itself.

=cut
