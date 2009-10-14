#!/usr/bin/perl

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
  VERSION_FROM => 'lib/POE/Component/Client/Keepalive.pm',
  PREREQ_PM    => {
    'POE'                         => 1.280,
    'POE::Component::Client::DNS' => 1.051,
    'Net::IP'                     => 1.25,
  },
  META_ADD     => {
    resources  => {
      license    => 'http://dev.perl.org/licenses/',
      repository => 'http://github.com/rcaputo/poe-component-client-keepalive',
    },
  },
  dist         => {
    COMPRESS   => 'gzip -9f',
    SUFFIX     => 'gz',
    PREOP      => (
      'git-log.pl | tee ./$(DISTNAME)-$(VERSION)/CHANGES > ./CHANGES'
    ),
  },
  @conditional_makefile,
);
