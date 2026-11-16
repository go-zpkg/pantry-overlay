# gnu.org/libtool — the portable library-building script, a base-toolchain
# member, and the project whose baked tool paths were already measured to be
# "the single biggest blocker on the autotools front".
#
# ⛔ WRITTEN FROM LIBTOOL'S OWN FILES (go-zpkg/packages#431), at 2.6.2, read out
# of the release tarball. Sixth of today's six: #126, #127, #128, #129 and #130
# took go-zpkg/pantry-overlay#88's measured gap from 9 to 4; this takes it to 3.
#
# ⭐⭐ AND IT STARTS FROM INVISIBLE PRIOR WORK, which `priorart` surfaced and
# nothing else would have. go-zpkg/zpkb carries a PUSHED BRANCH WITH NO PULL
# REQUEST, `fix/libtool-baked-tool-paths` at 1eac04a, "buildscript: stop libtool
# using a sed that exists on nobody's machine". Its commit message is the
# measurement this recipe is built on:
#
#     libtoolize opens with
#         : ${SED="/__w/_actions/pkgxdev/brewkit/v1/libexec/sed"}
#     the sed of the machine that built libtool … baked into the bottle and
#     present nowhere else. Every sed call in libtoolize then fails.
#
#     It does not fail loudly. libtoolize exits 0 and prints its version with
#     the program name stripped, because the name comes through that sed …
#     so autogen.sh's probe reads it as absent and reports
#         You must have libtoolize version >= 2.x.x, but you have none.
#     naming neither libtool nor a path. Three of ten recipes in one batch died
#     there; it is the single biggest blocker on the autotools front.
#
# That branch fixes it from the CONSUMER side, by exporting SED/GREP/EGREP/FGREP
# into the build environment so `: ${VAR=...}` (assign-only-if-unset) is
# pre-empted. ⭐ THIS RECIPE REMOVES THE CAUSE INSTEAD, for the libtool WE
# build: the baked default becomes a bare name, so there is nothing to
# pre-empt. The branch's workaround stays necessary for upstream bottles, which
# we do not build and cannot fix.

summary = "GNU Libtool: the libtool script, libtoolize and libltdl"

# ⛔ READ FROM BOTH: COPYING is the GPL version 2 text, and libtoolize.in:10-13
# is "either version 2 of the License, or (at your option) any later version".
#
# ⚠ NOT NARROWED FURTHER, per the discipline go-zpkg/pantry-overlay#127 set.
# libtool is also known for a linking exception on the scripts it GENERATES, and
# libltdl is usually LGPL — but neither file was opened for this recipe, and a
# licence is not narrowed on files that were not read.
license = "GPL-2.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/libtool/"
  match = "/libtool-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^libtool-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/libtool/libtool-{{version.raw}}.tar.xz"
  strip-components = 1

  # 1093564 bytes. Two independent hash paths, one answer: the builder's own
  # fetcher reported this digest, and an independent `curl --fail` +
  # `shasum -a 256` gave the same string.
  #
  # ⚠⚠ THE SIGNATURE IS A WEAKER WARRANT THAN ANY OTHER RECIPE WRITTEN TODAY,
  # and the whole measurement is in `provenance.note`. In one sentence: the
  # signature really is by Ileana Dumitrescu's key, and that key's MOST RECENT
  # self-signature had expired four months before this release was signed. This
  # digest therefore rests on the two hash paths; the signature says who, not
  # that the key was live.
  sha256 = {
    "2.6.2" = "2ef1067c16c97db930fd740cc9bc3d3ba9a583804ae5ac42cc3e8719e49e191e"
  }
}

# ⛔⛔ sed AND grep ARE RUNTIME DEPENDENCIES, and the branch quoted above is the
# proof of what happens without them: `bin/libtool` and `bin/libtoolize` are
# shell scripts that call `$SED` and `$GREP` on every invocation, and a broken
# one fails SILENTLY — exit 0, version banner with the program name stripped,
# and a consumer's probe reporting "you have none".
dependencies = {
  "gnu.org/sed"  = "*"
  "gnu.org/grep" = "*"
}

build {
  dependencies = {
    "gnu.org/make" = "*"

    # The same two at build time: configure's AC_PROG_SED / AC_PROG_GREP run
    # them, and so does the build itself (Makefile.am:195 pipes through
    # `$(SED)`).
    "gnu.org/sed"  = "*"
    "gnu.org/grep" = "*"
  }

  # ⛔ THE SWITCH CENSUS: exactly ONE AC_ARG_ENABLE of libtool's own
  # (configure.ac:121, `--disable-ltdl-install`) and ZERO AC_ARG_WITH. Everything
  # else comes from `LT_INIT([dlopen win32-dll])` at :149, i.e. libtool's own
  # standard set (--enable-shared/--enable-static/--with-pic), whose defaults are
  # fixed constants in libtool's macros.
  #
  # ⛔⛔ AND `--disable-ltdl-install` IS INERT IN 2.6.2 — MEASURED, WHICH IS WHY
  # IT IS NOT PASSED. `enable_ltdl_install` appears in exactly two places:
  #
  #     configure.ac:123  if test set != "${enable_ltdl_install+set}"; then
  #     configure.ac:124    enable_ltdl_install=yes
  #
  # its own default assignment, and NOWHERE in Makefile.am. libltdl is built
  # unconditionally through `include libltdl/ltdl.mk` (Makefile.am:324). So the
  # switch is accepted by configure and acted on by nothing: passing it would be
  # a recipe flag the project does not honour, which is go-zpkg/zpkb#486's whole
  # subject. Named rather than passed.
  #
  # ⚠ CONSEQUENCE, STATED BECAUSE IT IS A KNOWN RISK THIS RECIPE CANNOT RETIRE:
  # `lib/libltdl.la` is therefore installed, and a `.la` file carries absolute
  # `libdir=`/`dependency_libs=` values. This repository's README records
  # `zpkb bakedpaths` REFUSING the upstream `gnu.org/libtool` v2.5.4 bottle on
  # exactly that file. Whether our own build produces a refusable one cannot be
  # settled without running the factory, so it is written down as the first
  # thing to look at on the first real build rather than left to be rediscovered.
  env = {
    ARGS = [
      "--prefix={{prefix}}",
    ]

    # ⛔⛔ THE FOUR CACHE PRE-ANSWERS THAT REMOVE THE BAKED PATHS. libtoolize.in
    # opens with
    #
    #     :43  : ${EGREP="@EGREP@"}
    #     :44  : ${FGREP="@FGREP@"}
    #     :45  : ${GREP="@GREP@"}
    #     :47  : ${SED="@SED@"}
    #
    # and those four substitutions come from autoconf's AC_PROG_SED /
    # AC_PROG_GREP / AC_PROG_EGREP / AC_PROG_FGREP, every one of which records an
    # ABSOLUTE path in its `ac_cv_path_*` cache variable. In this factory that is
    # another project's versioned store path — go-zpkg/zpkb#397's class — and in
    # the upstream bottle it was a path inside pkgxdev's CI workspace.
    #
    # Pre-answering the cache is the same lever go-zpkg/pantry-overlay#128 and
    # #129 use for `ac_cv_path_M4`, and gnu.org/gzip before them for
    # `ac_cv_prog_LESS`. The values are the shapes configure itself would
    # produce, minus the directory: measured at configure:6852,
    # `ac_cv_path_EGREP="$GREP -E"` when grep supports -E, which is why these two
    # are `grep -E` and `grep -F` rather than `egrep`/`fgrep`.
    #
    # ⚠ COST, STATED: this also skips the screening those macros do (is it GNU,
    # does it survive long input). The `gnu.org/sed` and `gnu.org/grep`
    # dependencies above stand in its place — both are GNU by construction, being
    # the base toolchain's own.
    ac_cv_path_SED   = "sed"
    ac_cv_path_GREP  = "grep"
    ac_cv_path_EGREP = "grep -E"
    ac_cv_path_FGREP = "grep -F"
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Read from Makefile.am: `bin_SCRIPTS = libtool` (:284) and
# `bin_SCRIPTS += libtool-next-version` (:286, unconditional), plus `libtoolize`
# which is installed by its own rule at :534-539 rather than through bin_SCRIPTS
# — a third mechanism, which is why this list is read from the file instead of
# from `bin_SCRIPTS` alone.
provides = [
  "bin/libtool",
  "bin/libtool-next-version",
  "bin/libtoolize",
]

test {
  script = [
    # ⛔⛔ `--version` IS NOT A SUFFICIENT TEST HERE, AND THAT IS THE WHOLE POINT
    # OF THE BRANCH QUOTED AT THE TOP: with a broken $SED, libtoolize exits 0 and
    # still prints a version banner — just with the program name stripped. So the
    # banner is checked for its CONTENT, not its exit status.
    {
      run = <<EOT
out=$("{{prefix}}/bin/libtoolize" --version 2>&1) || exit 1
printf '%s\n' "$out"
# The program name comes through $SED. If sed is unusable it is stripped, which
# is exactly how this failure hid: exit 0, plausible output, no name.
printf '%s\n' "$out" | grep -q 'libtoolize' || {
  echo "libtool: libtoolize --version printed no program name" >&2
  echo "  that is the \$SED failure signature from go-zpkg/zpkb's" >&2
  echo "  fix/libtool-baked-tool-paths branch: exit 0, name stripped." >&2
  exit 1
}
EOT
    },

    "\"{{prefix}}/bin/libtool\" --version",

    # ⛔ THE REGRESSION WITNESS for the four pre-answers, asserted as an ABSENCE
    # because that is the direction the defect travels. If a future edit drops
    # them, configure resumes the PATH search and writes absolute paths into both
    # scripts' preambles. Matched on `/bin/sed` and `/bin/grep` so it catches the
    # host spelling as well as a store path.
    {
      run = <<EOT
for f in bin/libtool bin/libtoolize; do
  if grep -q -e '/bin/sed' -e '/bin/grep' "{{prefix}}/$f"; then
    echo "libtool: an ABSOLUTE sed or grep path is baked into $f" >&2
    echo "  libtoolize.in:43-47 substitutes @SED@/@GREP@/@EGREP@/@FGREP@," >&2
    echo "  and AC_PROG_SED/GREP record absolute paths." >&2
    echo "  Restore the four ac_cv_path_* answers in build.env." >&2
    exit 1
  fi
done
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",   # :121-125 the INERT --disable-ltdl-install; :149 LT_INIT; the whole switch census
    "libtoolize.in",  # :10-13 GPL-2.0-or-later; :41-42 AUTOCONF/AUTOMAKE as BARE NAMES; :43-47 the four baked tool paths; :144-145,:167-168,:418-422 the $SED uses
    "Makefile.am",    # :195 the build's own $(SED); :284-286 bin_SCRIPTS; :324 libltdl built unconditionally; :534-539 the libtoolize install rule
    "configure",      # :6849-6875 how ac_cv_path_EGREP is computed — the source of the `grep -E` shape
    "COPYING",        # the GPL version 2 text that ships
  ]

  consulted = [
    # Read for the key, and it did not help: Arch's libtool PKGBUILD has
    # pkgver=2.6.2 but NO validpgpkeys and a pkgver() function, i.e. it builds
    # from git. No third-party fingerprint for this tarball was found.
    "archlinux/packaging/packages/libtool PKGBUILD",
    # ⭐ AND THE ONE THAT MATTERED: a pushed branch with no pull request.
    "go-zpkg/zpkb branch fix/libtool-baked-tool-paths @1eac04a (commit message only)",
  ]

  note = <<EOT
⚠⚠ THE SIGNATURE IS THE WEAKEST WARRANT OF TODAY'S SIX RECIPES, and the reason
is a condition in the KEY rather than anything about the archive. Written out in
full because the obvious reading of it is wrong in two different directions.

The signature on libtool-2.6.2.tar.xz is RSA/SHA-512, created 2026-07-16, by
primary key

    FA26CA784BE188927F22B99F6570EA01146F7354
    Ileana Dumitrescu <ileanadumitrescu95@gmail.com>

That key is held by TWO independent hosts, and they disagree:

  ftp.gnu.org/gnu/gnu-keyring.gpg   self-sig 2023-03-08, key expiry 2026-03-07
                                    -> sourcepin REFUSES: "openpgp: key expired"
  protonmail.com WKD, for the       self-sig 2021-09-23, NO expiry
  ileanadumi95@protonmail.com UID   -> sourcepin VERIFIES

⛔⛔ AND THE POLARITY IS THE OPPOSITE OF go-zpkg/pantry-overlay#127'S, which is
why "prefer the author's own copy" is NOT the rule it looked like there. For
glibc, akhuettel.de served a self-signature dated the day before and the GNU
keyring served a stale one; taking the author's copy was taking the NEWER
statement. Here the GNU keyring's copy is the NEWER one — it carries a 2023
self-signature that ADDED a three-year expiry — and the WKD copy is the OLDER
one, from 2021, predating that change.

OpenPGP's rule is that the most recent self-signature governs. So the honest
reading is: this release was signed four months AFTER the key's current
self-signature had lapsed. The verification against the WKD copy succeeds only
because that copy is missing an update the author later made — choosing the
copy that says yes, which is not a warrant.

⚠ WHAT IS THEREFORE CLAIMED, precisely: the bytes were signed by Ileana
Dumitrescu's key (two independent hosts agree on that fingerprint, and the
cryptography checks out), and NOT that the key was valid at signing time. The
digest rests on the two independent hash paths — the builder's own fetcher and
`curl --fail` + `shasum -a 256` — exactly as kernel.org/linux-headers
(go-zpkg/pantry-overlay#126) rests on its two, there because our verifier cannot
read the chain and here because the chain itself has a hole.

⚠ No third-party fingerprint was available to break the tie: Arch's libtool
PKGBUILD carries no `validpgpkeys` at all and builds from git, so unlike
go-zpkg/pantry-overlay#128 and #129 there is no independent publisher pinning
this artifact.

⭐ ONE CLEAN RESULT WORTH RECORDING BESIDE THE MESSY ONE: libtool gets the
autoconf/automake case RIGHT where it gets sed/grep wrong, in the same file —

    libtoolize.in:41  : $${AUTOCONF="autoconf"}
    libtoolize.in:42  : $${AUTOMAKE="automake"}
    libtoolize.in:43  : $${EGREP="@EGREP@"}
    libtoolize.in:47  : $${SED="@SED@"}

bare names for the first two, substituted absolute paths for the rest. That is
the same distinction go-zpkg/pantry-overlay#130 found in automake's
`$${AUTOCONF-autoconf}`, four lines apart from its own counter-example. And
there is no `@M4@` here at all — libtool does not invoke m4 at run time, so the
third instance of #128's defect is not in this package.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS — the one real switch and the one inert switch, both
runtime dependencies, all three installed names from three different install
mechanisms, and the destination of all six substituted tool paths, each traced
to a line cited in `read`. Two things are explicitly left open for the first
real build: whether `lib/libltdl.la` carries a path `bakedpaths` refuses, and
the signature condition above.
EOT
}
