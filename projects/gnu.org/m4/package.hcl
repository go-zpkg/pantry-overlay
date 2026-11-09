# m4 — GNU M4, the macro processor autoconf is written in.
#
# ⛔ WRITTEN FROM M4'S OWN FILES at 1.4.21, and it is the FIRST OF THE FOURTEEN
# (#88). The base toolchain names 25 members and 14 of them had no recipe of
# ours at all — not fragments, absent — so the sovereign registry cannot be
# built until they exist (go-zpkg/packages#440, go-zpkg/packages#431). These
# are the tools everything else is built WITH, which is why they come before the
# other 195.
#
# ⭐ AND IT IS THE FIRST RECIPE HERE WITH NO DEPENDENCIES AT ALL, which is a
# finding and not an omission: see the build block.
#
# `base-toolchain/package.hcl:85` wants it as "autoconf's macro processor", and
# that is understated — autoconf IS m4 macros, so autoconf, automake, libtool
# and bison all wait on this one.

summary = "GNU M4: a macro processor"

# COPYING is the GPLv3 text; src/m4.c:8-11 carries "either version 3 of the
# License, or (at your option) any later version". Both files, because only the
# second answers the "-or-later".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/m4/"
  match = "/m4-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^m4-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/m4/m4-{{version.raw}}.tar.xz"
  strip-components = 1

  # Recorded with `zbk sourcepin --sig auto --key <gnu-keyring.gpg>
  # --fingerprint "71C2 CC22 B1C4 6029 27D2  F3AA A7A1 6B4A 2527 436A"`:
  # 2 080 016 bytes, signed by Eric Blake <eblake@redhat.com>, the named key
  # found after walking 327 primary keys in the GNU keyring.
  #
  # ⭐⭐ AND THE DIGEST HAS A SECOND, INDEPENDENT WITNESS, which the three GNU
  # recipes before it did not. The release announcement publishes it:
  #
  #   m4-1.4.21.tar.xz
  #   SHA256 sum:   f25c6ab51548a73a75558742fb031e0625d6485fe5f9155949d6486a2408ab66
  #
  # — the same string our own fetch-and-hash produced. Two sources that do not
  # derive from each other agree, which is a stronger statement than "the host
  # that served the tarball also served a signature for it".
  #
  # ⛔ THE FINGERPRINT CAME FROM THE ANNOUNCEMENT, NOT FROM THE KEYRING, and it
  # had to: `gnu-keyring.gpg` CANNOT BE READ WHOLE (one entity in a thirty-year
  # archive has multiple embedded signatures and `ReadKeyRing` then returns
  # nothing), so there is no way to ask it "which key signed this". Naming the
  # key is what rescues the file by reading only that one. The announcement says
  # "The signature should match the fingerprint of the following key" and then
  # prints `pub rsa2048/0xA7A16B4A2527436A`.
  #
  # ⛔ AND ITS KEY LISTING HOLDS A SECOND FINGERPRINT, under a photo-ID line
  # (`4441 8D9D 02D6 9912 052A  708E D205 1C2F D2E4 726C`). It is not the
  # signing key: the primary's fingerprint ends in the same `2527436A` as the
  # key id on the `pub` line, and that is the one pinned. A reader skimming for
  # "Key fingerprint =" would find the wrong one first.
  sha256 = {
    "1.4.21" = "f25c6ab51548a73a75558742fb031e0625d6485fe5f9155949d6486a2408ab66"
  }

  # ⛔ NO `sha` FIELD HERE. The three signed recipes before this one recorded
  # the SIGNATURE's URL in `sha`, and `sha` means "where the expected SHA-256 is
  # published" — a file the build FETCHES and compares. It would have failed
  # every build (#89). The signature URL lives in `provenance` below, because
  # no schema field exists for one (go-zpkg/zbk#282).
}

build {
  # ⛔⛔ NOTHING. NOT AN OMISSION — READ FOR, AND NOT FOUND.
  #
  # m4 is C with gnulib vendored into lib/, and its one candidate external
  # dependency is OPT-IN: `m4/sigsegv.m4:13-20` gates libsigsegv behind
  # `--with-libsigsegv`, and without it the bundled gnulib `sigsegv` module is
  # used (`if test "$with_libsigsegv" = yes … else gl_sigsegv_uses_libsigsegv=no`).
  # So a C compiler and make are the whole requirement, and those come from the
  # toolchain this recipe is a member of.
  #
  # ⭐ WHICH IS THE PROPERTY THAT MAKES IT THE RIGHT ONE TO WRITE FIRST: a seed
  # has to be buildable before the things it seeds exist. A recipe needing
  # pkg-config or gettext could not be, because both are also among the
  # fourteen.
  env {
    ARGS = [
      "--prefix={{prefix}}",
      # ⛔ `AM_GNU_GETTEXT([external], …)` (configure.ac:231) — m4 does NOT
      # bundle libintl, so NLS would be a real build dependency on
      # gnu.org/gettext, which is ALSO one of the fourteen. This flag is
      # therefore load-bearing here rather than the house habit it is elsewhere.
      "--disable-nls",
      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]
  }

  # ⛔ `--with-syscmd-shell` IS LEFT AT ITS DEFAULT, /bin/sh, AND THAT IS A
  # DECISION. configure.ac:192-209 bakes the shell m4's `syscmd`/`esyscmd` will
  # exec into the binary, defaulting to /bin/sh — and when cross-compiling it
  # takes that default with NO probe at all.
  #
  # In a FROM-scratch tree that could be a path to nothing. It is not:
  # `build/runner.go:303-305` states that "in the sovereign generation /bin/sh
  # is a symlink to $ZPKG_DIR/gnu.org/bash/v<ver>/bin/bash", because $ORIGIN in
  # its RUNPATH has to resolve from the real location.
  #
  # ⭐ So /bin/sh is BETTER here than naming the store path would be: the
  # symlink is the indirection that survives gnu.org/bash being rebuilt at a new
  # version, whereas a baked-in `$ZPKG_DIR/gnu.org/bash/v5.3/bin/bash` would
  # pin this bottle to one version of another package. The test below asserts
  # it resolves.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:27 — `bin_PROGRAMS = m4`, and there is no `bin_SCRIPTS`.
# `noinst_HEADERS = m4.h` installs nothing, and examples/Makefile.am has only
# EXTRA_DIST, so one binary is the whole of it.
provides = [
  "bin/m4",
]

test {
  script = [
    "m4 --version | grep {{version.raw}}",

    # The macro processor actually processing a macro. define/expand is the one
    # thing every autoconf run does millions of times.
    "test \"$(echo 'define(greet,hello)greet' | m4)\" = hello",

    # ⛔⛔ THE ASSERTION THAT COSTS NOTHING AND ANSWERS THE BUILD'S ONE REAL
    # QUESTION. `esyscmd` execs the shell that was compiled in — /bin/sh, per
    # the build note above — so this is what proves the default resolved in the
    # tree this bottle was built in. If /bin/sh were absent or not a shell,
    # m4 would still pass `--version` and every expansion above, and autoconf
    # would fail later with a message about something else entirely: m4's own
    # configure.ac:21 calls `m4_esyscmd([build-aux/git-version-gen …])`, so the
    # tool that cannot run a shell breaks the tool that builds itself.
    "test \"$(echo 'esyscmd(echo shell-works)' | m4)\" = shell-works",

    # A macro that is NOT defined expands to itself rather than to nothing,
    # which is the behaviour autoconf relies on to detect its own typos.
    "test \"$(echo 'undefined_macro' | m4)\" = undefined_macro",
  ]
}

provenance {
  read = [
    "src/Makefile.am",  # :27 bin_PROGRAMS = m4, :28 noinst_HEADERS — one binary
    "configure.ac",     # :21 m4_esyscmd; :181-190 --enable-changeword; :192-209 --with-syscmd-shell; :231 AM_GNU_GETTEXT external
    "m4/sigsegv.m4",    # :13-20 --with-libsigsegv is OPT-IN; gnulib's module otherwise
    "m4/libsigsegv.m4", # :13-15 what it would link if asked
    "doc/Makefile.am",  # :23 info_TEXINFOS, :25 man_MANS = $(srcdir)/m4.1
    "examples/Makefile.am", # :23 EXTRA_DIST only — installs nothing
    "Makefile.am",      # :23 SUBDIRS
    "COPYING",          # the GPLv3 text that ships
    "src/m4.c",         # :8-11 "either version 3 of the License, or"
  ]

  consulted = [
    "https://lists.gnu.org/archive/html/info-gnu/2026-02/msg00004.html",
    "go-zpkg/base-toolchain/package.hcl", # :85, which asks for m4 by name
  ]

  note = <<EOT
First of the fourteen base-toolchain members that had no recipe of ours
(#88). Nothing was converted: the version, the digest, the one configure flag
that matters and the four assertions all come from m4's own files and from the
release announcement.

⭐ THE DOCUMENTATION NEEDS NO TOOL TO BUILD. doc/ ships m4.info, m4.info-1,
m4.info-2 and m4.1 pre-built in the tarball (doc/Makefile.am:25 lists m4.1 in
both man_MANS and MAINTAINERCLEANFILES — the maintainer generates it, the
tarball carries it). So `make install` installs the manual and the man page
without makeinfo or help2man, and this recipe declares neither — which matters
because gnu.org/texinfo and gnu.org/help2man are ALSO among the fourteen, and
declaring them would have made a cycle out of a seed.

⛔ The one way that could still go wrong is timestamp skew: if `make` decides
the shipped .info is older than m4.texi it will call makeinfo. The builder's
sanitised environment no-ops ACLOCAL/AUTOMAKE/AUTOCONF/AUTOHEADER/AUTOPOINT and
DELIBERATELY NOT MAKEINFO (build/build.go:758-763: it "produces .info manuals
that some recipes then INSTALL", and forcing it to true made glibc's install
step fail). So the hazard is real and is not mitigated by a flag here; it is
named rather than hidden, and a build that hits it will say `makeinfo: command
not found` rather than something obscure.

The digest is signature-verified:

  signature    https://ftp.gnu.org/gnu/m4/m4-1.4.21.tar.xz.sig  (ASCII-armoured)
  key          https://ftp.gnu.org/gnu/gnu-keyring.gpg
  identity     Eric Blake <eblake@redhat.com>
  fingerprint  71C2CC22B1C4602927D2F3AAA7A16B4A2527436A, from the release
               announcement rather than from the keyring
  checked      when the digest was recorded, not at every build

⭐ Unlike gzip, grep and bash, this one's limits are NOT the same, and the
difference is worth stating rather than inheriting:

  - the fingerprint came from the info-gnu announcement, which is published by
    a different host than the tarball. For the other three it came from this
    fleet's own notes, and the keyring was served by the SAME host as the
    archive — continuity, not independence. Here one leg of the chain is
    genuinely independent;
  - and the announcement also publishes the SHA-256, which our own
    fetch-and-hash reproduced byte for byte. That is a second witness to the
    bytes, not merely to the key.

What stays shared with them: the keyring holds every GNU maintainer's key, so
the fingerprint had to be named or "verified" would have meant "somebody in
that file signed it".
EOT
}
