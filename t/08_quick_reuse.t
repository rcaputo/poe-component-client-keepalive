#!/usr/bin/perl
# $Id$

# Test rapid connection reuse.  Sets the maximum overall connections
# to a low number.  Allocate up to the maximum.  Reuse one of the
# connections, and allocate a completely different connection.  The
# allocation shuld be deferred, and one of the free sockets in the
# keep-alive pool should be discarded to make room for it.

use warnings;
use strict;
use lib qw(./mylib ../mylib);
use Test::More tests => 7;

sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE;
use POE::Component::Client::Keepalive;

use TestServer;

use constant PORT => 49018;
TestServer->spawn(PORT);

use constant ANOTHER_PORT => 49019;
TestServer->spawn(ANOTHER_PORT);

POE::Session->create(
  inline_states => {
    _child           => sub { },
    _start           => \&start,
    _stop            => sub { },
    got_another_conn => \&got_another_conn,
    got_conn         => \&got_conn,
    got_error        => \&got_error,
  }
);

sub start {
  my $heap = $_[HEAP];

  $heap->{cm} = POE::Component::Client::Keepalive->new(
    max_open => 2,
  );

  $heap->{conn_count} = 0;

  {
    my $conn = $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "127.0.0.1",
      port    => PORT,
      event   => "got_conn",
      context => "first",
    );

    ok(!defined($conn), "first connection request deferred");
  }

  {
    my $conn = $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "127.0.0.1",
      port    => PORT,
      event   => "got_conn",
      context => "second",
    );

    ok(!defined($conn), "second connection request deferred");
  }
}

sub got_conn {
  my ($heap, $stuff) = @_[HEAP, ARG0];

  my $conn  = delete $stuff->{connection};
  my $which = $stuff->{context};
  ok(defined($conn), "$which connection established asynchronously");

  $conn = undef;

  return unless ++$heap->{conn_count} == 2;

  # Re-allocate one of the connections.

  my $third = $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "127.0.0.1",
    port    => PORT,
    event   => "got_another_conn",
    context => "third",
  );

  ok(defined($third), "third connection request honored from pool");

  my $fourth = $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "127.0.0.1",
    port    => ANOTHER_PORT,
    event   => "got_another_conn",
    context => "fourth",
  );

  ok(!defined($fourth), "fourth connection request deferred");
}

sub got_another_conn {
  my ($heap, $stuff) = @_[HEAP, ARG0];

  my $conn  = $stuff->{connection};
  my $which = $stuff->{context};
  ok(defined($conn), "$which connection established asynchronously");

  $heap->{cm}->shutdown();
  TestServer->shutdown();
}

POE::Kernel->run();
exit;
