#!/usr/bin/perl
# $Id$

use strict;

use ExtUtils::MakeMaker;

# Touch CHANGES so it exists.
open(CHANGES, ">>CHANGES") and close CHANGES;

my @conditional_makefile;
my $eu_mm_ver = $ExtUtils::MakeMaker::VERSION;

if ($eu_mm_ver >= 6.48) {
  push(
    @conditional_makefile,
    META_MERGE => {
      no_index => { directory => "mylib" }
    }
  );
}

WriteMakefile(
  NAME         => 'POE::Component::Client::Keepalive',
  AUTHOR       => 'Rocco Caputo <rcaputo@cpan.org>',
  ABSTRACT     => 'Manages and keeps alive client connections',
  LICENSE      => 'perl',
  VERSION_FROM => 'Client-Keepalive.pm',
  PM           => {
    'Client-Keepalive.pm' => '$(INST_LIBDIR)/Keepalive.pm',
    'Conn-Keepalive.pm'   => '$(INST_LIBDIR)/../Connection/Keepalive.pm',
  },
  PREREQ_PM    => {
    'POE'                         => 0.31,
    'POE::Component::Client::DNS' => 1.01,
    'Net::IP'                     => 1.25,
  },
  META_ADD     => {
    resources  => {
      license    => 'http://dev.perl.org/licenses/',
      repository => 'http://thirdlobe.com/svn/poco-client-http/trunk'
    },
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
