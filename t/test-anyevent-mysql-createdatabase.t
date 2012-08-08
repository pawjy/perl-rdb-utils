use strict;
BEGIN {
  my $file_name = __FILE__; $file_name =~ s{[^/]+$}{}; $file_name ||= '.';
  $file_name . '/../config/perl/libs.txt';
  open my $file, '<', $file_name or die "$0: $file_name: $!";
  unshift @INC, split /:/, <$file>;
}
use warnings;
use Test::X1;
use Test::More;
use Path::Class;
use Test::AnyEvent::MySQL::CreateDatabase;
use DBI;
use JSON::Functions::XS qw(file2perl);

my $data_d = file(__FILE__)->dir->subdir('data');

test {
  my $c = shift;

  my $prep_f = $data_d->file('testdb1-preparation.txt');

  my $cv = Test::AnyEvent::MySQL::CreateDatabase->prep_f_to_cv($prep_f);
  $cv->cb(sub {
    my $obj = $_[0]->recv;
    test {
      my $json = file2perl $obj->json_f;
      my $dsn = $json->{dsns}->{testdb1};
      my $dbh = DBI->connect($dsn);

      $obj->context_begin;
      $obj->context_begin;
      $obj->context_begin;
      $obj->context_end;
      $obj->context_end;
      
      $dbh->prepare('insert into hoge (id, created) value (12, "2012-05-01 12:44:11")')->execute;
      my $sth = $dbh->prepare('select * from hoge');
      $sth->execute;
      is_deeply $sth->fetchrow_hashref, {id => 12, created => '2012-05-01 12:44:11'};

      $obj->context_end(sub {
        undef $obj;

        my $timer; $timer = AE::timer 10, 0, sub {
          test {
            my $result = `ps -o pid,cmd -e | grep $json->{pid} | grep -v grep`;
            ok !$result;
            undef $timer;
            done $c;
          } $c;
        };
      });
    } $c;
  });
};

run_tests;
