#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
BEGIN { require "t/utils.pl" }
our (@available_drivers);

use constant TESTS_PER_DRIVER => 86;

my $total = scalar(@available_drivers) * TESTS_PER_DRIVER;
plan tests => $total;

my @true  = qw/1 t true y yes TRUE/;
my @false = qw/0 f false n no FALSE/;

foreach my $d (@available_drivers) {
SKIP: {
    unless (has_schema('TestApp::User', $d)) {
        skip "No schema for '$d' driver", TESTS_PER_DRIVER;
    }

    unless (should_test($d)) {
        skip "ENV is not defined for driver '$d'", TESTS_PER_DRIVER;
    }

    diag("start testing with '$d' handle") if $ENV{TEST_VERBOSE};

    my $handle = get_handle($d);
    connect_handle($handle);
    isa_ok($handle->dbh, 'DBI::db');

    {
        my $ret = init_schema('TestApp::User', $handle);
        isa_ok($ret, 'DBI::st', 'init schema');
    }

    my @values = (
        ( map { [$_, 'true']  } @true  ),
        ( map { [$_, 'false'] } @false ),
    );

    for my $value ( @values ) {
        my ($input, $bool) = @$value;

        my $rec = TestApp::User->new( handle => $handle );
        isa_ok($rec, 'Jifty::DBI::Record');

        my ($id) = $rec->create( my_data => $input );
        ok($id, 'created record');
        ok($rec->load($id), 'loaded record');
        is($rec->id, $id, 'record id matches');

        ok($bool eq 'true' ? $rec->my_data : !$rec->my_data, 'Perl agrees with the expected boolean value');
        my $sth = $handle->simple_query("SELECT my_data FROM users WHERE id = $id");
        my ($got) = $sth->fetchrow_array;

        my $method = "canonical_$bool";
        is( $got, $handle->$method, 'my_data bool match' );

        # undef/NULL
        $rec->set_my_data;
        is($rec->my_data, undef, 'set undef value');
    }

    cleanup_schema('TestApp', $handle);
    disconnect_handle($handle);
}
}

package TestApp::User;
use base qw/ Jifty::DBI::Record /;

1;

sub schema_sqlite {

<<EOF;
CREATE table users (
    id integer primary key,
    my_data boolean
)
EOF

}

sub schema_mysql {

<<EOF;
CREATE TEMPORARY table users (
    id integer auto_increment primary key,
    my_data boolean
)
EOF

}

sub schema_pg {

<<EOF;
CREATE TEMPORARY table users (
    id serial primary key,
    my_data boolean
)
EOF

}

BEGIN {
    use Jifty::DBI::Schema;

    use Jifty::DBI::Record schema {
    column my_data =>
        is boolean;
    }
}


