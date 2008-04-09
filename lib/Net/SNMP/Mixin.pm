package Net::SNMP::Mixin;

use 5.006;
use strict;
use warnings;

=head1 NAME

Net::SNMP::Mixin - mixin framework for Net::SNMP

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 ABSTRACT

Thin framework to access cooked SNMP information from SNMP agents with various mixins to Net::SNMP.

=cut

#
# store this package name in a handy variable,
# used for unique prefix of mixin attributes
# storage in instance hash
#
my $prefix = __PACKAGE__;

#
# this module import config
#
use Carp ();
use Scalar::Util 'refaddr';
use Package::Generator;
use Package::Reaper;

#
# this module export config
#
use Sub::Exporter -setup => {
  into    => 'Net::SNMP',
  exports => [qw/mixer init_mixins/],
  groups  => { default => [qw/mixer init_mixins/] }
};

# needed for housekeeping of already mixed in modules
# in order to find double mixins
our %register_class_mixins;

=head1 SYNOPSIS

  use Net::SNMP;
  use Net::SNMP::Mixin qw(mixer init_mixins);

  my $session = Net::SNMP->session( -hostname => 'example.com' );
  
  # method mixin and initialization
  $session->mixer(qw/Net::SNMP::Mixin::Foo Net::SNMP::Mixin::Bar/);
  $session->init_mixins();
  
  # event_loop for nonblocking sessions
  snmp_dispatcher() if $Net::SNMP::NONBLOCKING;
  die $session->error if $session->error;

  # use mixed-in methods to retrieve cooked SNMP info
  my $a = $session->get_foo_a();
  my $b = $session->get_bar_b();

=head1 DESCRIPTION

Net::SNMP implements already the methods to retrieve raw SNMP values from the agents. With the help of specialized mixins, the access to these raw SNMP values is simplified and necessary calculations on these values are already done for gaining high level information.

This module provides helper functions in order to mixin methods into the inheritance tree of the Net::SNMP session instances or the Net::SNMP class itself.

The standard Net::SNMP get_... methods are still supported and the mixins fetch itself the needed SNMP values during initialization with these standard get_... methods. Blocking and non blocking sessions are supported. The mixins don't change the Net::SNMP session instance, besides storing additional payload in the object space prefixed with the unique mixin module names as the hash key.

=cut

=head1 DEFAULT EXPORTS

The following helper methods are exported by default into the Net::SNMP namespace.

=head2 B<< mixer(@module_names) >>

  # class method
  Net::SNMP->mixer(qw/Net::SNMP::Mixin::Foo/);

  # instance method
  $session->mixer(qw/Net::SNMP::Mixin::Yazz Net::SNMP::Mixin::Brazz/)

Called as class method mixes the methods for all session instances. This is useful for agents supporting the same set of MIBs.

Called as instance method mixes only for the calling session instance. This is useful for SNMP agents not supporting the same set of MIBs and therefore not the same set of mixin modules.

Even the SNMP agents from a big network company don't support the most useful standard MIBs. They always use proprietary private enterprise MIBs (ring, ring, Cisco, do you hear the bells, grrrmmml).

The name of the modules to mix-in is passed to this method as a list. You can mix class and instance mixins as you like, but importing the same mixin module twice is an error.

Returns the invocant for chaining method calls, dies on error.

=cut

sub mixer {
  my ( $self, @mixins ) = @_;

  for my $mixin (@mixins) {

    # check: already mixed-in as class-mixin?
    Carp::croak "$mixin already mixed into class,"
      if defined $register_class_mixins{$mixin};

    # instance- or class-mixin?
    if ( ref $self ) {

      # check: already mixed-in as instance-mixin?
      Carp::croak "$mixin already mixed into instance $self,"
        if defined $self->{$prefix}{mixins}{$mixin};

      _obj_mixer( $self, $mixin );

      # register instance mixins in the object itself
      $self->{$prefix}{mixins}{$mixin}++;
    }
    else {
      _class_mixer( $self, $mixin );

      # register class mixins in a package variable
      $register_class_mixins{$mixin}++;

    }
  }

  return $self;
}

sub _class_mixer {
  my ( $class, $mixin ) = @_;

  eval "use $mixin {into => 'Net::SNMP'}";
  Carp::croak $@ if $@;
}

sub _obj_mixer {
  my ( $session, $mixin )      = @_;
  my ( $package, $pkg_reaper ) = _make_package($session);

  # rebless $session to new subclass of Net::SNMP
  bless $session, $package;

  # When this instance is garbage collected, the $pkg_reaper
  # is DESTROYed and the package is deleted from the symbol table.
  $session->{$prefix}{reaper} = $pkg_reaper if $pkg_reaper;

  eval "use $mixin {into => '$package'}";
  Carp::croak $@ if $@;
}

#
# make unique mixin subclass for this session with name
# Net::SNMP::<refaddr $session> und make it a subclass
# of Net::SNMP. Mix all mixin modules into this only package
# for this session.
#
sub _make_package {
  my $session  = shift;
  my $pkg_name = 'Net::SNMP::__mixin__' . '::' . refaddr $session;

  # already buildt this package for this session object,
  # just return the package name
  return $pkg_name if Package::Generator->package_exists($pkg_name);

  # build this package, make it a subclass of Net::SNMP and
  my $package = Package::Generator->new_package(
    {
      make_unique => sub { return $pkg_name },
      isa         => ['Net::SNMP'],
    }
  );

  # arm a package reaper
  my $pkg_reaper = Package::Reaper->new($package);

  return ( $package, $pkg_reaper );
}

=head2 B<< init_mixins($reload) >>

  $session->init_mixins();
  $session->init_mixins(1);

This method redispatches to every I<< _init() >> methods in the loaded mixin modules. The raw SNMP values for the mixins are loaded during this call - or via callbacks during the snmp_dispatcher event loop for nonblocking sessions - and stored in the object space. The mixed methods deliver afterwards cooked meal from these values.

The MIB values are reloaded for the mixins if the argument $reload is true. It's an error calling this method twice without forcing $reload.

Returns nothing, dies on error.

=cut

sub init_mixins {
  my ( $session, $reload ) = @_;

  Carp::croak "pure instance method called as class method,"
    unless ref $session;

  my @class_mixins    = keys %register_class_mixins;
  my @instance_mixins = keys %{ $session->{$prefix}{mixins} };

  foreach my $mixin ( @class_mixins, @instance_mixins ) {
    eval "${mixin}::_init(\$session, \$reload)";
    Carp::croak $@ if $@;
  }
}

=head1 GUIDELINES FOR MIXIN AUTHORS

As a mixin-module author you must respect the following design guidelines:

=over 4

=item *

Write more separate mixin-modules instead of 'one module fits all'.

=item *

Don't build interdependancies to other mixin-modules.

=item *

In no circumstance change the given attributes of the calling Net::SNMP session instance. In any case stay with the given behavior for blocking, translation, debug, retries, timeout, ... of the object. Remember it's a mixin and no sub- or superclass.

=item *

Use Sub::Exporter and export the mixin methods by default.

=item *

Implement the I<< _init() >> method and fetch SNMP values only during this call. If the session instance is nonblocking use a callback to work properly with the I<< snmp_dispatcher() >> event loop. In no circumstance load additonal SNMP values outside the  I<< _init() >> method.

=back

See the L<< Net::SNMP::Mixin::System >> module as a blueprint for a simple mixin module.

=head1 DEVELOPER INFORMATION

If mixer() is called as a class method, the mixin-methods are just imported into the Net::SNMP package.

If called as an instance method for the first time, the methods are imported into a newly generated, unique package for this session. The session instance is B<< reblessed >> into this new package. The new package B<< inherits >> from the Net::SNMP class. Successive calls for this session instance imports just the additional mixin-methods into the already generated package for this instance.

=head1 SEE ALSO

L<< Sub::Exporter >>, and the Net::SNMP::Mixin::... documentations for more details about the provided mixin methods.

=head1 REQUIREMENTS

L<Net::SNMP>, L<Sub::Exporter>, L<Package::Generator>, L<Package::Reaper>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-net-snmp-mixin at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-SNMP-Mixin>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::SNMP::Mixin

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

unless ( caller() ) {
  print __PACKAGE__ . " compiles and initializes successful.\n";
}

1;

# vim: sw=2
