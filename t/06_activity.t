#!/usr/bin/perl
# $Id$

# Test activity on idle connections in the pool.

use warnings;
use strict;
use lib qw(./mylib ../mylib);
use Test::More tests => 4;

sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE;
use POE::Component::Client::Keepalive;

use TestServer;

use constant PORT => 49018;
TestServer->spawn(PORT);

POE::Session->create(
  inline_states => {
    _child             => sub { },
    _start             => \&start,
    _stop              => sub { },
    check_for_input    => \&check_for_input,
    got_conn           => \&got_conn,
    got_error          => \&got_error,
    got_input          => \&got_input,
    got_timeout        => \&got_timeout,
    shutdown_server    => \&shutdown_server,
  }
);

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

    ok(!defined($conn), "first connection request deferred");
  }
}

sub got_conn {
  my ($heap, $stuff) = @_[HEAP, ARG0..$#_];

  my $conn = $stuff->{connection};
  ok(defined($conn), "first connection established asynchronously");

  TestServer->send_something();

  $_[KERNEL]->delay(check_for_input => 1);

  # The connection goes free when it drops out of scope here.
  # Everything that was sent to it remains unread.
}

# Reallocate the free socket.  See if any input is on it.  There
# should be none, as it was all directed to /dev/null while the socket
# was free.

sub check_for_input {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  $heap->{conn} = $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "127.0.0.1",
    port    => PORT,
    event   => "got_conn",
    context => "first",
  );

  $heap->{conn}->start(
    InputEvent => "got_input",
  );

  ok(defined($heap->{conn}->wheel()), "connection contains a wheel");

  $kernel->delay(shutdown_server => 1);
}

sub got_input {
  $_[HEAP]->{got_input} = 1;
}

sub shutdown_server {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  ok(!$heap->{got_input}, "didn't receive any input");

  delete $heap->{conn};
  TestServer->shutdown();
  $heap->{cm}->shutdown();
}

POE::Kernel->run();
exit;
