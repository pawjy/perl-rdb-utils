package Test::AnyEvent::MySQL::Server;
use strict;
use warnings;
use AnyEvent;
use AnyEvent::Worker;
use JSON::Functions::XS qw(perl2json_bytes);
require DBIx::ShowSQL if $ENV{SQL_DEBUG};

sub new {
    return bless {db_set_index => 1}, $_[0];
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
    $self->worker->do('get_pid', sub {
        $cv->send(Test::AnyEvent::MySQL::Server::Result->new(data => $_[1], error => $@));
    });
    return $cv;
}

sub db_set_index {
    return $_[0]->{db_set_index};
}

sub reset_db_set_index {
    $_[0]->{db_set_index}++;
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
        $cv->send(Test::AnyEvent::MySQL::Server::Result->new(data => $_[1], error => $@));
    });
    return $cv;
}

sub process_prep_f_as_cv {
    my ($self, $f) = @_;
    my $cv = AE::cv;
    unless (-f $f) {
        $cv->send(Test::AnyEvent::MySQL::Server::Result->new(error => "$f not found"));
        return $cv;
    }
    $self->worker->do('process_prep', $f->resolve->stringify, $self->db_set_index, sub {
        $cv->send(Test::AnyEvent::MySQL::Server::Result->new(data => $_[1], error => $@));
    });
    return $cv;
}

sub prep_f_to_dsns_json_as_cv {
    my ($self, $f => $g, %args) = @_;
    my $cv = AE::cv;
    $self->process_prep_f_as_cv($f)->cb(sub {
        my $result = $_[0]->recv;
        #warn $result->error;
        unless ($result->error) {
            my $json = $result->data;
            if ($args{dup_master_defs}) {
                $json->{alt_dsns}->{master} = $json->{dsns};
            }
            $g->dir->mkpath;
            my $gh = $g->openw;
            my $w; $w = AE::io $gh, 1, sub {
                print $gh perl2json_bytes $json;
                undef $w;
            };
        }
        $cv->send($result);
    });
    return $cv;
}

sub stop_as_cv {
    my $cv = AE::cv;
    delete $_[0]->{worker};
    $cv->send(Test::AnyEvent::MySQL::Server::Result->new);
    return $cv;
}

sub DESTROY {
    $_[0]->stop_as_cv;
}

package Test::AnyEvent::MySQL::Server::Result;

sub new {
    my $class = shift;
    return bless {@_}, $class;
}

sub data {
    return $_[0]->{data};
}

sub error {
    return $_[0]->{error};
}

package Test::AnyEvent::MySQL::Server::Worker;
use Path::Class;

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

sub process_prep {
    my ($self, $file_name, $db_set_index) = @_;
    my $dsns = {};
    require DBIx::Preparation::Parser;
    my $parser = DBIx::Preparation::Parser->new;
    my $last_db_name;
    for my $op ($parser->parse_f(file($file_name))) {
        if ($op->{type} eq 'create database') {
            my $name = sprintf 'db%d_%s_test', $db_set_index, $op->{name};
            my $dsn = $self->create_database($name);
            $dsns->{$op->{name}} = $dsn;
            $last_db_name = $name;
            #warn "CREATE DATABASE $op->{name}\n";
        } elsif ($op->{type} eq 'use database') {
            my $name = sprintf 'db%d_%s_test', $db_set_index, $op->{name};
            $last_db_name = $name;
            #warn "USE $op->{name}\n";
        } elsif ($op->{type} eq 'create table') {
            die "Database is not created before CREATE TABLE"
                unless defined $last_db_name;
            my $dbh = $self->get_dbh($self->get_dsn($last_db_name));
            Test::MySQL::CreateDatabase::copy_schema_from_file
                    ($op->{f} => $dbh);
            #warn "Load CREATE TABLEs from @{[$op->{f}->relative]}\n";
        } elsif ($op->{type} eq 'insert') {
            die "Database is not created before INSERT"
                unless defined $last_db_name;
            my $dbh = $self->get_dbh($self->get_dsn($last_db_name));
            Test::MySQL::CreateDatabase::execute_inserts_from_file
                    ($op->{f} => $dbh);
            #warn "Load INSERTs from @{[$op->{f}->relative]}\n";
        } elsif ($op->{type} eq 'alter table') {
            die "Database is not created before ALTER TABLE"
                unless defined $last_db_name;
            my $dbh = $self->get_dbh($self->get_dsn($last_db_name));
            Test::MySQL::CreateDatabase::execute_alter_tables_from_file
                    ($op->{f} => $dbh);
            #warn "Load ALTER TABLEs from @{[$op->{f}->relative]}\n";
        } elsif ($op->{type} eq 'sql') {
            die "Database is not created before SQL execution"
                unless defined $last_db_name;
            my $dbh = $self->get_dbh($self->get_dsn($last_db_name));
            $dbh->prepare($op->{value})->execute;
            my $v = substr $op->{value}, 0, 50;
            $v .= '...' if $v ne $op->{value};
            $v =~ s/\x0A/ /g;
            #warn "SQL: $v\n";
        } else {
            die "Operation |$op->{type}| is not supported";
        }
    }
    return {dsns => $dsns};
}

sub install_signal_handlers {
    my $self = shift;
    $SIG{INT} = $SIG{QUIT} = $SIG{TERM} = sub {
        $self->mysqld->stop;
        exit;
    };
}

1;
