#!/usr/bin/perl

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
use POE::Component::Resolver;
use Socket qw(AF_INET);

use TestServer;

# Random port.  Kludge until TestServer can report a port number.
use constant PORT => int(rand(65535-2000)) + 2000;
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
    resolver => POE::Component::Resolver->new(af_order => [ AF_INET ]),
  );

  $heap->{conn_count} = 0;

  {
    $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "localhost",
      port    => PORT,
      event   => "got_conn",
      context => "first",
    );
  }

  {
    $heap->{cm}->allocate(
      scheme  => "http",
      addr    => "localhost",
      port    => PORT,
      event   => "got_conn",
      context => "second",
    );
  }
}

sub got_conn {
  my ($heap, $stuff) = @_[HEAP, ARG0];

  my $conn  = delete $stuff->{connection};
  my $which = $stuff->{context};
  ok(defined($conn), "$which connection established asynchronously");
  ok(!defined($stuff->{from_cache}), "$which connection request deferred");

  $conn = undef;

  return unless ++$heap->{conn_count} == 2;

  # Re-allocate one of the connections.

  $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "localhost",
    port    => PORT,
    event   => "got_another_conn",
    context => "third",
  );


  $heap->{cm}->allocate(
    scheme  => "http",
    addr    => "localhost",
    port    => ANOTHER_PORT,
    event   => "got_another_conn",
    context => "fourth",
  );
}

sub got_another_conn {
  my ($heap, $stuff) = @_[HEAP, ARG0];

  # Deleting here to avoid a copy of the connection in %$stuff.
  my $conn  = delete $stuff->{connection};
  my $which = $stuff->{context};

  if ($which eq 'third') {
    is(
      $stuff->{from_cache}, 'immediate',
      "$which connection request honored from pool"
    );
    return;
  }

  if ($which eq 'fourth') {
    ok(
      !defined ($stuff->{from_cache}),
      "$which connection request honored from pool"
    );
    ok(defined($conn), "$which connection established asynchronously");

    # Free the connection first.
    $conn = undef;

    TestServer->shutdown();
    $heap->{cm}->shutdown();
    return;
  }

  die;
}

POE::Kernel->run();
exit;
