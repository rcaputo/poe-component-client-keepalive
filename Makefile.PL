#!/usr/bin/perl
# $Id$

use ExtUtils::MakeMaker;

# Touch CHANGES so it exists.
open(CHANGES, ">>CHANGES") and close CHANGES;

my %prereq = (
  'POE'            => 0.29,
  'HTTP::Request'  => 1.30,
  'HTTP::Response' => 1.37,
  'URI'            => 1.24,
  'HTML::Parser'   => 3.33,  # For HTML::HeadParser
);

WriteMakefile(
  NAME         => 'POE::Component::Client::Keepalive',
  AUTHOR       => 'Rocco Caputo <rcaputo@cpan.org>',
  ABSTRACT     => 'Manages and keeps alive client connections',
  VERSION_FROM => 'Client-Keepalive.pm',
  PM           => {
    'Client-Keepalive.pm' => '$(INST_LIBDIR)/Keepalive.pm',
    'Conn-Keepalive.pm'   => '$(INST_LIBDIR)/../Connection/Keepalive.pm',
  },
  PREREQ_PM    => \%prereq,
  dist         => {
    COMPRESS   => 'gzip -9f',
    SUFFIX     => 'gz',
    PREOP      => (
      'cvs-log.perl | tee ./$(DISTNAME)-$(VERSION)/CHANGES > ./CHANGES'
    ),
  },
);
