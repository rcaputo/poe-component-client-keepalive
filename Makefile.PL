#!/usr/bin/perl
# $Id$

use ExtUtils::MakeMaker;

# Touch CHANGES so it exists.
open(CHANGES, ">>CHANGES") and close CHANGES;

my @conditional_makefile;
if ($ExtUtils::MakeMaker::VERSION > 6.30) {
  push(
    @conditional_makefile,
    EXTRA_META  => (
      "no_index:\n" .
      "    dir:\n" .
      "        - mylib\n"
    )
  );
}

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
    'POE'                         => 0.31,
    'POE::Component::Client::DNS' => 0.9801,
  },
  dist         => {
    COMPRESS   => 'gzip -9f',
    SUFFIX     => 'gz',
    PREOP      => (
      'svn-log.perl | tee ./$(DISTNAME)-$(VERSION)/CHANGES > ./CHANGES'
    ),
  },
  @conditional_makefile,
);
