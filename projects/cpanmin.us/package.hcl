# cpanmin.us — cpanminus, the `cpanm` CPAN client. One of the projects the
# base-toolchain closure needed and this tree did not carry at all (`zpkb
# closure -build -require-standalone go-zpkg/base-toolchain`, 2026-11-20).
#
# ⛔ WRITTEN FROM ITS OWN FILES (go-zpkg/packages#431), at 1.7049.
#
# A pure-Perl program: bin/cpanm is a "pre-compiled" (fatpacked) script with
# every module it needs inside it, so it has no CPAN dependencies — Makefile.PL
# has `"PREREQ_PM" => {}` — and only needs perl.

summary = "cpanminus: get, unpack, build and install modules from CPAN"

# LICENSE:1-12 and Makefile.PL `"LICENSE" => "perl"`: "the same terms as the
# Perl 5 programming language system itself", i.e. the GPL version 1 or later,
# or the Artistic License — SPDX's spelling of perl_5.
license = "Artistic-1.0-Perl OR GPL-1.0-or-later"

versions {
  # The author's CPAN directory, which is where the distributable is. Not the
  # GitHub tags: the upstream pantry has to ignore three families of them
  # (1.9*, 1.79*, 1.71*) because they are not release versions. Trial
  # releases on CPAN carry an underscore, which this match excludes.
  url   = "https://cpan.metacpan.org/authors/id/M/MI/MIYAGAWA/"
  match = "/App-cpanminus-\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/App-cpanminus-/", "/\\.tar\\.gz/"]
}

dependencies = {
  # Makefile.PL:19 MIN_PERL_VERSION 5.008001. It runs under perl.
  "perl.org" = ">=5.8.1"
}

distributable {
  url              = "https://cpan.metacpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-{{version.raw}}.tar.gz"
  strip-components = 1

  # 317962 bytes. Three readings agree: `zpkb sourcepin`, an independent
  # fetch-and-hash, and the sha256 CPAN publishes for this file in
  # authors/id/M/MI/MIYAGAWA/CHECKSUMS. See provenance.note for what that
  # CHECKSUMS file's signature could and could not establish.
  sha256 = {
    "1.7049" = "b9ffb88e62a06aa91bd7d5a28ef6bdbb942608aea90e3969aa29b33640035214"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    # INSTALL_BASE puts bin/cpanm and lib/perl5/... under the prefix.
    "perl Makefile.PL INSTALL_BASE={{prefix}}",
    "make install",

    # ⛔ bin/cpanm starts `#!perl`. MakeMaker rewrites that to the ABSOLUTE path
    # of the perl that ran Makefile.PL, which is the builder's and exists on no
    # one else's machine. fix-shebangs.ts is the builder's own rewrite to
    # `#!/usr/bin/env perl`, as perl.org does for its own scripts.
    "fix-shebangs.ts {{prefix}}/bin/cpanm",
  ]
}

provides = [
  "bin/cpanm",
]

test {
  # No network: the upstream pantry's test installs Test::More from CPAN, so it
  # tests CPAN as much as it tests this package.
  script = [
    "cpanm --version | grep -F \"version {{version}}\"",

    # The shebang repair held: the first line names no build directory.
    {
      run = <<EOT
set -eu
first="$(head -n 1 "{{prefix}}/bin/cpanm")"
case "$first" in
  "#!/usr/bin/env perl"*) ;;
  *) echo "bin/cpanm starts with '$first', not the relocatable form" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Makefile.PL", # EXE_FILES bin/cpanm, LICENSE perl, MIN_PERL_VERSION 5.008001, PREREQ_PM empty
    "LICENSE",     # :1-12 the Perl 5 terms
    "META.json",   # license perl_5; runtime requires perl 5.008001
    "bin/cpanm",   # :1 `#!perl`, :3 "pre-compiled source code"
    "https://cpan.metacpan.org/authors/id/M/MI/MIYAGAWA/CHECKSUMS", # the sha256 for 1.7049, and the signature on it
  ]

  consulted = [
    # Read for facts only: the URL shape, the GitHub-tag `ignore` list that is
    # the reason this reads CPAN instead, and that it runs fix-shebangs.ts.
    "pkgxdev/pantry projects/cpanmin.us/package.yml",
  ]

  note = <<EOT
⚠ THE RUNG IS A PUBLISHED CHECKSUM ON THE SAME HOST, STATED.

CPAN publishes a sha256 for every file in an author's directory, in
authors/id/M/MI/MIYAGAWA/CHECKSUMS (CPAN::Checksums 2.14); the 1.7049 entry is
b9ffb88e…5214, size 317962, and it matches the bytes. That file is a
clearsigned OpenPGP message: `gpg --verify` reports a signature made
2026-10-24 by RSA key 4584D789E682F9F53B392F1837D079412CC9032E.

⛔ That key's fingerprint could not be found published by CPAN. CPAN.pm ships
the PAUSE batch-signing keys as PAUSE<year>.pub (github.com/andk/cpanpm);
PAUSE2022.pub and PAUSE2025.pub, the newest, hold 124 primary keys between them
and not this one, and PAUSE2025.pub was last changed on 2024-08-18. So the
signature was NOT verified, and the checksum is vouched for only by the host
that serves the tarball — continuity, not independence.

⛔ NOT BUILT. No session here can run the factory.
EOT
}
