#!/usr/bin/perl
# $Id$

# Test connection queuing.  Set the per-connection queue to be really
# small (one in all), and then try to allocate two connections.  The
# second should queue.

use warnings;
use strict;
use lib qw(./mylib ../mylib);
use Test::More tests => 7;

sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE;
use POE::Component::Client::Keepalive;

use constant PORT => 49018;
use TestServer;

TestServer->spawn(PORT);

POE::Session->create(
  inline_states => {
    _child          => sub { },
    _start          => \&start,
    _stop           => sub { },
    got_error       => \&got_error,
    got_first_conn  => \&got_first_conn,
    got_fourth_conn => \&got_fourth_conn,
    got_second_conn => \&got_second_conn,
    got_timeout     => \&got_timeout,
    test_pool_alive => \&test_pool_alive,
  }
);

sub start {
  my $heap = $_[HEAP];

  $heap->{cm} = POE::Component::Client::Keepalive->new(
    max_per_host => 1,
  );

  # Count the number of times test_pool_alive is called.  When that's
  # 2, we actually do the test.

  $heap->{test_pool_alive} = 0;

  # Make two identical tests.  They're both queued because the free
  # pool is empty at this point.

  {
    my $conn = $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "127.0.0.1",
      port    => PORT,
      event   => "got_first_conn",
      context => "first",
    );

    ok(!defined($conn), "first connection request deferred");
  }

  {
    my $conn = $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "127.0.0.1",
      port    => PORT,
      event   => "got_second_conn",
      context => "second",
    );

    ok(!defined($conn), "second connection request deferred");
  }
}

sub got_first_conn {
  my ($kernel, $heap, $stuff) = @_[KERNEL, HEAP, ARG0];

  my $conn = $stuff->{connection};
  ok(defined($conn), "first connection established asynchronously");

  $kernel->yield("test_pool_alive");
}

sub got_second_conn {
  my ($kernel, $heap, $stuff) = @_[KERNEL, HEAP, ARG0];

  my $conn = $stuff->{connection};
  ok(defined($conn), "second connection established asynchronously");

  $kernel->yield("test_pool_alive");
}

# We need a free connection pool of 2 or more for this next test.  We
# want to allocate and free one of them to make sure the pool is not
# destroyed.  Yay, Devel::Cover, for making me actually do this.

sub test_pool_alive {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  $heap->{test_pool_alive}++;
  return unless $heap->{test_pool_alive} == 2;

  my $immediate_conn = $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "127.0.0.1",
    port    => PORT,
    event   => "got_third_conn",
    context => "third",
  );

  ok(defined($immediate_conn), "third connection request honored from pool");

  my $delayed_conn = $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "127.0.0.1",
    port    => PORT,
    event   => "got_fourth_conn",
    context => "fourth",
  );

  ok(!defined($delayed_conn), "fourth connection request is deferred");
}

sub got_fourth_conn {
  my ($kernel, $heap, $stuff) = @_[KERNEL, HEAP, ARG0];

  my $conn = delete $stuff->{connection};
  ok(defined($conn), "fourth connection established asynchronously");

  $conn = undef;

  TestServer->shutdown();
  $heap->{cm}->shutdown();
}

POE::Kernel->run();
exit;
