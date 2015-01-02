#!/usr/bin/perl

# Test that arguments to various constructors are handled correctly.

use warnings;
use strict;
use lib qw(./mylib ../mylib);

use Test::More;
use Test::Fatal;

sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE;

my $test_class = 'POE::Component::Client::Keepalive';
require_ok($test_class);

# Run all of our tests.
my %param_alias;
_setup_param_aliases();

default_arguments();
dodgy_arguments();
override_defaults();

# POE expects to run so stomp on warnings.
POE::Kernel->run;
Test::More::done_testing();

# The constructor behaves as we expect and fills in default arguments
# if they're not supplied.

sub default_arguments {

  # We get something back.
  my $client = $test_class->new;
  isa_ok($client, $test_class, 'blank arguments get us an object');

  # It has the default scalar values we expect.
  my %default_scalar = (
    SF_MAX_HOST  => 4,
    SF_MAX_OPEN  => 128,
    SF_KEEPALIVE => 15,
    SF_TIMEOUT   => 120,
  );
  for my $param (sort keys %default_scalar) {
      is($client->[$client->$param], $default_scalar{$param},
         "$param was set to default scalar value");
  }

  # Things we didn't specify are set to the appropriate empty values.
  for my $hash_param (qw(SF_POOL SF_USED SF_WHEELS SF_USED_EACH SF_SOCKETS)) {
      is_deeply($client->[$client->$hash_param], {},
                "$hash_param was initialised to an empty hashref");
  }
  for my $undef_param (qw(SF_SHUTDOWN SF_REQ_INDEX)) {
      is_deeply($client->[$client->$undef_param], undef,
                "$undef_param was initialised to undef");
  }
  is_deeply($client->[$client->SF_QUEUE], [],
            'SF_QUEUE was initialised to an empty arrayref');

  # Resolver and alias have been set to something appropriate.
  isa_ok($client->[$client->SF_RESOLVER], 'POE::Component::Resolver',
         'A resolver was built for us');
  like($client->[$client->SF_ALIAS], qr/^POE::Component::Client::Keepalive/,
       'The alias looks sane');
}

# We can't supply dodgy arguments to the constructor.

sub dodgy_arguments {
  ok(exception { $test_class->new(haxx0r => 'l33t yo') },
    'Unexpected arguments get rebuffed');
}

# If we specify non-standard arguments, they override the defaults.

sub _setup_param_aliases {
  %param_alias = (
    max_per_host => 'SF_MAX_HOST',
    max_open     => 'SF_MAX_OPEN',
    keep_alive   => 'SF_KEEPALIVE',
    timeout      => 'SF_TIMEOUT',
  );

}

sub override_defaults {
  my %non_defaults = (
    max_per_host => 5,
    max_open     => 127,
    keep_alive   => 14,
    timeout      => 121,
  );
  my $client = $test_class->new(%non_defaults);
  for my $constructor_param (sort keys %non_defaults) {
    my $constant = $param_alias{$constructor_param};
    is(
      $client->[$client->$constant],
      $non_defaults{$constructor_param},
      "Setting $constructor_param to something non-default took"
    );
  }
}
