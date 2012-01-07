package AnyEvent::DBI::Carp;
use strict;
use warnings;
our $VERSION = '1.0';
use base qw(AnyEvent::DBI);
use Carp;

for my $cmd_name (
  qw(exec attr begin_work commit rollback func), # AnyEvent::DBI
  qw(exec_as_hashref exec_or_fatal_as_hashref),  # AnyEvent::DBI::Hashref
) {
  eval 'sub ' . $cmd_name . '{
    my $cb = pop;

    my $i = Carp::short_error_loc() || Carp::long_error_loc();
    my %caller = Carp::caller_info $i;

    splice
        @_, 1, 0, $cb,
            #(caller)[1,2],
            $caller{file}, $caller{line},
        "req_' . $cmd_name . '";
    &AnyEvent::DBI::_req
  }';
}

1;

=head1 NAME

AnyEvent::DBI::Carp - A subclass of AnyEvent::DBI using Carp to detect error location

=head1 SYNOPSIS

  use AnyEvent::DBI::Carp;
  my $dbh = AnyEvent::DBI::Carp->new (..., on_error => sub {
    my ($dbh, $filename, $line, $fatal) = @_;
    warn "$filename line $line\n";
  });
  
  #line 1 "foo"
  sub foo () {
    $dbh->exec (...);
  }
  ...
  #line 1 "main"
  foo(); # => main line 1

=head1 DESCRIPTION

The C<AnyEvent::DBI::Carp> module defines a subclass of
L<AnyEvent::DBI> whoes C<on_error> callback detects the location of
the error by invoking functions from the L<Carp> module.

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
