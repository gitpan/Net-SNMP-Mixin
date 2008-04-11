#!perl

use strict;
use warnings;
use Test::More;

eval "use Net::SNMP";
plan skip_all => "Net::SNMP required for testing Net::SNMP::Mixin" if $@;

plan tests => 7;
#plan 'no_plan';

use_ok('Net::SNMP::Mixin');

my ( $session1, $error1 ) = Net::SNMP->session( hostname => '0.0.0.0', );

ok( !$error1, 'no snmp session' );
isa_ok( $session1, 'Net::SNMP' );

eval {$session1->mixer("Net::SNMP::Mixin::System")};
is( $@, '', 'Net::SNMP::Mixin::System mixed in successful' );
ok( $session1->can('get_system_group'), '$session1 can get_system_group' );

# try to mixin twice
eval {$session1->mixer("Net::SNMP::Mixin::System")};
like( $@, qr/already mixed into/, 'mixed in twice is an error' );

# try to mixin a non existent module
eval {$session1->mixer("Net::SNMP::Mixin::mixin_does_not_exist")};
like( $@, qr/Can't locate/i, 'try to mixin a non existent module' );

# vim: ft=perl sw=2
