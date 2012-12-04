package DBIx::Preparation::Parser;
use strict;
use warnings;
use Path::Class;

sub new {
    return bless {}, $_[0];
}

sub parse_f {
    my ($self, $f, %args) = @_;
    die "$f not found" unless -f $f;
    $f = $f->resolve;

    return () if $self->{processed}->{$f};
    $self->{processed}->{$f} = 1;

    return $self->parse_char_string(
        scalar $f->slurp,
        %args,
        base_d => $f->dir, f => $f,
    );
}

sub parse_char_string {
    my ($self, $string, %args) = @_;
    my $base_d = $args{base_d} || dir('.');
    
    my @operation;
    for (split /\x0D\x0A?|\x0A/, $string) {
        s/#.*$//;
        if (/^\s*db\s+(\S+)\s*$/) {
            push @operation,
                {type => 'create database', name => $1};
        } elsif (/^\s*use\s+db\s+(\S+)\s*$/) {
            push @operation,
                {type => 'use database', name => $1};
        } elsif (/^\s*table\s+(\S+)\s*$/) {
            push @operation,
                {type => 'create table',
                 f => file($1)->absolute($base_d)};
            $operation[-1]->{f} = $operation[-1]->{f}->resolve || $operation[-1]->{f};
            $operation[-1]->{sqls} = [$self->extract_statements_from_f($operation[-1]->{f}, sub { $_[0] =~ /^CREATE\s+TABLE/i })];
        } elsif (/^\s*dbtable\s+(\S+)\s*$/) {
            my $f = file($1)->absolute($base_d);
            $f = $f->resolve || $f;
            for ($self->extract_statements_from_f($f, sub { $_[0] =~ /^CREATE\s+/i })) {
                if (/^CREATE DATABASE (?:IF NOT EXISTS )?(\S+)$/) {
                    push @operation, {type => 'create database', name => $1};
                    push @operation, {type => 'use database', name => $1};
                } elsif (/^CREATE TABLE / or /^INSERT / or /^ALTER TABLE/) {
                    push @operation, {type => 'sql', value => $_};
                } else {
                    die "Operation |$_| is not supported\n";
                }
            }
        } elsif (/^\s*alter\s+table\s+(\S+)\s*$/) {
            push @operation,
                {type => 'alter table',
                 f => file($1)->absolute($base_d)};
            $operation[-1]->{f} = $operation[-1]->{f}->resolve || $operation[-1]->{f};
            $operation[-1]->{sqls} = [$self->extract_statements_from_f($operation[-1]->{f}, sub { $_[0] =~ /^ALTER\s+TABLE/i })];
        } elsif (/^\s*insert\s+(\S+)\s*$/) {
            push @operation,
                {type => 'insert', f => file($1)->absolute($base_d)};
            $operation[-1]->{f} = $operation[-1]->{f}->resolve || $operation[-1]->{f};
            $operation[-1]->{sqls} = [$self->extract_statements_from_f($operation[-1]->{f}, sub { $_[0] =~ /^INSERT/i })];
        } elsif (/^\s*import\s+glob\s+(\S+)\s*$/) {
            for (glob file($1)->absolute($base_d)->stringify) {
                push @operation, $self->parse_f(file($_));
            }
        } elsif (/^\s*import\s+modules\s+(\S+)\s*$/) {
            for (map { glob $_->file($1)->stringify } @{$args{modules_d} or []}) {
                push @operation, $self->parse_f(file($_));
            }
        } elsif (/^\s*import\s+(\S+)\s*$/) {
            push @operation, $self->parse_f(file($1)->absolute($base_d));
        } elsif (/^\s*$/) {
            #
        } else {
            my $f = $args{f} || '(input)';
            die "$f: Syntax error: |$_|\n";
        }
    }
    return @operation;
}

sub extract_statements_from_f {
    my ($self, $f, $filter) = @_;
    my @result;
    my $schema = $f->slurp;
    $schema =~ s/-- .*$//m;
    while ($schema =~ /\b((?:CREATE\s+(?:TABLE|DATABASE)|INSERT|ALTER TABLE).*?);/sgi) {
        push @result, $1 if $filter->($1);
    }
    return @result;
}

1;
