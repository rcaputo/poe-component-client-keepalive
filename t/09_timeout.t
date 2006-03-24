#!/usr/bin/perl
# $Id$
# vim: filetype=perl

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

use constant PORT => 49018;
TestServer->spawn(PORT);

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

  # TODO - The 0.01 second timeout assumes it will give the component
  # enough time to create a wheel but not establish a connection.
  # This is a bold assumption, and it may lead to false failures.

  {
    $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "google.com",
      port    => 80,
      event   => "got_conn",
      context => "second",
      timeout => 0.01,
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
