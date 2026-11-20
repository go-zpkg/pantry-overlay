# gawk — GNU Awk, and the `awk` every autotools configure script runs.
#
# ⛔ WRITTEN FROM GAWK'S OWN FILES at 5.3.2, continuing #88 after gnu.org/m4,
# gnu.org/make and gnu.org/sed (go-zpkg/packages#440, go-zpkg/packages#431).
# It was a four-line fragment declaring one darwin dependency.
#
# ⭐ AND IT IS THE FIRST OF THESE WHERE READING THE SOURCE CHANGED A
# DEPENDENCY LIST RATHER THAN A FLAG LIST: gawk links libmpfr AND libgmp when
# it finds them, declares neither, and both are in the seed's own closure — so
# the artifact's dependencies were decided by what happened to be staged.

summary = "GNU Awk: pattern scanning and processing language"

# COPYING is the GPLv3 text ("GNU GENERAL PUBLIC LICENSE / Version 3,
# 29 June 2007"); main.c:14 carries "either version 3 of the License, or".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/gawk/"
  match = "/gawk-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^gawk-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/gawk/gawk-{{version.raw}}.tar.xz"
  strip-components = 1

  # BOTH lines are pinned, on purpose. `versions` resolves 23 releases and
  # 5.4.1 is the newest, so a consumer that names no constraint builds 5.4.1;
  # the base toolchain pins `~5.3` and builds 5.3.2. A digest for only one of
  # them would leave the other fetched unpinned, which is the half of the job
  # that is easy to forget because nothing fails.
  #
  #   5.3.2  3 749 260 bytes, signed 2025-04-02
  #   5.4.1  3 838 416 bytes
  #   5.4.2  3 888 524 bytes, signed 2026-11-16 (added for go-zpkg/recipes#208)
  #
  # All three verified against the same key with `zpkb sourcepin`:
  #
  #   signed by  D1967C63788713177D861ED7DF597815937EC0D2
  #              Arnold Robbins <arnold@skeeve.com>
  #   found      after walking 347 primary key(s) of ftp.gnu.org's keyring
  #              (348 when 5.4.2 was checked, 2026-11-20)
  #   checked    when each digest was recorded, not at every build
  #
  # ⛔ WHERE THIS CHAIN IS WEAKER THAN gnu.org/sed's, STATED RATHER THAN
  # INHERITED. sed's fingerprint is published by its release announcement, on
  # lists.gnu.org — a different host from the archive — so an independent
  # document attests the key. **Gawk's announcements publish nothing of the
  # kind**: info-gnu 2025-04/msg00003 ("Gawk 5.3.2 is now available") carries
  # no checksum, no fingerprint, no key id, and does not mention signatures at
  # all. Read, not assumed.
  #
  # So the fingerprint here comes from the signature itself, and what raises it
  # above circular is that the key is IN GNU's curated maintainer keyring under
  # that identity — a statement by the project rather than by the signature.
  # Its limit is the single host: the keyring and the tarball are both served
  # by ftp.gnu.org, which is continuity, not independence.
  #
  # ⭐ Three recipes, three different strengths, and the difference is a fact
  # about each project rather than a policy of ours: gnu.org/sed has an
  # independent fingerprint AND a published digest; gnu.org/gawk has a key in
  # the keyring and nothing published; gnu.org/make's key is ABSENT from that
  # keyring entirely (#113) and its signature is recorded unverified.
  sha256 = {
    "5.3.2" = "f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc"
    "5.4.1" = "07f6f7342b7febe4313fc2c2542ad93d64fe20ad8717200109f105a826f5fd37"
    "5.4.2" = "b95e4909533b5f988c6b5e5539b3b3ddf76e7d7df02ca2e5b5b7d6f62db78e6a"
  }

  # ⛔ NO `sha` FIELD: it means "where the expected SHA-256 is PUBLISHED", a
  # file the build fetches and compares, and a `.sig` there fails every build
  # (#89). The signature URLs live in `provenance` (go-zpkg/zpkb#282).
}

build {
  # ⛔⛔ DECLARED BECAUSE GAWK LINKS THEM AND SAYS SO NOWHERE.
  # `m4/mpfr.m4:15-18` is `AC_ARG_WITH([mpfr], …, [_do_mpfr=yes])` — the
  # default is YES, i.e. "look for it" — and `:27-32` links the probe with
  # `_combo="-lmpfr -lgmp"` through `AC_LINK_IFELSE`. `configure.ac:446-448`
  # reaches it whenever `SKIP_MPFR=no`, which is the default (`:68`).
  #
  # So on a builder that has gmp and mpfr staged, gawk comes out linked
  # against both, with nothing in the recipe saying so; on one that does not,
  # the same recipe produces a gawk without `-M`. That is the
  # `with_selinux=maybe` shape this fleet has paid for three times
  # (overrides/gnu.org-{coreutils,sed}.hcl, and gnu.org/sed's own recipe) — an
  # artifact whose dependencies depend on the machine.
  #
  # ⭐ KEPT RATHER THAN DISABLED, and that is the choice the measurement
  # allows. `--disable-mpfr` would be the easy fix and would silently drop
  # `gawk -M` from a tool consumers install. Declaring instead makes the build
  # DETERMINISTIC — the dependency is staged, so the probe always finds it —
  # and makes the closure honest. The ordering was checked before deciding:
  # `seed/order.txt` builds gnu.org/gmp at line 31 and gnu.org/mpfr at 32,
  # with gnu.org/gawk at 123, so declaring them adds no edge the seed does not
  # already satisfy.
  dependencies = {
    "gnu.org/gmp"  = "*"
    "gnu.org/mpfr" = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ LOAD-BEARING, and it is what makes the fragment this recipe
      # replaces unnecessary. `configure.ac:182` is `AM_GNU_GETTEXT([external])`
      # — gawk bundles no libintl — and the overlay entry here was exactly
      # `dependencies.darwin: gnu.org/gettext ^1`, the libintl-on-darwin
      # correction. With NLS off there is nothing to link on any platform, so
      # this recipe declares no gettext at all. Same resolution as
      # gnu.org/sed's.
      "--disable-nls",

      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]
  }

  # ⛔ TWO DEFAULTS LEFT ALONE, EACH FOR A STATED REASON, AND THEY ARE NOT THE
  # SAME REASON:
  #
  #   --enable-pma (configure.ac:77-84, SKIP_PERSIST_MALLOC=no) is gawk's own
  #   bundled persistent memory allocator. No external input, so nothing about
  #   the builder can change the result.
  #
  #   --enable-extensions (:334-352) is documented "default is detect", and the
  #   detection is `dlfcn.h` plus `dlopen` in libc or -ldl. Those come from
  #   gnu.org/glibc, which is a base-toolchain member and therefore always
  #   staged — so the detection's inputs are fixed and its outcome is not
  #   host-dependent. That is the difference from mpfr, whose input is a
  #   package that may or may not be there, and it is why one is declared and
  #   the other is not.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# `Makefile.am:72-73` — `bin_PROGRAMS = gawk` and `bin_SCRIPTS = gawkbug`.
#
# ⛔⛔ AND `install-exec-hook` (:155-163) INSTALLS TWO MORE NAMES, which no
# `_PROGRAMS` line mentions and which a reader of the Makefile's variables
# alone would miss:
#
#   bin/awk            a SYMLINK ($(LN_S)) to gawk — this is how `awk`
#                      resolves on PATH in a from-scratch tree, and every
#                      autotools configure script runs `awk`
#   bin/gawk-5.3.2     a HARD LINK ($(LN) = ln) named after the version
#
# `bin/awk` is listed: it is the name consumers and configure scripts actually
# use. The versioned hard link is deliberately NOT listed — its name moves with
# every release, so a static `provides` entry for it would be wrong the next
# time the version does.
#
# ⛔ The hook runs `sed '$(transform)'`, so building gawk needs a sed. Not a
# self-dependency and not gawk's problem: the base toolchain stages gnu.org/sed
# beside gawk, which is the same reading that kept gnu.org/sed's own recipe
# from naming itself (projects/gnu.org/grep/package.hcl:65-71).
provides = [
  "bin/gawk",
  "bin/awk",
  "bin/gawkbug",
]

test {
  script = [
    "gawk --version | grep {{version.raw}}",

    # ⛔ THE LINK, NOT THE BINARY. `awk` is the name autotools runs, and it
    # exists only because install-exec-hook made it. A gawk installed without
    # that hook passes every other assertion here and breaks every configure
    # script in the factory.
    "test \"$(awk 'BEGIN { print \"linked\" }')\" = linked",

    # Field splitting and $0 rewriting: what a configure script's awk actually
    # does, and the oldest contract awk has.
    "test \"$(printf 'a b c\\n' | awk '{ print $2 }')\" = b",
    "test \"$(printf '1\\n2\\n3\\n' | awk '{ s += $1 } END { print s }')\" = 6",

    # ⛔⛔ THE ASSERTION FOR THE DEPENDENCY THIS RECIPE ADDED, and it is read
    # from gawk's own source rather than guessed. `main.c:1362-1364`:
    #
    #   #ifdef HAVE_MPFR
    #       printf(", (GNU MPFR %s, GNU MP %s)", mpfr_get_version(), gmp_version);
    #   #endif
    #
    # So the version string names MPFR and MP if and ONLY IF the build linked
    # them. Without this, a build on a machine where the probe failed would
    # produce a gawk that declares mpfr and cannot use it — the exact mismatch
    # the declaration exists to prevent, passing in silence.
    #
    # ⛔ The first version of this test asserted `gawk -M 'BEGIN { PREC = 200;
    # print 2 ** 100 }'` equalled 1267650600228229401496703205376, which
    # presumes how `print` formats a bignum — gawk has no gawk on this machine
    # to check it against, and `print` normally goes through CONVFMT/OFMT
    # (`%.6g`). An expectation nobody can verify is not a test. The version
    # string is a fact about the BUILD and is what this line is about.
    "gawk --version | grep 'GNU MPFR'",
    "gawk --version | grep 'GNU MP '",

    # The same witness for the other decision left at its default:
    # `main.c:1356-1358` prints `, API <major>.<minor>` only `#ifdef DYNAMIC`,
    # which is what --enable-extensions sets. A gawk built without dynamic
    # extensions says nothing there.
    "gawk --version | grep 'API '",
  ]
}

provenance {
  read = [
    "configure.ac",   # :26 AC_INIT 5.3.2; :68-75 SKIP_MPFR defaults to no; :77-84 pma default on; :182 AM_GNU_GETTEXT external; :334-352 extensions "default is detect" via dlfcn.h/dlopen; :446-448 GNUPG_CHECK_MPFR is reached whenever SKIP_MPFR=no
    "m4/mpfr.m4",     # :15-18 --with-mpfr defaults to YES; :27-32 the probe links `-lmpfr -lgmp` with AC_LINK_IFELSE
    "Makefile.am",    # :58-69 SUBDIRS; :72 bin_PROGRAMS = gawk; :73 bin_SCRIPTS = gawkbug; :137 LN = ln; :155-163 install-exec-hook makes bin/awk (symlink) and bin/gawk-<version> (hard link), through `sed '$(transform)'`
    "doc/Makefile.am", # :28 info_TEXINFOS (four manuals); :30 man_MANS = gawk.1 gawkbug.1 pm-gawk.1
    "main.c",          # :1356-1364 the version string names API only #ifdef DYNAMIC, PMA only #ifdef USE_PERSISTENT_MALLOC, and "(GNU MPFR …, GNU MP …)" only #ifdef HAVE_MPFR — the three witnesses the test block uses; :1018-1021 the same values in PROCINFO
    "COPYING",        # the GPLv3 text that ships, and main.c:14 "either version 3 of the License, or"
  ]

  consulted = [
    "https://lists.gnu.org/archive/html/info-gnu/2025-04/msg00003.html",
    "go-zpkg/zpkb build/build.go",      # :237 ToolchainGawk = "~5.3", stated once; :346-347 the constraint table
    "go-zpkg/zpkb build/build_test.go", # :129-131 WHY the pin exists, measured
    "go-zpkg/packages seed/order.txt",  # gmp at 31, mpfr at 32, gawk at 123
    "gnu.org/sed/package.hcl",          # the same libintl resolution, and the stronger trust chain this one is compared against
  ]

  note = <<EOT
Fourth of the base-toolchain members written from the project's own files
(#88). Nothing was converted.

⛔⛔ WHY THE TOOLCHAIN PINS `~5.3` WHILE THIS RECIPE PINS DIGESTS FOR BOTH
LINES, and the reason is not this recipe's to decide. `zpkb`'s
`build.ToolchainGawk` is `"~5.3"`, stated once in build/build.go:237, and its
test says what for: *"gawk is pinned to 5.3 (5.4.1 regressed autotools
config-header generation, e.g. libpng's pnglibconf drops PNG_SETJMP_SUPPORTED)"*
(build/build_test.go:129-131). That is a measured symptom in a third package,
not a dislike of the newer release.

⭐ I had remembered that pin as "5.4.1 mishandles autoconf's option-resolution
scripts" and wrote it that way in a draft. Reading build_test.go corrected it.
A pin's reason is a dated claim like any other, and the file that states it is
the one to quote.

The constraint spellings matter and zpkb records them beside the pin
(build/build.go:346-347): `gawk^5.3 → 5.4.1`, `gawk<5.4 → 5.3.2`,
`gawk@5.3.2 → 5.4.1`, `gawk@=5.3.2 → 5.3.2`. So `~5.3` is the form that
actually selects the 5.3 line — "it read as a pin for as long as it existed
because no 5.3.x was published for darwin: vacuous and misspelt are
indistinguishable until the version you meant to select exists."

⭐ THE DOCUMENTATION NEEDS NO TOOL TO BUILD, as for the three before it. doc/
ships gawk.info, gawkinet.info, gawkworkflow.info and pm-gawk.info, plus
gawk.1, gawkbug.1 and pm-gawk.1, all prebuilt — checked file by file because
`man_MANS` names pm-gawk.1 and `info_TEXINFOS` names pm-gawk.texi, and a man
page named but not shipped is what would pull in help2man. All seven are
there, so neither gnu.org/texinfo nor gnu.org/help2man is needed; both are
base-toolchain members without standalone recipes, and declaring either would
make a cycle out of a seed.

The signatures, for the record:

  https://ftp.gnu.org/gnu/gawk/gawk-5.3.2.tar.xz.sig  (488 bytes)
  https://ftp.gnu.org/gnu/gawk/gawk-5.4.1.tar.xz.sig
  https://ftp.gnu.org/gnu/gawk/gawk-5.4.2.tar.xz.sig  (signed 2026-11-16T11:34:48Z)
  key         ftp.gnu.org/gnu/gnu-keyring.gpg, local copy
  identity     Arnold Robbins <arnold@skeeve.com>
  fingerprint  D1967C63788713177D861ED7DF597815937EC0D2, from the signature
               itself — the announcements publish none — raised above circular
               only by the key's presence in GNU's curated keyring
  checked      when each digest was recorded, not at every build

No keyserver was asked. An unknown key is a refusal here, not a download.
EOT
}
