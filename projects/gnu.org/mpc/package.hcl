# gnu.org/mpc — GNU MPC, complex floating-point with exact rounding, third of
# the four projects `gnu.org/gcc/libstdcxx` needs.
#
# ⛔ WRITTEN FROM MPC'S OWN FILES (go-zpkg/packages#431), at 1.4.1.
#
# ⚠ THIS ONE MOVES NEITHER NUMBER, AND THAT IS MEASURED, not assumed. The
# mistake go-zpkg/pantry-overlay#134 made for gmp was to check the members tally,
# find it unchanged, and write "no number" about both. The walk prints two
# things, so both were read:
#
#   closure: 1 project(s) asked for and not read   — unchanged (libstdcxx)
#   closure: skip <name>                           — `gnu.org/mpc` occurs ZERO times
#
# gmp and mpfr were both already on that skip list, reached through
# `gnu.org/gawk`. mpc is not: nothing in the set declares it yet, and libstdcxx
# being unread means its dependencies are never walked. So unlike its two
# siblings this recipe closes no live gap — it is a prerequisite being put in
# place before `gnu.org/gcc`, which is the member that will ask for it.

summary = "GNU MPC: arithmetic on complex numbers with arbitrarily high precision and correct rounding"

# ⛔⛔ AN **AND**, AND IT IS THE THIRD DISTINCT LICENCE SHAPE IN THREE SIBLING
# LIBRARIES — worth stating because the three look interchangeable from outside:
#
#   gnu.org/gmp  (#134)  LGPL-3.0-or-later OR GPL-2.0-or-later   recipient CHOOSES
#   gnu.org/mpfr (#135)  LGPL-3.0-or-later                       one licence
#   gnu.org/mpc  (here)  LGPL-3.0-or-later AND GFDL-1.3-or-later two, simultaneously
#
# The library is LGPLv3+ (src/mpc.h.in:8-17, COPYING.LESSER). The MANUAL is not:
# doc/mpc.texi:19-22 places it "under the terms of the GNU Free Documentation
# License, Version 1.3 or any later version", and doc/fdl-1.3.texi ships that
# text. It is an AND rather than a footnote because the manual is INSTALLED —
# doc/Makefile.am's `info_TEXINFOS = mpc.texi` puts share/info/mpc.info in the
# artifact — so a redistributor of this package carries both obligations at once,
# the same reason gnu.org/glibc (#127) is an AND.
license = "LGPL-3.0-or-later AND GFDL-1.3-or-later"

versions {
  # ⚠ THIS LISTS 1.4.0 AND LATER ONLY, deliberately: mpc changed archive format
  # AT 1.4.0, and 1.3.1 and earlier exist as `.tar.gz` with no `.tar.xz` beside
  # them. Matching both extensions would make `distributable.url` below a lie for
  # every version before 1.4.0, since that template can name only one suffix. A
  # narrower list whose URL is true for every entry beats a complete list whose
  # URL is wrong for most of it.
  #
  # ⚠ Cost, stated: `versions` will not offer 1.3.1 or earlier. If one is ever
  # needed, the fix is a second recipe or an extension-aware template, not a
  # widened match here.
  url   = "https://ftp.gnu.org/gnu/mpc/"
  match = "/mpc-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^mpc-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/mpc/mpc-{{version.raw}}.tar.xz"
  strip-components = 1

  # ⭐ THREE INDEPENDENT DIGEST PATHS, ALL AGREEING — the strongest digest
  # position of this four-package chain, and better than either sibling:
  #
  #   1. the builder's own fetcher (`zpkb sourcepin`)      531992 bytes
  #   2. an independent `curl --fail` + `shasum -a 256`    531992 bytes
  #   3. Arch's mpc PKGBUILD `sha256sums`, over the SAME ftp.gnu.org tarball
  #
  # Path 3 is what gnu.org/mpfr (#135) could not have — Arch publishes sha512 and
  # b2 sums there, not sha256 — and what gnu.org/gmp (#134) could not have
  # either, Arch pinning a DIFFERENT archive (`.tar.lz` from gmplib.org) whose
  # digest is for different bytes.
  #
  # ⛔ THE SIGNATURE IS IDENTIFIED BUT NOT VERIFIED, and the claim is about the
  # COPY, not about the key — the distinction #134 had to make for gmp:
  #
  #   DSA/SHA-256, created 2026-04-16
  #   issuer primary ad17a21ef8aed8f1cc02dbd9f7d5c9bf765c61e3
  #   Arch's PKGBUILD pins that exact fingerprint as `# Andreas Enge`
  #
  # So the fingerprint is corroborated by a third party over these exact bytes.
  # What is missing is usable key MATERIAL: the only obtainable copy, ftp.gnu.org's
  # keyring, carries a self-signature of 2010-05-14 that expired 2015-05-13 —
  # ELEVEN YEARS before this signature was made — and `sourcepin` correctly
  # refuses it with `openpgp: key expired`. A newer self-signature therefore
  # almost certainly exists; this session could not reach it. Routes exhausted:
  # WKD for andreas.enge@inria.fr returns 404, and the project's own site
  # (multiprecision.org/mpc) publishes no key, no fingerprint and no signature
  # reference at all. No keyserver was asked, here or anywhere in this tree: an
  # unknown key pulled from a pool would degrade the check to "somebody signed
  # it".
  sha256 = {
    "1.4.1" = "91204cd32f164bd3b7c992d4a6a8ce6519511aadab30f78b6982d0bf8d73e931"
  }
}

# ⛔ BOTH ARE RUNTIME DEPENDENCIES, not merely build ones: libmpc links libgmp
# and libmpfr (configure.ac:142-157 adds `-lgmp` and `-lmpfr` to LIBS, and
# AC_MSG_ERRORs if either fails to link).
#
# The floors are mpc's own, each asserted twice in its own configure.ac — once as
# a compile-time #error and once as the value substituted into mpc.pc:
#
#   gmp  >= 5.0.0   configure.ac:160 REQUIRES_GMP_VERSION,  :174-176 the #error
#   mpfr >= 4.1.0   configure.ac:186 REQUIRES_MPFR_VERSION, :196-198 the #error
#
# This tree resolves gmp 6.3.0 (#134) and mpfr 4.2.2 (#135), so both are met.
dependencies = {
  "gnu.org/gmp"  = ">=5"
  "gnu.org/mpfr" = ">=4.1"
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    "gnu.org/gmp"  = ">=5"
    "gnu.org/mpfr" = ">=4.1"
  }

  env = {
    # ⛔⛔ THE FINDING OF THIS RECIPE, AND IT IS NOT A SWITCH. Unless CC or CFLAGS
    # is already set in the environment, mpc takes **the compiler and its flags
    # out of gmp's installed header**:
    #
    #   configure.ac:31-32   USER_CC=$CC / USER_CFLAGS=$CFLAGS, captured BEFORE
    #                        AC_PROG_CC so they hold only what came from outside
    #   configure.ac:104-106 `if test -z "$USER_CC" && test -z "$USER_CFLAGS"`
    #                        then MPC_GMP_CC_CFLAGS
    #   m4/mpc.m4            that macro preprocesses `#include "gmp.h"` to read
    #                        `__GMP_CC` and `__GMP_CFLAGS`, and on success does
    #                        `CC=$GMP_CC` and `CFLAGS=$GMP_CFLAGS`
    #
    # Every auto-detection this campaign has found so far decided what the
    # artifact LINKS (curl's brotli, glibc's libgd), how it was CODE-GENERATED
    # (glibc's --enable-cet), what it CONTAINS (texinfo's bin/info) or what it
    # EXPORTS (mpfr's --enable-float128). This one decides **which compiler
    # builds it**, by reading a string another package baked into its own header.
    # The chain makes it concrete: #134 exists because gmp tunes itself to the
    # build machine's CPU, and `__GMP_CFLAGS` is exactly the record of how that
    # gmp was compiled — so whatever a staged gmp happened to be built with would
    # silently become libmpc's own flags, and a foreign gmp could hand mpc a
    # different compiler entirely.
    #
    # ⚠ AND THE SANDBOX DOES NOT ALREADY PREVENT IT — measured, not assumed:
    # `ZBK_CC` and `CC` appear nowhere in zpkb's sources outside its own tests,
    # so nothing exports CC into a build and the macro really would run.
    #
    # Naming CC is enough: USER_CC becomes non-empty, the `&&` at :104 is false,
    # and the extraction never happens. CFLAGS is then AC_PROG_CC's own `-g -O2`,
    # which is deterministic. `cc` rather than `clang` follows the precedent
    # already working in this tree — projects/ruby-lang.org/package.hcl:30 builds
    # with `CC=cc`, and projects/gnu.org/mpfr/package.hcl:173 compiles its test
    # with `cc` — and #127 established that what it resolves to here is clang.
    CC = "cc"

    # ⛔ THE SWITCH CENSUS: EIGHT, and every single default is a fixed constant —
    # unset. There is no `[default=auto]` anywhere in mpc's configure.ac, which
    # makes it the first project in this campaign with a clean switch surface.
    # The two interesting things about mpc are therefore NOT switches: the CC
    # extraction above, and the complex.h detection recorded in `note` below.
    #
    # The eight, with where each is read:
    #   :39 --with-mpfr-include   unset   prepends -I to CPPFLAGS
    #   :43 --with-mpfr-lib       unset   prepends -L to LDFLAGS
    #   :47 --with-mpfr           unset   both; :55 REFUSES the two above beside it
    #   :58 --with-gmp-include    unset   prepends -I to CPPFLAGS
    #   :62 --with-gmp-lib        unset   prepends -L to LDFLAGS
    #   :66 --with-gmp            unset   both; :74 REFUSES the two above beside it
    #   :77 --enable-logging      no      see below
    #   :88 --enable-valgrind-tests no    see below
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ WHERE GMP AND MPFR ARE FOUND, STATED — the same lever #135 used, and
      # needed twice here. configure.ac:47-57 and :66-76 each add
      # `-I$DIR/include` and `-L$DIR/lib`, and each REFUSES to be combined with
      # its own -include/-lib pair. Left unset, mpc searches wherever CPPFLAGS and
      # LDFLAGS happen to point — in a store, whatever the sandbox staged, i.e.
      # the libgmp and libmpfr of the artifact chosen by accident. These name our
      # own, and they are the same two prefixes the test block links against.
      "--with-gmp={{deps.gnu.org/gmp.prefix}}",
      "--with-mpfr={{deps.gnu.org/mpfr.prefix}}",

      # ⛔ NAMED ALTHOUGH `no` IS ALREADY THE DEFAULT, because this switch decides
      # what enters the artifact and the campaign's rule is that such a decision
      # is written down rather than inherited. configure.ac:208-220: with logging
      # on, mpc requires dlfcn.h, links `-ldl`, compiles src/logging.c in, and
      # INSTALLS A SECOND HEADER — `@MPC_LOG_H@` at Makefile.am's
      # `include_HEADERS = src/mpc.h @MPC_LOG_H@` becomes src/mpc-log.h. So the
      # installed file set and the library's dependencies both turn on it.
      #
      # ⚠ Not inert, which is why it is passed at all: configure.ac:80-85 has an
      # explicit `case $enableval` accepting `no`, unlike libtool's
      # --disable-ltdl-install (#131) and gmp's --enable-fat off x86 (#134), which
      # this tree declines to pass precisely because the projects ignore them
      # (go-zpkg/zpkb#486).
      "--disable-logging",

      # ⛔ ALSO NAMED, for the same reason one step further out: `yes` here runs
      # gl_VALGRIND_TESTS (configure.ac:92), which SEARCHES THE BUILD MACHINE for
      # a valgrind binary. A build whose configure log differs by what happened to
      # be installed on the runner is not reproducible even when the artifact is
      # identical — the same reason #134 switched gmp's --with-readline off
      # although readline could not have reached that artifact either.
      "--disable-valgrind-tests",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: mpc installs no programs. The whole installed set, read from
# the two Makefile.am files, is
#
#   lib/libmpc.*          src/Makefile.am:20  lib_LTLIBRARIES = libmpc.la
#   include/mpc.h         Makefile.am:32      include_HEADERS = src/mpc.h
#   lib/pkgconfig/mpc.pc  Makefile.am:29      pkgconfig_DATA = mpc.pc
#   share/info/mpc.info   doc/Makefile.am:20  info_TEXINFOS = mpc.texi
#
# the same library-and-headers shape as zlib.net, gnu.org/gmp and gnu.org/mpfr.
#
# ⭐ AND IT NEEDS NO TEXINFO AT BUILD TIME, checked rather than assumed: the
# tarball ships doc/mpc.info prebuilt, beside doc/stamp-vti and doc/version.texi,
# so automake's info rules have nothing to regenerate and `makeinfo` is never
# invoked. gnu.org/texinfo (#132) is not a build dependency here.

test {
  script = [
    "test -f \"{{prefix}}/include/mpc.h\"",
    "test -f \"{{prefix}}/share/info/mpc.info\"",
    {
      run = <<EOT
ls "{{prefix}}"/lib/libmpc.* >/dev/null
EOT
    },

    # ⛔ THE .pc FILE IS PART OF THE INSTALLED SET, so it is asserted like any
    # other installed file. ⚠ A CHECKED NEGATIVE, recorded because it looked like
    # a defect and is not: mpc.pc.in declares
    # `Requires.private: mpfr >= @REQUIRES_MPFR_VERSION@, gmp >= @REQUIRES_GMP_VERSION@`,
    # which would be unsatisfiable if either project shipped no pkg-config file.
    # Both do — gmp's Makefile.am:121-122 installs gmp.pc and mpfr's :43-44
    # installs mpfr.pc — so the only remaining question is whether their
    # directories are on the search path, which is go-zpkg/zpkb#493's subject and
    # not this recipe's.
    {
      run = <<EOT
grep -q "^Libs: -L" "{{prefix}}/lib/pkgconfig/mpc.pc"
grep -q "Requires.private:.*mpfr" "{{prefix}}/lib/pkgconfig/mpc.pc"
EOT
    },

    # ⛔⛔ ONE PROGRAM, TWO ASSERTIONS, AND THE SECOND IS THE WITNESS FOR AN
    # AUTO-DETECTION THAT HAS NO SWITCH TO PIN IT.
    #
    # (a) ARITHMETIC THROUGH BOTH LIBRARIES. i raised to the i is exp(-pi/2) on
    #     the principal branch — a real number, 0.207879576…, that no accident
    #     produces. Computing it exercises mpc_pow, which goes through mpfr's
    #     transcendentals and therefore through libgmp, so this fails both if mpc
    #     was built against libraries it cannot find at run time and if the
    #     arithmetic is wrong. Nine decimals are asserted rather than twenty
    #     because the tenth is a rounding boundary (…5076…) and the test should
    #     witness the value, not a rounding mode.
    #
    # (b) THE FOUR C-COMPLEX SYMBOLS MUST EXIST. `mpc_get_dc` is one of exactly
    #     four declarations gated at src/mpc.h.in:283 by `_MPC_HAVE_COMPLEX_H`,
    #     which MPC_COMPLEX_H in m4/mpc.m4 sets from a compile-and-link probe of
    #     complex.h and substitutes into the INSTALLED header at :28 — and which
    #     also gates src/get_x.c and src/set_x.c, so the symbols leave the library
    #     binary too, not just the header. There is no `--enable-complex` to pin
    #     it with: unlike mpfr's --enable-float128 (#135), which this tree
    #     disables by NAMING a value, the only way to make this detection's
    #     outcome a stated property of the artifact is to assert it. Calling
    #     mpc_get_dc here does that at the sharpest point — if the probe ever
    #     fails, mpc.h declares neither it nor its three siblings and this test
    #     DOES NOT COMPILE.
    {
      run = <<EOT
cat > conftest.c <<'SRC'
#include <complex.h>
#include <mpc.h>
#include <mpfr.h>
#include <stdio.h>
#include <string.h>

int main (void)
{
  mpc_t z, w;
  mpfr_t re;
  char buf[64];
  double _Complex d;

  mpc_init2 (z, 200);
  mpc_init2 (w, 200);
  mpfr_init2 (re, 200);

  /* (a) i^i = exp(-pi/2) = 0.207879576..., through mpfr and libgmp. */
  mpc_set_si_si (z, 0, 1, MPC_RNDNN);
  mpc_pow (w, z, z, MPC_RNDNN);
  mpc_real (re, w, MPFR_RNDN);
  mpfr_sprintf (buf, "%.9Rf", re);
  printf ("i^i = %s\n", buf);
  if (strcmp (buf, "0.207879576") != 0)
    {
      printf ("mpc: wrong value for i^i: %s\n", buf);
      return 1;
    }

  /* (b) The witness: this call does not compile unless the complex.h probe
     put _MPC_HAVE_COMPLEX_H into the installed mpc.h. */
  d = mpc_get_dc (w, MPC_RNDNN);
  if (!(creal (d) > 0.2078 && creal (d) < 0.2079))
    {
      printf ("mpc: mpc_get_dc disagrees: %f\n", creal (d));
      return 1;
    }

  mpfr_clear (re);
  mpc_clear (w);
  mpc_clear (z);
  return 0;
}
SRC
cc conftest.c -I"{{prefix}}/include" -L"{{prefix}}/lib" \
   -I"{{deps.gnu.org/mpfr.prefix}}/include" -L"{{deps.gnu.org/mpfr.prefix}}/lib" \
   -I"{{deps.gnu.org/gmp.prefix}}/include" -L"{{deps.gnu.org/gmp.prefix}}/lib" \
   -lmpc -lmpfr -lgmp -o conftest
./conftest
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",      # the eight-switch census at :39-97, all defaults unset; :31-32 and :104-106 the CC/CFLAGS guard; :142-157 the -lgmp/-lmpfr links; :160 and :186 the .pc version floors; :174-176 and :196-198 the #error floors; :208-220 what logging pulls in; :239-241 the MPC_DEBUG environment variable
    "m4/mpc.m4",         # MPC_GMP_CC_CFLAGS, which reads __GMP_CC/__GMP_CFLAGS out of gmp.h; MPC_COMPLEX_H, the detection with no switch
    "src/mpc.h.in",      # :8-17 the LGPL statement; :28-31 the MPC_HAVE_COMPLEX_H substitution; :283-288 the four symbols it gates
    "src/Makefile.am",   # :20 lib_LTLIBRARIES = libmpc.la, no bin_PROGRAMS
    "Makefile.am",       # :29 pkgconfig_DATA, :32 include_HEADERS with its conditional @MPC_LOG_H@
    "doc/Makefile.am",   # :20 info_TEXINFOS = mpc.texi, the installed manual
    "doc/mpc.texi",      # :19-22 the GFDL-1.3-or-later statement that makes the licence an AND
    "mpc.pc.in",         # Requires.private, the two substituted version floors
    "COPYING.LESSER",    # the LGPL version 3 text that ships
    "tests/random.c",    # :63-70, the only consumers of MPC_CC and MPC_GCC_VERSION
  ]

  consulted = [
    # Read for the key material and for a third digest path; gave the fingerprint
    # and the digest, not the key.
    "archlinux/packaging/packages/mpc PKGBUILD (validpgpkeys, source, sha256sums)",
    # Read for the sibling levers and the licence contrasts this recipe draws.
    "go-zpkg/pantry-overlay projects/gnu.org/mpfr/package.hcl",
    "go-zpkg/pantry-overlay projects/gnu.org/gmp/package.hcl",
    # Read to establish that nothing already sets CC in a build, and for the
    # precedent that `cc` is the name that works here.
    "go-zpkg/zpkb buildscript/buildscript_test.go:42,153",
    "go-zpkg/pantry-overlay projects/ruby-lang.org/package.hcl:30",
    # Read to check, rather than assume, that mpc.pc's Requires.private can be
    # satisfied.
    "gmp-6.3.0 Makefile.am:121-122, mpfr-4.2.2 Makefile.am:43-44",
  ]

  note = <<EOT
⛔⛔ THE FINDING: MPC TAKES ITS COMPILER AND ITS FLAGS OUT OF ANOTHER PACKAGE'S
INSTALLED HEADER.

m4/mpc.m4's MPC_GMP_CC_CFLAGS preprocesses `#include "gmp.h"` to extract
`__GMP_CC` and `__GMP_CFLAGS`, checks that the pair compiles a trivial program,
and then assigns `CC=$GMP_CC` and `CFLAGS=$GMP_CFLAGS`. configure.ac:104-106
runs it whenever neither CC nor CFLAGS arrived from outside, the two having been
captured at :31-32 before AC_PROG_CC so they hold only what the environment
supplied.

Every auto-detection found earlier in this campaign decided something about the
artifact: what it links (curl's brotli and zstd, glibc's libgd and libselinux),
how it was code-generated (glibc's --enable-cet), what it contains (texinfo's
bin/info), or what it exports (mpfr's --enable-decimal-float and
--enable-float128). This one decides WHICH COMPILER BUILDS IT, from a string
another package baked into its own header — one rung above everything on that
ladder, because it is not a property of mpc's configuration at all.

The chain makes it concrete rather than theoretical. go-zpkg/pantry-overlay#134
exists because gmp tunes itself to the build machine's exact CPU, and
`__GMP_CFLAGS` is precisely the record of how that gmp was compiled. So a gmp
built elsewhere would hand its flags — and, through `__GMP_CC`, possibly a
different compiler — to libmpc, and nothing in the resulting artifact would say
where either came from.

⚠ AND THE SANDBOX DOES NOT ALREADY PREVENT THIS. Checked rather than assumed:
`CC` appears in zpkb's Go sources only inside buildscript's own tests, and
`ZBK_CC` and `ZBK_` appear nowhere in zpkb at all, so nothing exports a compiler
into a build and the macro really would run. Setting CC in this recipe makes the
`&&` at configure.ac:104 false and the extraction never happens; CFLAGS then
comes from AC_PROG_CC's own `-g -O2`, which is the same on every builder.

⛔ A SECOND IMPLICIT INPUT, STATED THOUGH NOT ACTED ON: configure.ac:239-241
reads the ENVIRONMENT VARIABLE `MPC_DEBUG` — not a switch, not in --help — and
appends `-Werror` to CFLAGS if it is non-empty. A builder with that variable set
for unrelated reasons gets a different, more fragile build. It is left alone
because the remedy belongs one level up: a build sandbox that passes an explicit
environment rather than the ambient one. Naming it here would hide a sandbox
question inside one recipe, and there are certainly other projects reading
variables like it.

⭐⭐ AND THE SWITCH SURFACE IS CLEAN, which is worth recording as a positive
result because this campaign has not met one before. mpc has eight
AC_ARG_WITH/AC_ARG_ENABLE and every default is a fixed constant — unset. No
`[default=auto]`, no `[default=autodetect]`, nothing for the build machine to
decide. Two are passed anyway (--disable-logging, --disable-valgrind-tests)
because each decides what enters the artifact or what the runner is searched
for, and the campaign writes such decisions down instead of inheriting them;
both are genuinely acted on by configure, so neither is the inert-flag mistake
go-zpkg/zpkb#486 is about.

⛔⛔ BUT THE DETECTION THAT CHANGES THE EXPORTED API HAS NO SWITCH AT ALL. m4/mpc.m4's
MPC_COMPLEX_H compiles and links a probe using `complex double`, `creal`,
`cimag` and `I`, and substitutes the answer into the INSTALLED header at
src/mpc.h.in:28. On success `_MPC_HAVE_COMPLEX_H` is defined and :283-288
declares exactly four functions — mpc_set_dc, mpc_set_ldc, mpc_get_dc,
mpc_get_ldc — which also gate src/get_x.c and src/set_x.c, so a failed probe
removes them from the library binary as well as from the header.

That is mpfr's --enable-float128 severity (#135) with the lever missing. mpfr
could be pinned by naming a value; here there is nothing to name, so the only
way to make the outcome a stated property of the artifact is to ASSERT it, which
the test block does by calling mpc_get_dc — a call that does not compile if the
probe ever fails. The choice is also the opposite of mpfr's, deliberately: there
the two detections were switched OFF because GCC asks for a mpfr version and not
for those helpers, whereas these four are what every C consumer of mpc uses to
get a value in and out, and C99 complex.h is available on every target this tree
builds for.

⭐ THREE DIGEST PATHS, ONE ANSWER — the builder's own fetcher, an independent
`curl --fail` plus `shasum -a 256`, and Arch's published sha256sums over the SAME
ftp.gnu.org tarball. Neither sibling had three: #135's third party published
sha512 and b2 sums only, and #134's pinned a different archive entirely.

⛔ THE SIGNATURE IS THE FOURTH INSTANCE OF A PATTERN THIS CAMPAIGN KEEPS MEETING:
a current signature over a key whose only obtainable copy is long expired. The
signature is DSA/SHA-256 from 2026-04-16 naming primary
ad17a21ef8aed8f1cc02dbd9f7d5c9bf765c61e3, which Arch pins as Andreas Enge, so a
third party vouches for the fingerprint over these exact bytes. ftp.gnu.org's
keyring holds a copy of that key whose self-signature is from 2010-05-14 and
expired 2015-05-13 — eleven years before the signature was made — and sourcepin
refuses it, correctly.

⚠ WHAT IS NOT CLAIMED. There is ONE copy, so nothing here measures the key's
state, only that copy's: a 2010 self-signature with a five-year lifetime says
nothing about whether Andreas Enge renewed it, and since he signed a release in
2026 he evidently did. The honest statement is the one #134 arrived at for gmp —
the only copy obtainable says expired; whether a newer self-signature exists is
unknown to this session. Routes exhausted: WKD for andreas.enge@inria.fr returns
404, and multiprecision.org/mpc serves 200 but mentions no key, fingerprint or
signature. No keyserver was asked: an unknown key from a pool would reduce the
check to "somebody signed it".

⭐ TWO MEASURED NEGATIVES, kept so nobody re-finds them as defects:

1. `MPC_CC` and `MPC_GCC_VERSION` are AC_DEFINE_UNQUOTED'd at configure.ac:231-233
   with the compiler's name and version, which looks exactly like the baked
   store path of go-zpkg/zpkb#397. They are consumed in tests/random.c:63-70
   alone, printed by the test harness, and reach no installed file — config.h is
   not in include_HEADERS and no source under src/ reads either macro.
2. mpc.pc's `Requires.private: mpfr >= 4.1.0, gmp >= 5.0.0` would be
   unsatisfiable if either dependency shipped no pkg-config file. Both do, read
   from their own trees: gmp-6.3.0/Makefile.am:121-122 and
   mpfr-4.2.2/Makefile.am:43-44. Whether those directories are on the search
   path is go-zpkg/zpkb#493 and not this recipe's business.

⚠ NOT BUILT. No session here runs the factory, so what is established is this
recipe's INPUTS: all eight switches with their defaults read from configure.ac,
the two decided and why, the CC extraction traced through m4/mpc.m4 to its guard
and shown not to be prevented elsewhere, the complex.h detection traced to the
four symbols it gates in both the header and the library, the installed set read
from four Makefile.am files, the absence of a makeinfo dependency confirmed by
the prebuilt doc/mpc.info, and the licence read from mpc's own header and its own
manual. The test block computes i^i to nine correct decimals through mpfr and
libgmp and calls mpc_get_dc, which is the regression witness for the detection
that cannot be pinned by a flag.
EOT
}
