use strict;
BEGIN {
  my $file_name = __FILE__; $file_name =~ s{[^/]+$}{}; $file_name ||= '.';
  unshift @INC, glob "$file_name/../t_deps/modules/*/lib";
}
use warnings;
use Test::X1;
use Test::More;
use Path::Class;
use Test::AnyEvent::MySQL::Server;
use DBI;
use AnyEvent;
use AnyEvent::Timer::Retry;
#use DBIx::ShowSQL;

test {
    my $c = shift;
    my $cv = AE::cv;
    $cv->begin;
    my $server = Test::AnyEvent::MySQL::Server->new;
    $cv->begin;
    $server->create_database_as_cv('hoge')->cb(sub {
        my $dsn = $_[0]->recv;
        test {
            ok !$@;
            like $dsn, qr{hoge};
            my $dbh = DBI->connect($dsn, undef, undef, {RaiseError => 1});
            $dbh->prepare('CREATE TABLE `hoge` (id int)')->execute;
            $dbh->prepare('INSERT INTO `hoge` (id) values (1)')->execute;
            my $sth = $dbh->prepare('SELECT * FROM `hoge`');
            $sth->execute;
            is_deeply $sth->fetchall_hashref('id'), {1 => {id => 1}};
            $cv->end;
        } $c;
    });
    $cv->begin;
    my $pid;
    $server->get_pid_as_cv->cb(sub {
        $pid = $_[0]->recv;
        test {
            ok !$@;
            ok $pid;
            $cv->end;
        } $c;
    });
    $cv->end;
    $cv->cb(sub {
        test {
            undef $server;
            my $timer; $timer = AnyEvent::Timer::Retry->new(
                on_retry => sub {
                    my $done = shift;
                    $done->(not kill 0, $pid);
                },
                on_end => sub {
                    my ($result) = @_;
                    test {
                        ok $result;
                        undef $timer;
                        done $c;
                        undef $c;
                    } $c;
                },
            );
        } $c;
    });
} n => 6;

run_tests;
