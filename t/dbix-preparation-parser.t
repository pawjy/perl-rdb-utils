use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->subdir('t_deps', 'modules', '*', 'lib');
use Test::X1;
use Test::More;
use DBIx::Preparation::Parser;

test {
    my $c = shift;
    my $parser = DBIx::Preparation::Parser->new;
    my @op = $parser->parse_char_string('');
    is_deeply \@op, [];
    done $c;
} n => 1, name => 'parse_char_string empty';

test {
    my $c = shift;
    my $parser = DBIx::Preparation::Parser->new;
    my @op = $parser->parse_char_string('
        db hoge
        db fuga
    ');
    is_deeply \@op, [
        {type => 'create database', name => 'hoge'},
        {type => 'create database', name => 'fuga'},
    ];
    done $c;
} n => 1, name => 'parse_char_string dbs';

run_tests;
