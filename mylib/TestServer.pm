package TestServer;

use warnings;
use strict;

use POE;
use POE::Component::Server::TCP;

my %clients;
my %servers;

sub spawn {
  my ($class, $port) = @_;

  my $alias = $servers{$port} = "server_$port";

  POE::Component::Server::TCP->new(
    Alias              => $alias,
    Port               => $port,
    Address            => "127.0.0.1",
    ClientInput        => \&discard_client_input,
    ClientConnected    => \&register_client,
    ClientDisconnected => \&unregister_client,
    InlineStates       => {
      send_something   => \&internal_send_something,
    },
  );
}

sub register_client {
  $clients{$_[SESSION]->ID} = 1;
}

sub unregister_client {
  delete $clients{$_[SESSION]->ID};
}

sub discard_client_input {
  # Do nothing.
}

sub send_something {
  foreach my $client (keys %clients) {
    $poe_kernel->call($client, "send_something");
  }
}

sub internal_send_something {
  $_[HEAP]->{client}->put(scalar localtime);
}

sub shutdown {
  foreach my $session (values(%servers), keys(%clients)) {
    $poe_kernel->post($session => "shutdown");
  }
}

sub shutdown_clients {
  foreach my $session (keys(%clients)) {
    $poe_kernel->call($session => "shutdown");
  }
}

1;
