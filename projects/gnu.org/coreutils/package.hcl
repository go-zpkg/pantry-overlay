# coreutils — the programs every other build in this factory runs.
#
# ⛔ WRITTEN FROM COREUTILS' OWN FILES at 9.12, continuing #88 after m4, make,
# sed, gawk and help2man (go-zpkg/packages#440, go-zpkg/packages#431). It was a
# four-line fragment declaring one darwin dependency.
#
# ⭐ IT IS THE ONE WHOSE `provides` TOOK THREE READINGS, each catching errors in
# the last. The note above the list says what they were, because a `provides`
# that names files an artifact does not contain is the kind of wrong nothing
# fails on.

summary = "GNU coreutils: the basic file, shell and text utilities"

# COPYING is the GPLv3 text; the sources carry "either version 3 of the
# License, or (at your option) any later version".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/coreutils/"
  match = "/coreutils-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^coreutils-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/coreutils/coreutils-{{version.raw}}.tar.xz"
  strip-components = 1

  # 6 704 996 bytes, fetched and hashed with the builder's own fetcher.
  sha256 = {
    "9.12" = "a480198559733e9b3da999e90543ac6f888a2caa544d8d664c5a1f17e528e210"
  }

  # ⭐⭐ THE SIGNATURE VERIFIES, AND GETTING THERE SETTLED A QUESTION
  # gnu.org/make's recipe had left open.
  #
  #   signature  coreutils-9.12.tar.xz.sig — algo 1 (RSA), digest algo 10
  #              (SHA-512), signed 2026-09-14
  #   key        6C37DC12121A5006BC1DB804DF6FD971306037D9
  #   identity   Pádraig Brady <P@draigBrady.com>
  #
  # `sourcepin` against the whole GNU keyring refuses:
  #
  #   no key matching 6C37DC12… among the 402 primary key(s) that could be
  #   read, and the packet stream stops being readable after them
  #
  # — the same sentence make's recipe met, whose disjunction was "either the
  # key is beyond that point, or the selector is wrong". For THIS key the first
  # disjunct is true: gpg reads the whole file and verifies the signature, so
  # the key is present and simply beyond where the Go reader stops.
  #
  # ⭐ And that makes the fix mechanical: export the one key and pass it.
  #
  #   gpg --export --armor 6C37DC12… > padraig-brady-306037D9.asc   (6 925 bytes)
  #   zpkb sourcepin --key padraig-brady-306037D9.asc --fingerprint 6C37DC12…
  #     → signed by 6C37DC12…, Pádraig Brady, "1 key(s) read from the file"
  #
  # The key still comes from ftp.gnu.org's keyring; only the reading changed.
  # ⛔ The fingerprint is still the one the SIGNATURE names — coreutils'
  # announcements were not consulted, so this chain has no independently
  # published fingerprint, like gnu.org/gawk's and unlike gnu.org/sed's.
  #
  # So the keyring now has three measured outcomes across five recipes:
  # reachable (sed at 326, gawk at 347), BEYOND THE BREAK but exportable
  # (this one), and exportable but EXPIRED (make, #116).
}

build {
  # ⛔ NO DEPENDENCIES, AND THE DARWIN ONE THIS REPLACES IS GONE.
  # `configure.ac:923` is `AM_GNU_GETTEXT([external], [need-formatstring-macros])`
  # — coreutils bundles no libintl — and the fragment here was exactly
  # `dependencies.darwin: gnu.org/gettext *`, the same libintl-on-darwin
  # correction gnu.org/sed and gnu.org/gawk carried. `--disable-nls` removes
  # the coupling on every platform.
  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--disable-nls",

      # ⛔⛔ THE FLAG THE WHOLE SOVEREIGN GENERATION DEPENDS ON, and the
      # override in go-zpkg/packages carries the measurement:
      #
      #   mkdir: error while loading shared libraries: libselinux.so.1:
      #   cannot open shared object file
      #
      # on the s390x sovereign lane, where there is no host to fall back on —
      # and coreutils is the FIRST thing any build runs, so the generation
      # stops there. The cause is gnulib's
      # `AC_ARG_WITH([selinux], …, [], [with_selinux=maybe])`: `maybe` is
      # auto-detection, and every Ubuntu builder HAS libselinux. Still live at
      # 9.12 (`configure.ac:526-527`), checked rather than inherited.
      #
      # The trade is deliberate and upstream's own: `ls -Z` and
      # `cp --preserve=context` go away, along with `chcon` and `runcon`
      # entirely (see `provides`). An artifact that cannot start anywhere is
      # worth less than one that cannot label a file.
      "--without-selinux",

      # ⛔ THE THIRD AUTO-DETECTION OF THE DAY, after gawk's mpfr and sed's
      # selinux. `configure.ac:62` is
      # `gl_SET_CRYPTO_CHECK_DEFAULT([auto-gpl-compat])`, and
      # `m4/gl-openssl.m4:23-39` defaults `--with-openssl` to that value: with
      # openssl present and GPL-compatible — 3.x is — the hash utilities link
      # **libcrypto** and nothing declares it.
      #
      # The risk is not theoretical here: `seed/order.txt` builds openssl.org
      # at line 28 and coreutils at 120, so openssl IS in the store when this
      # is built.
      #
      # ⭐ DISABLED rather than declared, which is the opposite of the choice
      # gnu.org/gawk made about mpfr, and the difference is what is lost.
      # Disabling mpfr would have removed `gawk -M`, a feature; disabling
      # libcrypto removes nothing — gnulib's own implementations compute the
      # same digests, only slower. Against that: coreutils is the package every
      # other build in this factory depends on, so an openssl edge here puts
      # openssl in essentially every closure. Minimal closure wins when the
      # feature set does not change.
      "--without-openssl",

      # ⛔ `kill` and `uptime` ARE NOT INSTALLED BY DEFAULT — `src/cu-progs.mk`
      # puts them in `no_install__progs` (:6-7), because util-linux and procps
      # traditionally own those names, and `m4/include-exclude-prog.m4:37-38`
      # is the flag that adds them back.
      #
      # Measured before keeping it: `github.com/util-linux/util-linux` and
      # `gitlab.com/procps-ng/procps` are both in go-zpkg/packages'
      # `recipes.txt`, so the REGISTRY publishes them — but neither is in
      # `seed/order.txt` nor in `builder/toolchain.txt`. In the seed and in the
      # builder image, coreutils is the only candidate, and without this flag
      # there is no `kill` and no `uptime` at all.
      #
      # ⚠ The consequence is a name this package shares with two others for a
      # consumer who installs them. Named here rather than discovered: it is
      # upstream's own reason for the default, and the flag is a deliberate
      # departure from it.
      "--enable-install-program=kill,uptime",

      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]
  }

  # ⭐⭐ THE MAN PAGES ARE REGENERATED ON EVERY BUILD, UNLIKE THE FIVE RECIPES
  # BEFORE THIS ONE, and it does not cost a dependency.
  #
  # `man/local.mk:72+` gives each page a rule whose prerequisite is the
  # BINARY — `man/ls.1: src/ls` — and src/ls is built here, so it is always
  # newer than the shipped page. Where m4, make, sed, gawk and help2man were
  # saved by a source file older than its generated output, coreutils cannot
  # be: the rule always fires.
  #
  # It still needs nothing external. `man/local.mk:19` ships **help2man
  # itself** (`man/help2man`) and `man/dummy-man`, and `:23-33` picks between
  # them: `$(PERL) -- man/help2man` when perl is there, `dummy-man` when cross
  # compiling or without perl. And `man/dummy-man:43-44` COPIES the
  # distributed page (`test -f "$dist_man" && cp "$dist_man" "$output"`) —
  # all 108 of which ship — writing a stub only if one is missing.
  #
  # So gnu.org/help2man is not a build dependency of coreutils even though
  # coreutils is why help2man is in the toolchain at all, and perl is optional.
  # `dummy-man` calls `sed`, which the base toolchain stages.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# ⛔⛔ 104 PROGRAMS, COMPUTED FROM `src/cu-progs.mk` AND THESE FLAGS — NOT FROM
# THE MAN PAGES, AND NOT TYPED. Three readings, each wrong until the next:
#
#  1. man/*.x cross-checked against man/*.1: 108 each, agreement reported.
#     ⛔ The agreement meant nothing — coreutils ships man pages for programs
#     it does NOT install, so the two sets shared the same mistake. A
#     cross-check between two readings with a common error is not a control.
#
#  2. The buckets in `src/cu-progs.mk`, which is the file coreutils generates
#     for exactly this question, minus what these flags leave out:
#       arch, coreutils, hostname   `no_install__progs` (:3-5), not named by
#                                   --enable-install-program
#       chcon, runcon               `build_if_appropriate__progs` (:21-22) —
#                                   built only with SELinux, which this recipe
#                                   disables
#     Five names the first list would have declared and the artifact would not
#     contain.
#
#  3. Reconciling the two sets EXACTLY, because 110 bucket entries against 108
#     man includes is a count that will not add up:
#       `ginstall`  is in default__progs with no man/ginstall.x, while
#                   `install` has a man page and is in no bucket.
#                   `man/local.mk:72` closes it: `man/install.1: src/ginstall`
#                   — built as ginstall, INSTALLED as install. Declaring
#                   `bin/ginstall` would have named a sixth absent file.
#       `[`         is in default__progs with no man/[.x because man/test.1
#                   covers it (`man/local.mk:73`), and IS installed.
#       `libstdbuf.so` is a library in build_if_possible__progs, installed to
#                   pkglibdir rather than bin/.
#
# ⚠ `build_if_possible__progs` (:9-19 — chroot, df, hostid, nice, pinky,
# stdbuf, stty, timeout, users, who) is itself conditional, on platform
# features rather than on a package: statvfs, utmp and the like. On
# linux/glibc all ten build. A platform where one does not would make this
# list wrong by that one, which is a real limit of a static `provides`.
provides = [
  "bin/[",
  "bin/b2sum",
  "bin/base32",
  "bin/base64",
  "bin/basename",
  "bin/basenc",
  "bin/cat",
  "bin/chgrp",
  "bin/chmod",
  "bin/chown",
  "bin/chroot",
  "bin/cksum",
  "bin/comm",
  "bin/cp",
  "bin/csplit",
  "bin/cut",
  "bin/date",
  "bin/dd",
  "bin/df",
  "bin/dir",
  "bin/dircolors",
  "bin/dirname",
  "bin/du",
  "bin/echo",
  "bin/env",
  "bin/expand",
  "bin/expr",
  "bin/factor",
  "bin/false",
  "bin/fmt",
  "bin/fold",
  "bin/groups",
  "bin/head",
  "bin/hostid",
  "bin/id",
  "bin/install",
  "bin/join",
  "bin/kill",
  "bin/link",
  "bin/ln",
  "bin/logname",
  "bin/ls",
  "bin/md5sum",
  "bin/mkdir",
  "bin/mkfifo",
  "bin/mknod",
  "bin/mktemp",
  "bin/mv",
  "bin/nice",
  "bin/nl",
  "bin/nohup",
  "bin/nproc",
  "bin/numfmt",
  "bin/od",
  "bin/paste",
  "bin/pathchk",
  "bin/pinky",
  "bin/pr",
  "bin/printenv",
  "bin/printf",
  "bin/ptx",
  "bin/pwd",
  "bin/readlink",
  "bin/realpath",
  "bin/rm",
  "bin/rmdir",
  "bin/seq",
  "bin/sha1sum",
  "bin/sha224sum",
  "bin/sha256sum",
  "bin/sha384sum",
  "bin/sha512sum",
  "bin/shred",
  "bin/shuf",
  "bin/sleep",
  "bin/sort",
  "bin/split",
  "bin/stat",
  "bin/stdbuf",
  "bin/stty",
  "bin/sum",
  "bin/sync",
  "bin/tac",
  "bin/tail",
  "bin/tee",
  "bin/test",
  "bin/timeout",
  "bin/touch",
  "bin/tr",
  "bin/true",
  "bin/truncate",
  "bin/tsort",
  "bin/tty",
  "bin/uname",
  "bin/unexpand",
  "bin/uniq",
  "bin/unlink",
  "bin/uptime",
  "bin/users",
  "bin/vdir",
  "bin/wc",
  "bin/who",
  "bin/whoami",
  "bin/yes",
]

test {
  script = [
    "ls --version | grep {{version.raw}}",

    # ⛔ THE ONE THAT WOULD HAVE CAUGHT THE s390x FAILURE. mkdir is what every
    # build runs first, and the libselinux defect showed up as mkdir refusing
    # to start — not as a wrong answer.
    "mkdir -p /tmp/cu-selftest/a/b && test -d /tmp/cu-selftest/a/b",

    # The two renamed names, asserted because both were wrong in a draft of
    # `provides`: `install` (built as ginstall) and `[` (man page is test.1).
    "install --version | grep {{version.raw}}",
    "test \"$(cd /tmp/cu-selftest && [ -d a ] && echo yes)\" = yes",

    # The flag's two programs. Without --enable-install-program they are not
    # in the store at all, and nothing else in the seed provides them.
    "kill -l | grep -q TERM",
    "uptime --version | grep {{version.raw}}",

    # ⛔⛔ THE ASSERTION FOR --without-openssl, and it is about the ANSWER
    # rather than the linkage: gnulib's implementation must compute the same
    # digest libcrypto would. The value is SHA-256 of the empty input, which
    # is a constant anybody can check.
    "test \"$(printf '' | sha256sum | cut -d' ' -f1)\" = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",

    # And that the SELinux tools are NOT there, which is what --without-selinux
    # means for this artifact's surface. A recipe that declared them would pass
    # every other line here.
    "test ! -e \"{{prefix}}/bin/chcon\"",
    "test ! -e \"{{prefix}}/bin/runcon\"",
  ]
}

provenance {
  read = [
    "configure.ac",                # :27 AC_INIT; :62 gl_SET_CRYPTO_CHECK_DEFAULT([auto-gpl-compat]); :526-527 the selinux decision is live; :923 AM_GNU_GETTEXT external
    "m4/gl-openssl.m4",            # :18 the default lives in a divert; :23-39 --with-openssl takes it when the flag is absent
    "m4/include-exclude-prog.m4",  # :37-47 --enable-install-program / --enable-no-install-program
    "m4/cu-progs.m4",              # :99-100 "add any program specified via --enable-install-program, and remove any …"
    "src/cu-progs.mk",             # :2-7 no_install__progs (arch, coreutils, hostname, kill, uptime); :8-19 build_if_possible__progs incl. libstdbuf.so; :20-22 build_if_appropriate__progs (chcon, runcon); 92 default__progs
    "src/local.mk",                # :28-36 EXTRA_PROGRAMS and bin_PROGRAMS = @bin_PROGRAMS@, i.e. configure decides
    "man/local.mk",                # :19 help2man and dummy-man are VENDORED; :23-33 the three run_help2man branches; :72-73 install.1 ← src/ginstall and test.1 ← src/[; each page depends on its BINARY
    "man/dummy-man",               # :43-44 it COPIES the distributed page, stub only if absent
    "COPYING",                     # the GPLv3 text that ships
  ]

  consulted = [
    "go-zpkg/packages overrides/gnu.org-coreutils.hcl", # the measured s390x libselinux failure this recipe carries natively
    "go-zpkg/packages seed/order.txt",                  # openssl.org at 28, coreutils at 120
    "go-zpkg/packages recipes.txt",                     # util-linux at 969 and procps-ng at 1001: the registry has them, the seed does not
    "gnu.org/gawk/package.hcl",                         # the opposite decision about an auto-detected library, and why
    "gnu.org/make/package.hcl",                         # the keyring disjunction this recipe's key settles
  ]

  note = <<EOT
Sixth of the base-toolchain members written from the project's own files (#88).
Nothing was converted. The fragment's one darwin dependency is gone, three
flags were added for three different measured reasons, and `provides` went
from absent to 104 names computed from the project's own bucket file.

⭐⭐ WHAT THIS ONE TAUGHT, and it is about method rather than coreutils: THE
CROSS-CHECK THAT AGREED WAS WORTHLESS. man/*.x against man/*.1 gave 108 and
108, and I reported agreement — but both are man-page sets, and coreutils
ships man pages for programs it does not install. Two readings that share a
mistake agree with each other perfectly. What actually found the five absent
names was asking a DIFFERENT question of a DIFFERENT file (which bucket is
each program in), and what found the sixth was a count that would not
reconcile: 110 buckets against 108 includes, whose difference named `ginstall`
and `[`.

So three readings, five then six corrections, on a field that no build would
ever have contradicted — `provides` is documentation to the resolver, and a
wrong entry fails at install time for somebody else.

The signature chain, and what it settles:

  signature    coreutils-9.12.tar.xz.sig, RSA/SHA-512, signed 2026-09-14
  key          6C37DC12121A5006BC1DB804DF6FD971306037D9
  identity     Pádraig Brady <P@draigBrady.com>
  keyring      ftp.gnu.org/gnu/gnu-keyring.gpg — the key is BEYOND the 402
               primary keys the Go OpenPGP reader manages before the file
               stops being readable, so `sourcepin` must be given the one key,
               exported with `gpg --export`
  verified     yes, "1 key(s) read from the file"
  fingerprint  from the signature itself; coreutils' announcements were not
               consulted, so there is no independently published fingerprint
               here, unlike gnu.org/sed and gnu.org/m4
  checked      when the digest was recorded, not at every build

That makes three distinct keyring outcomes measured across six recipes:
reachable (sed, gawk), beyond the break but exportable (this one), and
exportable but expired (make, #116). gnu.org/make's recipe asked which of the
first two its own failure was; this one answers the question for a different
key and shows the technique that settles it.

No keyserver was asked.
EOT
}
