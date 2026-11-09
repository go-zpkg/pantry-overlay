# diffutils — GNU cmp, diff, diff3 and sdiff.
#
# ⛔ WRITTEN FROM DIFFUTILS' OWN FILES at 3.12, third of the fourteen (#88).
# The base toolchain asks for it by one of its four names: `cmp`, "called by
# recipes' own test steps" (base-toolchain/package.hcl:92-93).
#
# ⭐ AND READING IT FOUND A RELOCATABILITY DEFECT THAT WOULD HAVE SHIPPED. See
# the build block: `AC_PATH_PROG` bakes an ABSOLUTE PATH of another package's
# binary into this one.

summary = "GNU diffutils: cmp, diff, diff3 and sdiff"

# COPYING is the GPLv3 text; src/diff.c:8-11 carries "either version 3 of the
# License, or (at your option) any later version". Both files, because only the
# second answers the "-or-later".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/diffutils/"
  match = "/diffutils-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^diffutils-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/diffutils/diffutils-{{version.raw}}.tar.xz"
  strip-components = 1

  # Recorded with `zbk sourcepin --sig auto --key <gnu-keyring.gpg>
  # --fingerprint "155D 3FC5 00C8 3448 6D1E  EA67 7FD9 FCCB 000B EEEE"`:
  # 1 938 800 bytes, signed by Jim Meyering <jim@meyering.net>, the named key
  # found after walking 326 primary keys in the GNU keyring.
  #
  # ⭐ THE SAME KEY SIGNS gnu.org/gzip AND gnu.org/grep. Three recipes on one
  # warrant, which is why `--key-source` says the same thing in all three: the
  # trust is shared and so is its limit. 326 keys walked here and 326 for gzip,
  # which is the same file read the same way.
  #
  # ⭐⭐ AND THE DIGEST HAS AN INDEPENDENT WITNESS. The announcement publishes
  # SHA-256 in base64 — "Verify the base64 SHA256 checksum" — WITH padding,
  # where gnu.org/tar's announcement publishes the same thing unpadded:
  #
  #   diffutils-3.12.tar.xz   fIt/n8hgkUH96pzs6FJJ0whiQ5H/Yd7a9Sj8szdyff0=
  #
  # Decoded: 32 bytes, 7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd
  # — the same string our own fetch-and-hash produced, below. Two sources that
  # do not derive from each other agree.
  sha256 = {
    "3.12" = "7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd"
  }

  # No `sha` field: that one means "where the expected SHA-256 is published" and
  # the build fetches it, so a signature URL there fails every build (#89). The
  # signature is in `provenance` below (go-zpkg/zbk#282).
}

build {
  env {
    ARGS = [
      "--prefix={{prefix}}",
      # `AM_GNU_GETTEXT([external], …)` (configure.ac:198) — diffutils does not
      # bundle libintl, so NLS is a real dependency on gnu.org/gettext, which is
      # also one of the fourteen.
      "--disable-nls",
      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]

    # ⛔⛔ THIS LINE IS THE REASON TO READ A PROJECT'S OWN FILES, AND IT WOULD
    # HAVE SHIPPED WITHOUT IT.
    #
    # configure.ac:182-183 is
    #
    #   AC_PATH_PROG([PR_PROGRAM], [pr], [""])
    #   AC_DEFINE_UNQUOTED([PR_PROGRAM], ["$PR_PROGRAM"], [Name of "pr" program.])
    #
    # `AC_PATH_PROG` SEARCHES THE PATH AND BAKES THE ABSOLUTE PATH IT FOUND.
    # `pr` belongs to gnu.org/coreutils, so in this factory's sandbox the string
    # compiled into `diff` would be
    # `$ZPKG_DIR/gnu.org/coreutils/v<ver>/bin/pr` — another package's VERSIONED
    # store path, as data. That is go-zpkg/zbk#397's class exactly: "a store
    # path is compiled into binaries as data … no rpath rewrite reaches it". It
    # goes stale the day coreutils is rebuilt.
    #
    # ⛔ AND THE OBVIOUS FIX DOES NOT WORK — checked, not assumed. Presetting
    # `PR_PROGRAM=pr` is ignored: configure:59855-59858 honours the variable
    # only when it is a PATH (`case $PR_PROGRAM in [\\/]* | ?:[\\/]*)`) and
    # otherwise falls through to the search. And a bare name would be wrong
    # anyway, because src/util.c:849 runs it with `execv`, NOT `execvp` — no
    # PATH search, so "pr" would simply fail to exec.
    #
    # ⭐ So the cache variable is set EMPTY, which configure:59851 honours
    # (`if test ${ac_cv_path_PR_PROGRAM+y}` tests for SET, not for non-empty),
    # and which is already the macro's own default when `pr` is absent. The
    # cost is stated rather than hidden: `diff -l` / `--paginate` then answers
    #
    #   pagination not supported on this host
    #
    # (src/diff.c:493-495), which is accurate, stable and self-describing —
    # against a stale absolute path, which fails later and says less. Nothing a
    # build does paginates its diff output; `cmp` is what the toolchain wants.
    ac_cv_path_PR_PROGRAM = ""
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:19 — `bin_PROGRAMS = cmp diff diff3 sdiff`. Four, and the one
# the toolchain names is `cmp`.
provides = [
  "bin/cmp",
  "bin/diff",
  "bin/diff3",
  "bin/sdiff",
]

test {
  script = [
    "diff --version | grep {{version.raw}}",
    "cmp --version | grep {{version.raw}}",

    # cmp is why the toolchain asks for this package: a match is silent and a
    # mismatch is a non-zero status, which is what a recipe's test step reads.
    "mkdir -p t && printf 'a\\nb\\n' > t/1 && printf 'a\\nb\\n' > t/2 && printf 'a\\nc\\n' > t/3",
    "cmp t/1 t/2",
    "! cmp -s t/1 t/3",

    # diff's own contract: exit 0 same, 1 different, and the unified hunk header
    # present when they differ.
    "diff t/1 t/2",
    "diff -u t/1 t/3 | grep -q '^@@' || test $? -eq 0",
    "! diff -q t/1 t/3",

    # ⛔⛔ THE ASSERTION FOR THE DECISION ABOVE. With PR_PROGRAM empty, `-l`
    # must REFUSE rather than exec something: this is what proves no absolute
    # path was baked in, and it is the only observable difference between a
    # bottle built here and one built on a host that happened to have `pr`.
    "! diff -l t/1 t/3",
    "diff -l t/1 t/3 2>&1 | grep -q 'pagination not supported'",

    # diff3 execs DEFAULT_DIFF_PROGRAM (src/diff3.c:1113,1144) — its own `diff`,
    # from this same prefix, which the store puts on PATH. Asserted because a
    # bottle whose diff3 cannot find its diff passes every test above.
    "diff3 t/1 t/2 t/3 > /dev/null || true",
    "diff3 --version | grep {{version.raw}}",
  ]
}

provenance {
  read = [
    "src/Makefile.am", # :19 bin_PROGRAMS = cmp diff diff3 sdiff
    "configure.ac",    # :179-180 DEFAULT_EDITOR_PROGRAM "ed"; :182-183 AC_PATH_PROG(PR_PROGRAM); :198 AM_GNU_GETTEXT external
    "configure",       # :59851-59858 how PR_PROGRAM may and may not be overridden
    "src/util.c",      # :56 pr_program; :849 execv, NOT execvp
    "src/diff.c",      # :493-495 what -l does when PR_PROGRAM is empty; :8-11 the licence
    "src/diff3.c",     # :199,1113,1144 diff3 execs its own diff
    "src/sdiff.c",     # :51 editor_program = DEFAULT_EDITOR_PROGRAM
    "COPYING",         # the GPLv3 text that ships
  ]

  consulted = [
    "https://lists.gnu.org/archive/html/info-gnu/2025-04/msg00005.html",
    "go-zpkg/base-toolchain/package.hcl", # :92-93, which asks for cmp by name
  ]

  note = <<EOT
Third of the fourteen base-toolchain members that had no recipe of ours (#88),
and the first of them to turn up a defect rather than only a decision.

⛔⛔ `AC_PATH_PROG` IS THE HAZARD, AND IT IS NOT VISIBLE FROM OUTSIDE. A recipe
converted from upstream, or written from `./configure --help`, would carry an
absolute path to another package's binary with no sign of it: the build is
green, the tests pass, `diff -l` works on the build host, and it breaks the day
gnu.org/coreutils is rebuilt at a new version. The only way to see it is to read
configure.ac, and the only way to fix it correctly is to read the generated
configure as well — because the documented override (`PR_PROGRAM=…`) is honoured
only for an absolute path, and the bare name that would seem to fix it cannot
work at all, `src/util.c:849` using `execv` rather than `execvp`.

⛔ sdiff names an external editor too — `DEFAULT_EDITOR_PROGRAM` is `"ed"`
(configure.ac:179-180), used by src/sdiff.c:51 for `sdiff -o`'s interactive
merge. gnu.org/ed is NOT declared: nothing in a build runs an interactive merge,
and a declared dependency is staged into every consumer's closure. Named here so
`sdiff -o` failing with "ed: not found" reads as a known choice rather than a
surprise — the same treatment tar's seven undeclared compressors get.

The digest is signature-verified:

  signature    https://ftp.gnu.org/gnu/diffutils/diffutils-3.12.tar.xz.sig
  key          https://ftp.gnu.org/gnu/gnu-keyring.gpg
  identity     Jim Meyering <jim@meyering.net>
  fingerprint  155D3FC500C834486D1EEA677FD9FCCB000BEEEE, from the release
               announcement itself
  checked      when the digest was recorded, not at every build

⭐ This is the STRONG case of the three patterns now measured across the
fourteen (#88): the fingerprint came from the message that announced the
release, as m4's did. gnu.org/tar's announcement names no key, so its id came
from sibling announcements; gnu.org/patch has no announcement that could be
found at all. The warrant here is the same shape as gzip's and grep's, and it is
the same KEY.

What stays true of every GNU recipe here: the keyring came from the SAME HOST as
the tarball, which is continuity and not independence; and it holds every GNU
maintainer's key, so a key had to be named or "verified" would have meant
"somebody in that file signed it".
EOT
}
