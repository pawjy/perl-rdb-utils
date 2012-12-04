package Test::AnyEvent::MySQL::Server;
use strict;
use warnings;
use AnyEvent;
use AnyEvent::Worker;
require DBIx::ShowSQL if $ENV{SQL_DEBUG};

sub new {
    return bless {}, $_[0];
}

sub worker {
    return $_[0]->{worker} ||= do {
        my $w = AnyEvent::Worker->new({
            class => 'Test::AnyEvent::MySQL::Server::Worker',
            new => 'new',
        }, on_error => sub {
            my ($worker, $error, $fatal, $file, $line) = @_;
            die "$error at $file line $line" if $fatal;
            warn "$error at $file line $line";
        });
        $w->do('install_signal_handlers', sub { });
        $w;
    };
}

sub get_pid_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    $self->worker->do('get_pid', sub { $cv->send($_[1]) });
    return $cv;
}

sub db_set_index {
    return $_[0]->{db_set_index} ||= 1;
}

sub get_db_name {
    return sprintf 'db%d_%s_test',
        $_[0]->db_set_index,
        $_[1];
}

sub create_database_as_cv {
    my ($self, $dbname) = @_;
    my $cv = AE::cv;
    $self->worker->do('create_database', $self->get_db_name($dbname), sub {
        $cv->send($_[1]);
    });
    return $cv;
}

package Test::AnyEvent::MySQL::Server::Worker;

sub new {
    return bless {}, $_[0];
}

sub mysqld {
    require Test::MySQL::CreateDatabase;
    return Test::MySQL::CreateDatabase::mysqld();
}

sub get_dbh {
    require DBI;
    return $_[0]->{dbh}->{$_[1]} ||= DBI->connect($_[1], undef, undef, {RaiseError => 1, PrintError => 0});
}

sub get_dsn {
    return $_[0]->mysqld->dsn(dbname => $_[1])
}

sub get_pid {
    return $_[0]->mysqld->pid;
}

sub create_database {
    my $dbh = $_[0]->get_dbh($_[0]->get_dsn('mysql'));
    my $sth = $dbh->prepare(sprintf 'CREATE DATABASE %s', $dbh->quote_identifier($_[1]));
    $sth->execute;
    die "Can't create database" unless $sth->rows > 0;
    return $_[0]->get_dsn($_[1]);
}

sub install_signal_handlers {
    my $self = shift;
    $SIG{INT} = $SIG{QUIT} = $SIG{TERM} = sub {
        $self->mysqld->stop;
        exit;
    };
}

1;
