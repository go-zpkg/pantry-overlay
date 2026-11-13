# grep — GNU grep, egrep and fgrep.
#
# ⛔ WRITTEN FROM GREP'S OWN FILES (go-zpkg/packages#431), at 3.12. Fifth whole
# recipe of the sovereign pantry. It began as a 21-line fragment with a build
# block and nothing else, and reading the source to complete it found three
# defects IN THOSE 21 LINES — see the notes on each below.

summary = "GNU grep: print lines matching a pattern"

# COPYING is the GPLv3 text; src/grep.c:6 carries "either version 3, or (at
# your option) any later version". Both files, because only the second answers
# the "-or-later".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/grep/"
  match = "/grep-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^grep-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/grep/grep-{{version.raw}}.tar.xz"
  strip-components = 1

  # Recorded with `zpkb sourcepin --sig auto --key <gnu-keyring.gpg>
  # --fingerprint "155D 3FC5 00C8 3448 6D1E  EA67 7FD9 FCCB 000B EEEE"`:
  # 1 918 448 bytes, signed 2025-04-10 with SHA-512 by Jim Meyering
  # <jim@meyering.net>, the named key found after walking 326 primary keys in
  # the GNU keyring. Confirmed by a second, independent fetch-and-hash.
  #
  # ⭐ THE SAME FINGERPRINT SIGNS gnu.org/gzip. One key covers both recipes,
  # which is why `--key-source` says the same thing in both: the warrant is
  # shared and so is its limit.
  sha256 = {
    "3.12" = "2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9"
  }

  # ⛔⛔ THE SIGNATURE URL WAS WRITTEN HERE AS `sha`, AND `sha` MEANS SOMETHING
  # ELSE. schema/package.schema.json:141 defines it as "where the expected
  # SHA-256 of the archive is published, usually ${{url}}.sha256 — the build
  # FETCHES it and refuses a mismatch", and build/runner.go:769-781 does
  # exactly that. Measured rather than reasoned, with the builder's own reader:
  #
  #   fetch.DeclaredSHA256(".../grep-3.12.tar.xz.sig", "grep-3.12.tar.xz")
  #   → no line names grep-3.12.tar.xz — the server returned text, not an
  #     archive: "-----BEGIN PGP SIGNATURE----- …"
  #
  # and a checksum file that cannot be READ is a build failure on purpose
  # (runner.go:746-749: "the upstream's checksum was unavailable, so we built
  # anyway is exactly the reasoning that leaves a verification permanently
  # disarmed"). So this recipe would have failed at the fetch, and `zpkb lint`
  # could not see it because linting does not fetch.
  #
  # There is no schema field for a detached signature — `sig` appears nowhere
  # in zpkb's Go sources, which is go-zpkg/zpkb#282 — so it is recorded in
  # `provenance` below, in prose, until there is one.
}

build {
  # ⛔⛔ THREE CHANGES TO A 21-LINE BLOCK, EACH WITH A CONTROL.
  #
  # 1. `"gnu.org/grep" = "*"` REMOVED — grep was its own build dependency, the
  #    only recipe among 216 here to name itself. The sandbox already has a
  #    grep: `go-zpkg/base-toolchain/package.hcl:80` declares `gnu.org/grep`
  #    beside sed and gawk, and that package is what stages the build image.
  #    Which is why 15 of the 16 recipes here that run `./configure` declare no
  #    grep at all, and why upstream's own grep recipe declares only
  #    pkg-config. Inherited from the pre-HCL tree with no commit explaining it.
  #
  # 2. `"pcre.org/v2" = "=10.47"` → `"^10"` — an EXACT pin where grep states no
  #    version. `m4/pcre.m4:26` is
  #
  #        PKG_CHECK_MODULES([PCRE], [libpcre2-8], [], [: ${PCRE_LIBS=-lpcre2-8}])
  #
  #    with no version argument; what it probes is `pcre2_compile`
  #    (m4/pcre.m4:29-41), which is PCRE2's API, i.e. major 10. An exact pin
  #    asserts a requirement the project does not have and breaks the day that
  #    one version leaves the registry.
  #
  # 3. pkg-config KEPT, and now justified: PKG_CHECK_MODULES above is what
  #    needs it. The constraint is upstream's and unchanged.
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "pcre.org/v2"                = "^10"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--disable-nls",
      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:24-25 — `bin_PROGRAMS = grep` and `bin_SCRIPTS = egrep fgrep`.
# Three names, none of them conditional and none of them an install-hook alias,
# which makes this the simplest `provides` of the five recipes written so far.
provides = [
  "bin/egrep",
  "bin/fgrep",
  "bin/grep",
]

test {
  script = [
    "grep --version | grep {{version.raw}}",

    # ⛔⛔ THE GATE FOR DEFECT 4, AND IT IS THE ONE A VERSION TEST CANNOT SEE.
    # The fragment passed `-with-packager=tea` to configure. Traced through the
    # project's own files rather than assumed:
    #
    #   configure:3400        `-with-* | --with-*)` — autoconf accepts the
    #                         SINGLE dash, so the option was recognised
    #   configure:48671       `#define PACKAGE_PACKAGER "$withval"`
    #   lib/version-etc.c:76  fprintf (stream, _("Packaged by %s\n"), …)
    #
    # So every grep artifact this factory built printed `Packaged by tea` —
    # naming the project this ecosystem forked from, in the one place a user
    # looks, while `grep --version | grep <version>` passed on the line above
    # it. The flag is gone; this asserts the line cannot come back.
    "test -z \"$(grep --version | grep -i 'packaged by')\"",

    # A real match and a real non-match, so the three names are exercised
    # rather than merely present. `-q` keeps the output clean and the exit
    # status is what is asserted.
    "printf 'alpha\\nbeta\\n' | grep -q '^beta$'",
    "printf 'alpha\\nbeta\\n' | egrep -q 'al(pha|ias)'",
    "printf 'a.c\\nabc\\n' | fgrep -q 'a.c'",
    "! printf 'alpha\\n' | grep -q 'gamma'",

    # -P is the reason pcre.org/v2 is a dependency at all. If PCRE2 were absent
    # at build time, configure's AM_CONDITIONAL([USE_PCRE]) (configure.ac:218)
    # would turn it off and grep would still install — so the dependency is only
    # really asserted here.
    "printf 'x42\\n' | grep -qP '\\\\d{2}'",
  ]
}

provenance {
  read = [
    "src/Makefile.am", # :24-25 bin_PROGRAMS and bin_SCRIPTS — the three names
    "configure.ac",    # :217-218 gl_FUNC_PCRE and AM_CONDITIONAL([USE_PCRE])
    "m4/pcre.m4",      # :26 PKG_CHECK_MODULES([PCRE], [libpcre2-8]) with NO version
    "configure",       # :3400 single-dash long options; :48671 PACKAGE_PACKAGER
    "lib/version-etc.c", # :71-76 where PACKAGE_PACKAGER reaches --version
    "COPYING",         # the GPLv3 text that ships
    "src/grep.c",      # :6 "either version 3, or (at your option) any later"
  ]

  consulted = [
    "pkgxdev/pantry projects/gnu.org/grep/package.yml",
    "go-zpkg/base-toolchain/package.hcl", # :80, which already provides grep
  ]

  note = <<EOT
This recipe existed as a build block and nothing else — no versions, no
distributable — so it resolved only because upstream's recipe was merged
underneath it. Completing it required reading grep's own files, and that reading
found three defects inside the 21 lines that were already there:

  - grep was its own build dependency, alone among 216 recipes here;
  - PCRE2 was pinned to an exact version the project does not ask for;
  - `-with-packager=tea` stamped the forked-from project's name into
    `grep --version`.

⛔ THE THIRD IS THE ONE WORTH REMEMBERING. It was not a typo and not inert: a
single-dash long option IS accepted by autoconf (configure:3400), the macro IS
defined (configure:48671), and gnulib's version-etc.c:76 prints it. The existing
test asserted `grep --version | grep <version>` and passed, one line above the
wrong name. A test that checks the line it expects cannot see the line it does
not.

The digest is signature-verified, by the same key as gnu.org/gzip:

  signature  https://ftp.gnu.org/gnu/grep/grep-3.12.tar.xz.sig  (ASCII-armoured)
  key        https://ftp.gnu.org/gnu/gnu-keyring.gpg
  identity   Jim Meyering
  checked    when the digest was recorded, not at every build

Both limits on that warrant are the same and are restated here rather than
cross-referenced, because a recipe should be readable alone:

  - the key came from https://ftp.gnu.org/gnu/gnu-keyring.gpg, served by the
    SAME HOST as the tarball — continuity, not independence;
  - that keyring holds every GNU maintainer's key, so the fingerprint had to be
    named or "verified" would have meant "somebody in that file signed it".
EOT
}
