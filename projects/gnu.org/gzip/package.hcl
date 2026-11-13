# gzip — the GNU compression utility, and the first recipe here whose digest is
# vouched for by a SIGNATURE rather than only pinned.
#
# ⛔ WRITTEN FROM GZIP'S OWN FILES (go-zpkg/packages#431), at 1.15. Fourth whole
# recipe of the sovereign pantry after zlib.net (#79), tukaani.org/xz (#81) and
# lz4.org (#82) — and the first that is not a compression LIBRARY, so the facts
# it needed were about installed names rather than about linking.

summary = "The GNU compression utility: gzip, gunzip, zcat and the z* script family"

# Read from COPYING, which is the GPLv3 text, and from gzip.c:9 — "either
# version 3, or (at your option) any later version". Both files, because the
# COPYING of a GNU project says which licence TEXT ships and the source header
# says whether later versions are permitted; only the second answers "-or-later".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/gzip/"
  match = "/gzip-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^gzip-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/gzip/gzip-{{version.raw}}.tar.xz"
  strip-components = 1

  # ⛔⛔ THE FIRST SIGNATURE-VERIFIED PIN IN THIS TREE. ftp.gnu.org publishes a
  # detached signature beside every tarball, and nothing in this builder read
  # one until zpkb v0.73.0. Recorded with:
  #
  #   zpkb sourcepin --sig auto --key ./gnu-keyring.gpg \
  #     --key-source "https://ftp.gnu.org/gnu/gnu-keyring.gpg, 2026-11-08" \
  #     --fingerprint "155D 3FC5 00C8 3448 6D1E  EA67 7FD9 FCCB 000B EEEE" \
  #     --version 1.15 https://ftp.gnu.org/gnu/gzip/gzip-1.15.tar.xz
  #
  # 808900 bytes, signed 2026-09-20 with SHA-512 by Jim Meyering
  # <jim@meyering.net>, found after walking 326 primary keys in the GNU keyring.
  # The digest below was then confirmed by a second, independent fetch-and-hash
  # (`curl --fail` + `shasum -a 256`): two paths, one answer.
  sha256 = {
    "1.15" = "9aa0cc780dec156b8282844833b342ab7cb08c25d2cd9a1869cdd0df31deff48"
  }

  # The signature's own URL, recorded because the field exists and three
  # upstream recipes in 1932 use it. It is NOT what protects this build — the
  # digest above is, and it needs no network. This says where the warrant came
  # from, so the next person to bump the version knows a signature is published
  # and can check it rather than discovering the digest alone.
  # ⛔⛔ THE SIGNATURE URL WAS WRITTEN HERE AS `sha`, AND `sha` MEANS SOMETHING
  # ELSE: "where the expected SHA-256 of the archive is published … the build
  # FETCHES it and refuses a mismatch" (schema/package.schema.json:141,
  # build/runner.go:769-781). Measured with the builder's own reader,
  # fetch.DeclaredSHA256 on a `.sig` returns "no line names <archive> — the
  # server returned text, not an archive: \"-----BEGIN PGP SIGNATURE----- …\"",
  # and an unreadable checksum file is a build failure by design
  # (runner.go:746-749). `zpkb lint` cannot see it, because linting does not
  # fetch.
  #
  # No schema field exists for a detached signature (go-zpkg/zpkb#282), so it is
  # recorded in `provenance` below until there is one:
  #   https://ftp.gnu.org/gnu/gzip/gzip-1.15.tar.xz.sig
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix=\"{{prefix}}\"",
      "--disable-dependency-tracking",
    ]
    MAKE_CFLAGS = [
      "-g",
      "-O2",
    ]
    "linux/aarch64" = {
      MAKE_CFLAGS = [
        "-include asm/sigcontext.h",
      ]
    }
  }

  # ⛔⛔ ac_cv_prog_LESS=less IS LOAD-BEARING, AND IT LOOKS LIKE NOISE.
  # configure.ac:61-62 is
  #
  #     AC_CHECK_PROG([LESS], [less], [less])
  #     AM_CONDITIONAL([LESS], [test "$LESS"])
  #
  # and Makefile.am:33-39 gates `ZLESS_PROG = zless` on that conditional. So
  # `bin/zless` is installed only if configure FINDS less in PATH — and a
  # FROM-scratch build sandbox has no less. Pre-seeding autoconf's cache
  # variable makes the conditional true without the program being present,
  # which is the only reason `provides` can name bin/zless at all.
  #
  # ac_cv_prog_MORE=more is there for symmetry and gates NOTHING: configure.ac
  # :63-64 defines the MORE conditional and Makefile.am:58-59 lists `zmore`
  # unconditionally. Stated rather than removed, because removing it would be a
  # change to a working build for a reason this recipe cannot verify — whether
  # an unseeded MORE probe is slow or noisy in some sandbox.
  script = [
    "./configure $ARGS ac_cv_prog_LESS=less ac_cv_prog_MORE=more",
    "make --jobs {{ hw.concurrency }} install CFLAGS=\"$MAKE_CFLAGS\"",
  ]
}

# ⛔ FOURTEEN NAMES, AND THEY COME FROM THREE DIFFERENT PLACES in gzip's own
# Makefile.am. A converted recipe would list them correctly and be unable to say
# why, which is the whole point of writing these:
#
#   Makefile.am:57     bin_PROGRAMS = gzip                     1 compiled binary
#   Makefile.am:58-59  bin_SCRIPTS = gunzip gzexe zcat zcmp    12 shell scripts,
#                      zdiff zegrep zfgrep zforce zgrep        one of them
#                      $(ZLESS_PROG) zmore znew                 conditional
#   Makefile.am:145    install-exec-hook: … gunzip)            1 alias, hard-
#                      aliases='uncompress'                     linked at install
#
# 1 + 12 + 1 = 14. The hook at :145-165 links `uncompress` to `gunzip` with
# `ln`, falling back to `$(LN_S)`, so it is a real installed name and not a
# convenience the packager invented.
provides = [
  "bin/gunzip",
  "bin/gzexe",
  "bin/gzip",
  "bin/uncompress",
  "bin/zcat",
  "bin/zcmp",
  "bin/zdiff",
  "bin/zegrep",
  "bin/zfgrep",
  "bin/zforce",
  "bin/zgrep",
  "bin/zless",
  "bin/zmore",
  "bin/znew",
]

test {
  script = [
    "gzip --version | grep {{version.raw}}",

    # ⛔ A ROUND TRIP, THROUGH EACH OF THE THREE FAMILIES, because the three are
    # installed by three different mechanisms and a test that exercised only
    # the compiled binary would pass with every script missing.
    #
    # The input was `tea.xyz.test-string` — a name from the project this
    # ecosystem forked from, left in a test that never checked anything about
    # it. Replaced by a string whose LENGTH matters: it is longer than its own
    # gzip header, so a round trip that silently produced an empty file cannot
    # pass.
    "test \"$(printf '%s' \"$INPUT\" | gzip -c | gunzip -c)\" = \"$INPUT\"",
    "test \"$(printf '%s' \"$INPUT\" | gzip -c | zcat)\" = \"$INPUT\"",

    # The install hook's alias, asserted as itself: `uncompress` is the one name
    # here that no Makefile variable lists.
    "test \"$(printf '%s' \"$INPUT\" | gzip -c | uncompress -c)\" = \"$INPUT\"",

    # And the conditional one. If ac_cv_prog_LESS were dropped from the build
    # script above, THIS is the line that would go red rather than the recipe
    # silently shipping thirteen of fourteen names.
    "test -x {{prefix}}/bin/zless",
  ]

  env {
    INPUT = "the quick brown fox jumps over the lazy dog, compressibly"
  }
}

provenance {
  read = [
    "Makefile.am",  # :57 bin_PROGRAMS, :58-59 bin_SCRIPTS, :33-39 the LESS gate, :145-165 the uncompress hook
    "configure.ac", # :61-64 the LESS and MORE probes, and which of them is used
    "COPYING",      # the GPLv3 text that ships
    "gzip.c",       # :9 "either version 3, or (at your option) any later version"
  ]

  consulted = [
    "pkgxdev/pantry projects/gnu.org/gzip/package.yml",
  ]

  note = <<EOT
The build script's shape — configure with a prefix, then `make install` — came
from the upstream recipe and is unremarkable autotools. What this recipe adds is
the BASIS for its two lists, both of which the upstream recipe states without
one:

  - `provides` is 1 + 12 + 1 names from three different mechanisms, one of them
    an install hook and one of them conditional;
  - `ac_cv_prog_LESS=less` is not noise: it is what makes the conditional name
    exist in a sandbox with no less.

⛔ AND THE DIGEST IS VOUCHED FOR, which is new in this tree. The archive's
detached signature was verified when the digest was recorded, not at build time:
the signature's job is to justify WRITING the hash, and the hash is then the
durable pin. That division is Guix's — its `origin` record has no signature
field at all because `guix refresh` does the checking — and it is why this
recipe needs no key at build time and no network beyond the tarball.

Two honest limits on the warrant, stated because every other distribution's
documentation is silent on them:

  - the key came from https://ftp.gnu.org/gnu/gnu-keyring.gpg, which is served
    by the SAME HOST as the tarball. That establishes continuity, not
    independence: a host serving different bytes could serve a matching
    keyring. It is still strictly more than a digest alone, because the
    signature is over the archive and the keyring is a published, dated,
    widely-mirrored artefact — but it is not a key obtained out of band, and
    saying so is the point of recording where a fingerprint came from.
  - the keyring holds every GNU maintainer's key, so the fingerprint had to be
    named: without it, "verified" would have meant "somebody in that file
    signed it". 326 primary keys were walked to reach this one.
EOT
}
