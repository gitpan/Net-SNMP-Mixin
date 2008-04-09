package Net::SNMP::Mixin::System;

use 5.006;
use warnings;
use strict;

# store this package name in a handy variable,
# used for unambiguous prefix of mixin attributes
# storage in object hash
#
my $prefix = __PACKAGE__;

# this module import config
#
use Carp ();

# normally needed utils, but not for this simple blueprint mixin.
# Please see the other mixins in Net::SNMP::Mixin::...
#use Net::SNMP::Mixin::Util qw/idx2val/;

# this module export config
#
my @mixin_methods;

BEGIN {
  @mixin_methods = ( qw/get_system_group/);
}

use Sub::Exporter -setup => {
  exports   => [@mixin_methods],
  groups    => { default => [@mixin_methods], },
};

# SNMP oid constants used in this module
#
use constant {
  SYS_DESCR          => '1.3.6.1.2.1.1.1.0',
  SYS_OBJECT_ID      => '1.3.6.1.2.1.1.2.0',
  SYS_UP_TIME        => '1.3.6.1.2.1.1.3.0',
  SYS_CONTACT        => '1.3.6.1.2.1.1.4.0',
  SYS_NAME           => '1.3.6.1.2.1.1.5.0',
  SYS_LOCATION       => '1.3.6.1.2.1.1.6.0',
  SYS_SERVICES       => '1.3.6.1.2.1.1.7.0',
};

=head1 NAME

Net::SNMP::Mixin::System - mixin class for the mib-2 system-group values

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

A Net::SNMP mixin class for mib-II system-group info. It's just in the distribution to act as a blueprint for mixin authors.

  use Net::SNMP;
  use Net::SNMP::Mixin qw/mixer init_mixins/;

  my $session = Net::SNMP->session( -hostname => 'foo.bar.com' );

  $session->mixer('Net::SNMP::Mixin::System');
  $session->init_mixins;
  snmp_dispatcher() if $session->nonblocking;

  die $session->error if $session->error;

  my $system_group = $session->get_system_group;

  printf "Name: %s, Contact: %s, Location: %s\n",
    $system_group->{sysName},
    $system_group->{sysContact},
    $system_group->{sysLocation};

=head1 MIXIN METHODS

=head2 B<< OBJ->get_system_group() >>

Returns the mib-II system-group as a hash reference:

  {
    sysDescr        => DisplayString,
    sysObjectID     => OBJECT_IDENTIFIER,
    sysUpTime       => TimeTicks,
    sysContact      => DisplayString,
    sysName         => DisplayString,
    sysLocation     => DisplayString,
    sysServices     => INTEGER,
  }

=cut

sub get_system_group {
  my $session = shift;
  Carp::croak "'$prefix' not initialized,"
    unless $session->{$prefix}{__initialized};

  my $result = {};

  $result->{sysDescr}        = $session->{$prefix}{sysDescr};
  $result->{sysObjectID}     = $session->{$prefix}{sysObjectID};
  $result->{sysUpTime}       = $session->{$prefix}{sysUpTime};
  $result->{sysContact}      = $session->{$prefix}{sysContact};
  $result->{sysName}         = $session->{$prefix}{sysName};
  $result->{sysLocation}     = $session->{$prefix}{sysLocation};
  $result->{sysServices}     = $session->{$prefix}{sysServices};

  return $result;
}

=head1 INITIALIZATION

=cut

=head2 B<< OBJ->_init($reload) >>

Fetch the SNMP mib-II system-group values from the host. Don't call this method direct!

=cut

sub _init {
  my ($session, $reload) = @_;

  die "$prefix already initalized and reload not forced.\n"
  	if $session->{$prefix}{__initialized} && not $reload;

  # initialize the object system-group infos
  _fetch_system_group($session);
  return if $session->error;

  return 1;
}

=head1 PRIVATE METHODS

Only for developers or maintainers.

=head2 B<< _fetch_system_group($session) >>

Fetch values from the system-group once during object initialization.

=cut

sub _fetch_system_group {
  my $session = shift;
  my $result;

  # fetch the mib-II system-group
  $result = $session->get_request(
    -varbindlist => [

      SYS_DESCR,
      SYS_OBJECT_ID,
      SYS_UP_TIME,
      SYS_CONTACT,
      SYS_NAME,
      SYS_LOCATION,
      SYS_SERVICES,
    ],

    # define callback if in nonblocking mode
    $session->nonblocking ? ( -callback => \&_system_group_cb ) : (),
  );

  return unless defined $result;
  return 1 if $session->nonblocking;

  # call the callback function in blocking mode by hand
  _system_group_cb($session);

}

=head2 B<< _system_group_cb($session) >>

The callback for _fetch_system_group.

=cut

sub _system_group_cb {
  my $session = shift;
  my $vbl     = $session->var_bind_list;

  return unless defined $vbl;

  $session->{$prefix}{sysDescr}        = $vbl->{ SYS_DESCR() };
  $session->{$prefix}{sysObjectID}     = $vbl->{ SYS_OBJECT_ID() };
  $session->{$prefix}{sysUpTime}       = $vbl->{ SYS_UP_TIME() };
  $session->{$prefix}{sysContact}      = $vbl->{ SYS_CONTACT() };
  $session->{$prefix}{sysName}         = $vbl->{ SYS_NAME() };
  $session->{$prefix}{sysLocation}     = $vbl->{ SYS_LOCATION() };
  $session->{$prefix}{sysServices}     = $vbl->{ SYS_SERVICES() };

  $session->{$prefix}{__initialized}++;
}

unless ( caller() ) {
  print "$prefix compiles and initializes successful.\n";
}

=head1 BUGS

Please report any bugs or feature requests to
C<bug-net-snmp-mixin-system at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-SNMP-Mixin>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::SNMP::Mixin::System

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-SNMP-Mixin>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-SNMP-Mixin>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-SNMP-Mixin>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-SNMP-Mixin>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Karl Gaissmaier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

# vim: sw=2
