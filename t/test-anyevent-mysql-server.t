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

test {
    my $c = shift;
    my $cv = AE::cv;
    $cv->begin;
    my $server = Test::AnyEvent::MySQL::Server->new;
    $cv->begin;
    $server->create_database_as_cv('hoge')->cb(sub {
        my $result = $_[0]->recv;
        test {
            ok !$result->error;
            my $dsn = $result->data;
            like $dsn, qr{dbname=db1_hoge_test;};
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
        my $result = $_[0]->recv;
        test {
            ok !$result->error;
            ok $pid = $result->data;
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

my $data_d = file(__FILE__)->dir->subdir('data');

test {
    my $c = shift;
    
    my $server = Test::AnyEvent::MySQL::Server->new;
    my $prep_f = $data_d->file('testdb1-preparation.txt');
    $server->process_prep_f_as_cv($prep_f)->cb(sub {
        my $result = $_[0]->recv;
        test {
            ok !$result->error;
            my $json = $result->data;
            my $dsn = $json->{dsns}->{testdb1};
            my $dbh = DBI->connect($dsn);
            
            $dbh->prepare('insert into hoge (id, created) value (12, "2012-05-01 12:44:11")')->execute;
            my $sth = $dbh->prepare('select * from hoge');
            $sth->execute;
            is_deeply $sth->fetchrow_hashref, {id => 12, created => '2012-05-01 12:44:11'};
            done $c;
            undef $c;
            undef $server;
        } $c;
    });
} n => 2, name => 'file';

run_tests;
