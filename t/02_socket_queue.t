#!/usr/bin/perl
# $Id$

# Test connection queuing.  Set the max active connection to be really
# small (one in all), and then try to allocate two connections.  The
# second should queue.

use warnings;
use strict;
use lib qw(./mylib ../mylib);
use Test::More tests => 10;
use Errno qw(ECONNREFUSED);

sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE;
use POE::Component::Client::Keepalive;

use constant PORT => 49018;
use constant UNKNOWN_PORT => PORT+1;
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
    test_max_queue  => \&test_max_queue,
  }
);

sub start {
  my $heap = $_[HEAP];

  $heap->{cm} = POE::Component::Client::Keepalive->new(
    max_open => 1,
  );

  # Count the number of times test_max_queue is called.  When that's
  # 2, we actually do the test.

  $heap->{test_max_queue} = 0;

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

    ok(!defined($conn), "first request deferred");
  }

  {
    my $conn = $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "127.0.0.1",
      port    => PORT,
      event   => "got_second_conn",
      context => "second",
    );

    ok(!defined($conn), "second request deferred");
  }
}

sub got_first_conn {
  my ($kernel, $heap, $stuff) = @_[KERNEL, HEAP, ARG0];

  my $conn = delete $stuff->{connection};
  ok(defined($conn), "first connection honored asynchronously");

  $conn = undef;

  $kernel->yield("test_max_queue");
}

sub got_second_conn {
  my ($kernel, $heap, $stuff) = @_[KERNEL, HEAP, ARG0];

  my $conn = $stuff->{connection};
  ok(defined($conn), "second connection honored asynchronously");

  $conn = undef;

  $kernel->yield("test_max_queue");
}

# We need a free connection pool of 2 or more for this next test.  We
# want to allocate one of them, and then attempt to allocate a
# different connection.

sub test_max_queue {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  $heap->{test_max_queue}++;
  return unless $heap->{test_max_queue} == 2;

  my $conn = $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "127.0.0.1",
    port    => PORT,
    event   => "got_third_conn",
    context => "third",
  );

  ok(defined($conn), "third connection request honored from pool");

  my $other_conn = $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "127.0.0.1",
    port    => UNKNOWN_PORT,
    event   => "got_fourth_conn",
    context => "fourth",
  );

  ok(!defined($other_conn), "fourth connection request deferred");

  # The allocated connection should self-destruct when it falls out of
  # scope.
}

# This connection should fail, actually.

sub got_fourth_conn {
  my ($kernel, $heap, $stuff) = @_[KERNEL, HEAP, ARG0];

  my $conn = $stuff->{connection};
  ok(!defined($conn), "fourth connection failed (as it should)");

  ok($stuff->{function} eq "connect", "connection failed in connect");
  ok($stuff->{error_num} == ECONNREFUSED, "connection error ECONNREFUSED");
  ok($stuff->{error_str} eq "Connection refused", "connection refused");

  # Shut things down.
  TestServer->shutdown();
  $heap->{cm}->shutdown();
}

POE::Kernel->run();
exit;
