#!/usr/bin/perl
use strict;
BEGIN {
    require Config;
    my $file_name = __FILE__; $file_name =~ s{[^/\\]+$}{}; $file_name ||= '.';
    my $fn = $file_name . sprintf '/../local/config/perl/libs-%vd-%s.txt',
        $^V, $Config::Config{archname};
    $fn = $file_name . '/../config/perl/libs.txt' unless -f $file_name;
    if (-f $fn) {
        open my $file, '<', $fn or die "$0: $fn: $!";
        my $paths = <$file>; chomp $paths;
        unshift @INC, split /:/, $paths;
    }
}
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use lib glob file(__FILE__)->dir->parent->parent->subdir('*', 'lib')->stringify;
use Getopt::Long;
use JSON::Functions::XS qw(file2perl perl2json_bytes);
use Test::MySQL::CreateDatabase qw(
    mysqld test_dsn dsn2dbh copy_schema_from_file execute_inserts_from_file
    extract_schema_sql_from_file execute_alter_tables_from_file
);
use DBIx::Preparation::Parser;

my $list_file_name;
my $debug_log_file_name;
my @operation;
my $preparation_files = {};
my @insert;
my @modules_d;
my $stop;
sub process_preparation_file ($);
GetOptions(
    'create-database=s' => sub {
        push @operation, {type => 'create database', name => $_[1]};
    },
    'use-database=s' => sub {
        push @operation, {type => 'use database', name => $_[1]};
    },
    'create-table-file-name=s' => sub {
        push @operation, {type => 'create table', f => file($_[1])};
    },
    'insert-file-name=s' => sub {
        push @operation, {type => 'insert', f => file($_[1])};
    },
    'preparation-file-name=s' => sub {
        process_preparation_file file($_[1])->absolute->realpath;
    },
    'dsn-list=s' => \$list_file_name,
    'debug-log-file-name=s' => \$debug_log_file_name,
    'modules-dir-name=s' => sub {
        push @modules_d, dir($_[1])->absolute->realpath;
    },
    'stop' => \$stop,
) or die;
die unless $list_file_name;

use Cwd qw(abs_path);
sub Path::Class::Entity::realpath {
    my $self = shift;
    my $cleaned = $self->new((abs_path $self) || $self);
    %$self = %$cleaned;
    return $self;
}

my $Parser;
sub process_preparation_file ($) {
    my $f = shift;
    $Parser ||= DBIx::Preparation::Parser->new;
    push @operation, $Parser->parse_f($f, modules_d => \@modules_d);
}

my $debug_log_file;
my $debug_log_f;

sub initdebug () {
    $debug_log_file = $debug_log_f->open('>>')
        or die "$debug_log_file_name: $!";
    binmode $debug_log_file, ':encoding(utf-8)';
    $debug_log_file->autoflush(1);
}

sub debuglog (@) {
    return unless $debug_log_file;
    print $debug_log_file join ' ', '[' . (scalar localtime) . ']', $$, @_, "\n";
}

if ($debug_log_file_name) {
    $debug_log_f = file($debug_log_file_name)->absolute->realpath;
    initdebug;
} elsif ($ENV{TEST_MYSQLD_DEBUG}) {
    $debug_log_file = \*STDERR;
}

my $json = {};
my $list_f = file($list_file_name)->absolute->realpath;
if (-f $list_f) {
    $json = file2perl $list_f;
    debuglog 'File opened', $list_file_name;
}

if ($json->{pid}) {
    my $killed = kill 15, $json->{pid}; # SIGTERM
    debuglog 'Killed process', $json->{pid}, $killed;

    if (-d $json->{dir_name}) {
        dir($json->{dir_name})->rmtree;
        debuglog 'Removed temporary directory', $json->{dir_name};
    }
}

if ($stop) {
    if (-f $list_f) {
        unlink $list_f->stringify;
        debuglog 'File removed', $list_f;
    }
    exit;
}

local $ENV{TEST_MYSQLD_PRESERVE} = 1;

my $last_dbh;
my $dsns = {};
my $dbhs = {};
while (my $op = shift @operation) {
    if ($op->{type} eq 'create database') {
        my $dsn = test_dsn $op->{name};
        $last_dbh = dsn2dbh $dsn;
        $dsns->{$op->{name}} = $dsn;
        $dbhs = {$op->{name} => $last_dbh};
        warn "CREATE DATABASE $op->{name}\n";
    } elsif ($op->{type} eq 'use database') {
        $last_dbh = $dbhs->{$op->{name}} || dsn2dbh $dsns->{$op->{name}};
        $dbhs = {$op->name => $last_dbh};
        warn "USE $op->{name}\n";
    } elsif ($op->{type} eq 'create db and table') {
        my $subops = extract_schema_sql_from_file $op->{f};
        warn "Load CREATEs from @{[$op->{f}->relative]}\n";
        my @newop;
        for (@$subops) {
            if (/^CREATE DATABASE (?:IF NOT EXISTS )?(\S+)$/) {
                push @newop, {type => 'create database', name => $1};
                push @newop, {type => 'use database', name => $1};
            } elsif (/^CREATE TABLE / or /^INSERT /) {
                push @newop, {type => 'sql', value => $_};
            } else {
                die "Operation |$_| is not supported\n";
            }
        }
        unshift @operation, @newop;
    } elsif ($op->{type} eq 'create table') {
        die "Database is not created before CREATE TABLE" unless $last_dbh;
        copy_schema_from_file $op->{f} => $last_dbh;
        warn "Load CREATE TABLEs from @{[$op->{f}->relative]}\n";
    } elsif ($op->{type} eq 'insert') {
        die "Database is not created before INSERT" unless $last_dbh;
        execute_inserts_from_file $op->{f} => $last_dbh;
        warn "Load INSERTs from @{[$op->{f}->relative]}\n";
    } elsif ($op->{type} eq 'alter table') {
        die "Database is not created before ALTER TABLE" unless $last_dbh;
        execute_alter_tables_from_file $op->{f} => $last_dbh;
        warn "Load ALTER TABLEs from @{[$op->{f}->relative]}\n";
    } elsif ($op->{type} eq 'sql') {
        die "Database is not created before SQL execution" unless $last_dbh;
        $last_dbh->prepare($op->{value})->execute;
        my $v = substr $op->{value}, 0, 50;
        $v .= '...' if $v ne $op->{value};
        $v =~ s/\x0A/ /g;
        warn "SQL: $v\n";
    }
}

my $new_json = {
    pid => mysqld->pid,
    dsns => $dsns,
    dir_name => mysqld->base_dir,
};

$list_f->dir->mkpath;
my $list_file = $list_f->openw;
print $list_file perl2json_bytes $new_json;
close $list_file;
debuglog 'Wrote', $list_f;

no warnings 'redefine';
*Test::mysqld::DESTROY = sub { };

__END__

=head1 USAGE

    perl prepare-db-set.pl --dsn-list path/to/json \
        --create-database hoge \
        --create-table-file-name hoge.sql \
        --create-database fuga \
        --create-table-file-name fuga.sql

    my $json = file2perl file('path/to/json');
    for my $key (keys %{$json->{dsns}}) {
        DBIx::RewriteDSN->prepend_rules(
            sprintf q{^dbi:mysql:dbname=%s_test;host=localhost$ %s;password=},
                $key, $json->{dsns}->{$key},
        );
    }

    perl prepare-db-set.pl --dsn-list path/to/json --stop

=head1 AUTHOR

Wakaba (id:wakabatan) <wakabatan@hatena.ne.jp>.

=head1 ACKNOWLEDGEMENTS

Thanks to id:shiba_yu36.

=head1 LICENSE

Copyright 2011-2012 Hatena <http://www.hatena.ne.jp/>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
