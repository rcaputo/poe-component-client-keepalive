#!/usr/bin/perl
# vim: filetype=perl ts=2 sw=2 expandtab

# Test request timeouts.  Set the timeout ridiculously small, so
# timeouts happen immediately.  Request a connection, and watch it
# fail.  Ha ha ha!

use warnings;
use strict;
use lib qw(./mylib ../mylib);
use Test::More tests => 6;

sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE;
use POE::Component::Client::Keepalive;

use TestServer;

# TODO - Dynamically find ports so we don't conflict with someone.
# And we WILL conflict with someone sooner or later!
use constant PORT => 49018;
TestServer->spawn(PORT);

# Listen on a socket, but don't accept connections.
use IO::Socket::INET;
my $unaccepting_listener = IO::Socket::INET->new(
  LocalAddr => "127.0.0.1",
  LocalPort => PORT + 1,
  Reuse     => "yes",
) or die $!;

# Session to run tests.
POE::Session->create(
  inline_states => {
    _child   => sub { },
    _start   => \&start,
    _stop    => sub { },
    got_conn => \&got_conn,
  }
);

sub start {
  my $heap = $_[HEAP];

  # Connecting to localhost can happen within 0 seconds, so we make
  # the timeout negative.  Connections can't happen in the past. :)

  $heap->{cm} = POE::Component::Client::Keepalive->new(
    timeout => -1,
  );

  {
    $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "127.0.0.1",
      port    => PORT,
      event   => "got_conn",
      context => "first",
    );
  }

  # Try to connect to a socket we know is listening but won't answer.
  # Forces the timeout after the wheel is created.

  {
    $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "127.0.0.1",
      port    => PORT+1,
      event   => "got_conn",
      context => "second",
      timeout => 0.5,
    );
  }
}

sub got_conn {
  my ($heap, $stuff) = @_[HEAP, ARG0];

  my $conn  = $stuff->{connection};
  my $which = $stuff->{context};
  ok(!defined($stuff->{from_cache}), "$which didn't come from cache");
  ok(!defined($conn), "$which connection failed");
  ok(
    $stuff->{error_num} == Errno::ETIMEDOUT,
    "$which connection request timed out"
  );

  return unless ++$heap->{timeout_count} == 2;

  TestServer->shutdown();
}

POE::Kernel->run();
exit;
