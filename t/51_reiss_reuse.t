#!/usr/bin/perl

# Regression test for a bug which occured because a loop
# that would look for existing free connections would reuse
# a connection without removing it from a list of connections
# that can be closed if we have neared the connection limit.

use warnings;
use strict;
use lib qw(./mylib ../mylib);
use Test::More tests => 5;

sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE;
use POE::Component::Client::Keepalive;

use TestServer;

# TODO - Ideally TestServer->spawn() should choose an unused port and
# return that.

use constant PORT => 49000 + int(rand 1000);
TestServer->spawn(PORT);

use constant ANOTHER_PORT => PORT + 1;
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
    max_per_host => 2,
  );

  $heap->{conn_count} = 0;

  for (1..3) {
    $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "localhost",
      port    => PORT,
      event   => "got_conn",
      context => "first/$_",
    );
  }
}

sub got_conn {
  my ($heap, $stuff) = @_[HEAP, ARG0];

  my $conn  = delete $stuff->{connection};
  my $which = $stuff->{context};
  ok(defined($conn), "$which connection established asynchronously");

  $conn = undef;
  if (++$heap->{request_count} == 1) {
    $heap->{cm}->allocate(
      scheme => "http",
      addr => "localhost",
      port => PORT,
      event => "got_conn",
      context => "second-a"
    );
    $heap->{cm}->allocate(
      scheme => "http",
      addr => "localhost",
      port => ANOTHER_PORT,
      event => "got_conn",
      context => "second-b"
    );
  }

  if ($heap->{request_count} == 5) {
    TestServer->shutdown();
    $heap->{cm}->shutdown();
  }
}

POE::Kernel->run();
exit;
