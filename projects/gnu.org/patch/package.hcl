# patch — GNU patch, which applies a diff.
#
# ⛔ WRITTEN FROM PATCH'S OWN FILES at 2.8.1, fifth of the fourteen (#88). The
# base toolchain asks for it by name: "recipes that patch their own sources
# (openssl.org)" (base-toolchain/package.hcl:95-96).
#
# ⛔⛔ AND IT WAS CLASSIFIED "NO ANNOUNCEMENT FINDABLE", WHICH WAS WRONG. #88
# recorded three warrant patterns and put gnu.org/patch in the weakest: nothing
# reachable, do not write it without a decision. That classification came from
# reading the `info-gnu` archives alone — the same method that wrongly concluded
# the same thing for gnu.org/findutils, whose announcement is on its OWN list.
# Asked again on `bug-patch`, the announcement is there, and it carries the
# STRONGEST warrant of the five: a full forty-hex fingerprint and a hex SHA-256,
# in the message that announced the release.
#
# An index fetched and read is a negative result. A list never opened is not.

summary = "GNU patch: apply a diff to an original"

# COPYING is the GPLv3 text; src/patch.c:8 carries "either version 3 of the
# License, or (at your option) any later version". Both files, because only the
# second answers the "-or-later".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/patch/"
  match = "/patch-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^patch-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/patch/patch-{{version.raw}}.tar.xz"
  strip-components = 1

  # Recorded with `zpkb sourcepin --sig auto
  # --key <andreas-gruenbacher-0313653A.asc>
  # --fingerprint "259B 3792 B3D6 D319 212C C4DC D5BF 9FEB 0313 653A"`:
  # 940 364 bytes, signed by Andreas Gruenbacher <agruen@gnu.org>, 1 key read
  # from the file.
  #
  # ⭐ THE WARRANT IS THE STRONGEST OF THE FIVE, and on three hosts that do not
  # derive from each other:
  #
  #   fingerprint   lists.gnu.org  — the announcement prints all forty digits,
  #                 "Key fingerprint = 259B 3792 B3D6 D319 212C  C4DC D5BF 9FEB
  #                 0313 653A", beside the `gpg --recv-keys D5BF9FEB0313653A`
  #                 whose sixteen digits are its tail
  #   key material  keyserver.ubuntu.com, fetched BY FINGERPRINT
  #   tarball       ftp.gnu.org
  #
  # gnu-keyring.gpg was not used and was not needed. Every earlier GNU recipe
  # here notes that it comes from the same host as the tarball, which is
  # continuity rather than independence; this one does not inherit that limit.
  sha256 = {
    "2.8.1" = "3240c7959c5347c8ed347e3c4201c0337bf4240d5cf09d68889e58eeaba30e17"
  }

  # ⭐ AND THE DIGEST HAS AN INDEPENDENT WITNESS, in hex, as gnu.org/findutils'
  # does — where gnu.org/tar published base64 unpadded and gnu.org/diffutils
  # base64 padded. The announcement lists all three archive formats; this is the
  # .tar.xz line, character for character what our own fetch-and-hash produced.
  #
  # No `sha` field: that one means "where the expected SHA-256 is published" and
  # the build fetches it, so a signature URL there fails every build (#89). The
  # signature is in `provenance` below (go-zpkg/zpkb#282).
}

build {
  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
      # ⛔ NO `--disable-nls`, AND ITS ABSENCE IS THE MEASUREMENT. Every other
      # GNU recipe in this tree passes it, because every other one bundles
      # `AM_GNU_GETTEXT([external])`. patch 2.8.1 has NO NLS AT ALL:
      # `grep -c -i nls configure` returns 0, there is no `po/` directory, and
      # the single gettext mention is gnulib's `gettext-h` module at
      # configure:8186 — the header shim that makes `gettext()` a no-op. Passing
      # the flag anyway would hand configure an option it does not have, which
      # is exactly the kind of thing a recipe copied from its siblings carries.
      #
      # ⛔ AND `--enable-merge` IS NOT PASSED EITHER, because the default is
      # already on and stating it would be stating a guess. configure.ac:26-29
      # declares the option with NO default action and then tests
      # `test "$enableval" != no` — with the option unset, `$enableval` is
      # empty, the test is true, and merge is enabled. It is the first
      # AC_ARG_ENABLE in the file, so no earlier option can leave a value in
      # that variable. Deterministic, and left alone.
    ]

    # ⛔⛔ THE THIRD `AC_PATH_PROG` IN FIVE RECIPES, AND THE THIRD DIFFERENT
    # CORRECT ANSWER. configure.ac:116-117 is
    #
    #   AC_PATH_PROG([ED], [ed], [ed])
    #   AC_DEFINE_UNQUOTED([EDITOR_PROGRAM], ["$ED"], [Name of editor program.])
    #
    # so without this line `patch` would compile in
    # `$ZPKG_DIR/gnu.org/ed/v<ver>/bin/ed` — another package's VERSIONED store
    # path, as data, stale the day gnu.org/ed is rebuilt (go-zpkg/zpkb#397).
    #
    # ⭐ WHAT THE REMEDY IS DEPENDS ON THE CONSUMER, WHICH IS WHY THIS IS READ
    # EVERY TIME RATHER THAN RULED ONCE. Three recipes, one macro, three
    # answers:
    #
    #   gnu.org/diffutils  src/util.c:849 runs `execv` — NO path search, so a
    #                      bare name cannot exec and the cache var must be
    #                      EMPTY, with the feature refused (#92)
    #   gnu.org/findutils  `$sort` in a shell pipeline — PATH search, so the
    #                      bare NAME is right (#93)
    #   gnu.org/patch      src/pch.c:2385-2390 builds `EDITOR_PROGRAM " -s "`
    #                      into a string and hands it to `systemic()`, which
    #                      runs it THROUGH A SHELL — PATH search again, so the
    #                      bare name is right here too
    #
    # And `ed` is the macro's own third argument, so this is the value upstream
    # already ships when ed is absent at configure time.
    ac_cv_path_ED = "ed"
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:20 — `bin_PROGRAMS = patch`. One binary, and no scripts.
provides = [
  "bin/patch",
]

test {
  script = [
    "patch --version | grep {{version.raw}}",

    # What the base toolchain asks for: a recipe applying a unified diff to its
    # own source before building.
    "mkdir -p t && printf 'one\\ntwo\\nthree\\n' > t/f.txt",
    "printf '%s\\n' '--- f.txt' '+++ f.txt' '@@ -1,3 +1,3 @@' ' one' '-two' '+TWO' ' three' > t/f.diff",
    "patch -d t -p0 f.txt < t/f.diff",
    "grep -q '^TWO$' t/f.txt",

    # ⛔⛔ THE ASSERTION FOR THE BAKED PATH. `EDITOR_PROGRAM " -s "` is one
    # compiled string, so the binary carries `ed -s ` when the name is bare and
    # `/…/bin/ed -s ` when a store path was baked in. The negative is the one
    # that matters: it is the only observable difference between an artifact built
    # here and one built on a host that happened to have `ed`.
    "grep -q 'ed -s' {{prefix}}/bin/patch",
    "! grep -q '/bin/ed -s' {{prefix}}/bin/patch",

    # ⛔⛔ AND THE ASSERTION FOR CVE-2026-115207, WHICH IS WHY 2.8.1 AND NOT 2.8.
    # NEWS: "Prevent creation of out-of-tree files (CVE-2026-115207)". A patch
    # whose target escapes the directory it is applied in must not create that
    # file. Asserted on the PROPERTY — the file is absent — rather than on the
    # exit status or the message, because those are the parts upstream is free
    # to reword and the property is the fix.
    "mkdir -p t/sub",
    "printf '%s\\n' '--- /dev/null' '+++ ../escaped.txt' '@@ -0,0 +1 @@' '+out-of-tree' > t/escape.diff",
    "patch -d t/sub -p0 < t/escape.diff > t/escape.out 2>&1 || true",
    "! test -e t/escaped.txt",
  ]
}

provenance {
  read = [
    "configure.ac",  # :18 AC_INIT; :26-29 --enable-merge, on by default; :116-117 AC_PATH_PROG(ED) → EDITOR_PROGRAM
    "configure",     # 45 ac_cv_path_* probes, of which only ED reaches a define; :8186 gnulib gettext-h, the only gettext here
    "src/Makefile.am", # :20 bin_PROGRAMS = patch
    "src/pch.c",     # :2385-2393 EDITOR_PROGRAM built into a string and run by systemic(), i.e. through a shell
    "src/patch.c",   # :8 "either version 3 of the License, or (at your option) any later"
    "NEWS",          # 2.8.1: "Prevent creation of out-of-tree files (CVE-2026-115207)"
    "COPYING",       # the GPLv3 text that ships
  ]

  consulted = [
    "https://lists.gnu.org/archive/html/bug-patch/2026-10/msg00014.html",
    "go-zpkg/base-toolchain/package.hcl", # :95-96, which asks for patch by name
  ]

  note = <<EOT
Fifth of the fourteen base-toolchain members that had no recipe of ours (#88),
and the one that was written only because its classification was re-tested.

⛔⛔ "NO ANNOUNCEMENT FINDABLE" WAS A STATEMENT ABOUT WHERE I LOOKED. #88 put
this project in the weakest of three warrant patterns and said it must not be
written without a decision. That verdict came from reading the `info-gnu`
archives alone. gnu.org/findutils (#93) showed the method was wrong — its
announcement is on `bug-findutils` — and asking patch's own list found
"GNU patch 2.8.1 released", 2026-10-23, with the full fingerprint in it.

So the fourth pattern #93 added to this issue is not a curiosity: it moved a
project from "do not write this" to the strongest warrant in the set.

⛔ THE VERSION IS A SECURITY FIX, AND THE TEST ASSERTS THE FIX RATHER THAN THE
NUMBER. 2.8.1's only change is "Prevent creation of out-of-tree files
(CVE-2026-115207)". A recipe that pinned 2.8 would build, pass `--version`, and
apply every diff in this tree correctly while carrying the defect; the test
applies a diff whose target escapes the directory and requires that the file not
appear. ⛔ gnu.org/ed is NOT declared: `patch -e` and ed-format patches run
`ed -s` through a shell, nothing in a build does, and a declared dependency is
staged into every consumer's closure — the same treatment gnu.org/diffutils
gives `sdiff -o` and gnu.org/tar gives its seven undeclared compressors. Named
here so "ed: not found" on an ed-format patch reads as a known choice.

The digest is signature-verified:

  signature    https://ftp.gnu.org/gnu/patch/patch-2.8.1.tar.xz.sig
  key          fetched BY FINGERPRINT from keyserver.ubuntu.com
  identity     Andreas Gruenbacher <agruen@gnu.org>
  fingerprint  259B3792B3D6D319212CC4DCD5BF9FEB0313653A, printed in full by the
               release announcement
  checked      when the digest was recorded, not at every build
EOT
}
