#!/usr/bin/perl
# $Id$

# Testing the bits that keep track of connections per connection key.

use warnings;
use strict;
use lib qw(./mylib ../mylib);
use Test::More tests => 5;

sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE;
use POE::Component::Client::Keepalive;

use constant PORT => 49018;
use TestServer;

TestServer->spawn(PORT);

POE::Session->create(
  inline_states => {
    _start      => \&start,

    got_conn  => \&got_conn,
    got_error   => \&got_error,
    got_timeout => \&got_timeout,
    test_alloc_and_free => \&test_alloc_and_free,

    _child => sub { },
    _stop  => sub { },
  }
);

# Allocate two connections.  Wait for both to be allocated.  Free them
# both.

sub start {
  my $heap = $_[HEAP];

  $heap->{cm} = POE::Component::Client::Keepalive->new();

  {
    my $conn = $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "127.0.0.1",
      port    => PORT,
      event   => "got_conn",
      context => "first",
    );

    ok(!defined($conn), "first connection request is deferred");
  }

  {
    my $conn = $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "127.0.0.1",
      port    => PORT,
      event   => "got_conn",
      context => "second",
    );

    ok(!defined($conn), "second connection request is deferred");
  }
}

sub got_conn{
  my ($heap, $stuff) = @_[HEAP, ARG0];

  my $conn  = $stuff->{connection};
  my $which = $stuff->{context};
  ok(defined($conn), "$which connection created successfully");

  $heap->{conn}{$which} = $conn;

  return unless keys(%{$heap->{conn}}) == 2;

  # Free them both at once.
  delete $heap->{conn};

  # Give the server time to accept the connection.
  $_[KERNEL]->delay(test_alloc_and_free => 1);
}

# Allocate and free a third connection.  It's reused from the free
# pool.

sub test_alloc_and_free {
  my $heap = $_[HEAP];

  my $new = $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "127.0.0.1",
    port    => PORT,
    event   => "got_conn",
    context => "third",
  );

  ok(defined($new), "third connection honored from the pool");

  $heap->{cm}->shutdown();
  TestServer->shutdown();
}

POE::Kernel->run();
exit;
