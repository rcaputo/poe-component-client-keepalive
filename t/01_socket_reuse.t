#!/usr/bin/perl
# $Id$

# Test connection reuse.  Allocates a connection, frees it, and
# allocates another.  The second allocation should return right away
# because it is honored from the keep-alive pool.

use warnings;
use strict;
use lib qw(./mylib ../mylib);
use Test::More tests => 3;

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

  $heap->{cm} = POE::Component::Client::Keepalive->new();

  my $connection = $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "127.0.0.1",
    port    => PORT,
    event   => "got_conn",
    context => "first",
  );

  ok(!defined($connection), "first request deferred");
}

sub got_conn{
  my ($heap, $stuff) = @_[HEAP, ARG0];

  # The delete() ensures only one copy of the connection exists.
  my $connection = delete $stuff->{connection};
  ok(defined($connection), "first request honored asynchronously");

  # Destroy the connection, freeing its socket.
  $connection = undef;

  my $second_request = $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "127.0.0.1",
    port    => PORT,
    event   => "die_die_die",
    context => "second",
  );

  ok(defined($second_request), "connection reused immediately");

  TestServer->shutdown();
}

POE::Kernel->run();
exit;
