#!/usr/bin/perl
# $Id$

use ExtUtils::MakeMaker;

# Touch CHANGES so it exists.
open(CHANGES, ">>CHANGES") and close CHANGES;

WriteMakefile(
  NAME         => 'POE::Component::Client::Keepalive',
  AUTHOR       => 'Rocco Caputo <rcaputo@cpan.org>',
  ABSTRACT     => 'Manages and keeps alive client connections',
  VERSION_FROM => 'Client-Keepalive.pm',
  PM           => {
    'Client-Keepalive.pm' => '$(INST_LIBDIR)/Keepalive.pm',
    'Conn-Keepalive.pm'   => '$(INST_LIBDIR)/../Connection/Keepalive.pm',
  },
  PREREQ_PM    => {
    'POE' => 0.29,
  },
  dist         => {
    COMPRESS   => 'gzip -9f',
    SUFFIX     => 'gz',
    PREOP      => (
      'cvs-log.perl | tee ./$(DISTNAME)-$(VERSION)/CHANGES > ./CHANGES'
    ),
  },
);
