use strict;
BEGIN {
  my $file_name = __FILE__; $file_name =~ s{[^/]+$}{}; $file_name ||= '.';
  unshift @INC, glob "$file_name/../t_deps/modules/*/lib";
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

  my $create = Test::AnyEvent::MySQL::CreateDatabase->new;
  my $json_f = $create->json_f;
  like $json_f->stringify, qr{\.json$};
  my $cv = $create->prep_f_to_cv($prep_f);
  $cv->cb(sub {
    my $obj = $_[0]->recv;
    test {
      my $json = file2perl $obj->json_f;
      is $obj->json_f, $json_f;
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
} n => 4, name => 'file';

test {
  my $c = shift;

  my $create = Test::AnyEvent::MySQL::CreateDatabase->new;
  my $json_f = $create->json_f;
  like $json_f->stringify, qr{\.json$};
  my $cv = $create->prep_text_to_cv(q{db testdb1
      table } . $data_d->file('testdb1.sql')->absolute);
  $cv->cb(sub {
    my $obj = $_[0]->recv;
    test {
      my $json = file2perl $obj->json_f;
      is $obj->json_f, $json_f;
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
} n => 4, name => 'text';

run_tests;
