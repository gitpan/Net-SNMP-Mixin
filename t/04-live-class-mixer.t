#!perl

use strict;
use warnings;
use Test::More;
use Module::Build;

eval "use Net::SNMP";
plan skip_all => "Net::SNMP required for testing Net::SNMP::Mixin" if $@;

plan tests => 10;
#plan 'no_plan';

use_ok('Net::SNMP::Mixin');
is( Net::SNMP->mixer('Net::SNMP::Mixin::System'),
  'Net::SNMP', 'mixer returns the class name' );

my $builder        = Module::Build->current;
my $snmp_agent     = $builder->notes('snmp_agent');
my $snmp_community = $builder->notes('snmp_community');
my $snmp_version   = $builder->notes('snmp_version');

SKIP: {
  skip '-> no live tests', 8, unless $snmp_agent;

  my ( $session, $error ) = Net::SNMP->session(
    hostname  => $snmp_agent,
    community => $snmp_community || 'public',
    version   => '2c' || $snmp_version
  );

  ok( !$error, 'got snmp session for live tests' );
  isa_ok( $session, 'Net::SNMP' );
  ok( $session->can('get_system_group'), 'can $session->get_system_group' );

  eval { $session->init_mixins };
  ok( !$@, 'init_mixins successful' );

  eval { $session->init_mixins(1) };
  ok( !$@, 'already initalized but reload forced' );

  eval { $session->init_mixins };
  like(
    $@,
    qr/already initalized and reload not forced/i,
    'already initalized and reload not forced'
  );

  eval { Net::SNMP->init_mixins };
  like(
    $@,
    qr/pure instance method called as class method/i,
    'pure instance method called as class method'
  );

  my $system_group;
  eval { $system_group = $session->get_system_group };
  ok( !$@, 'get_system_group' );
}

# vim: ft=perl sw=2
