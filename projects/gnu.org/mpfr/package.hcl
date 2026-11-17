# gnu.org/mpfr — GNU multiple-precision floating point, second of the four
# projects `gnu.org/gcc/libstdcxx` needs, and a gap gawk already had.
#
# ⛔ WRITTEN FROM MPFR'S OWN FILES (go-zpkg/packages#431), at 4.2.2.
#
# ⭐ IT CLOSES A SKIP THAT WAS ALREADY LIVE, which is worth saying because
# go-zpkg/recipes#134's description got this wrong for gmp and had to be
# corrected: `gnu.org/mpfr` is NOT reached through libstdcxx (that member is
# unread, so its dependencies are never walked). It is reached through
# `gnu.org/gawk`, a base-toolchain member, which declares it at
# projects/gnu.org/gawk/package.hcl:99-100 — put there by
# go-zpkg/recipes#114 because gawk "links libmpfr AND libgmp when it
# finds them, declares neither". So this closes one of the walk's 24 remaining
# skips on its own account, and happens to also be step two of the libstdcxx
# chain.

summary = "GNU MPFR: multiple-precision floating-point arithmetic with correct rounding"

# ⛔ READ FROM BOTH, and note it is a PLAIN LGPL — not gmp's disjunction.
# COPYING.LESSER is the LGPL version 3 text and src/mpfr.h:8-11 says "under the
# terms of the GNU Lesser General Public License … either version 3 of the
# License, or (at your option) any later version". Only one licence, so no
# AND and no OR: contrast gnu.org/gmp (go-zpkg/recipes#134), which is
# LGPLv3+ OR GPLv2+ at the recipient's choice.
license = "LGPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/mpfr/"
  match = "/mpfr-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^mpfr-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/mpfr/mpfr-{{version.raw}}.tar.xz"
  strip-components = 1

  # 1505596 bytes, recorded with the builder's own fetcher and a VERIFIED
  # signature, then confirmed by an independent `curl --fail` + `shasum -a 256`:
  # two paths, one answer.
  #
  #   signed by A534BE3F83E241D918280AEB5831D11A0D4DB02A
  #   Vincent Lefevre <vincent@vinc17.net>
  #   EdDSA/SHA-256, created 2025-03-20; no keyserver was asked
  #
  # ⭐ The fingerprint comes from Arch's mpfr PKGBUILD, which lists it as the
  # second of two validpgpkeys AND fetches the SAME ftp.gnu.org tarball — so
  # unlike gnu.org/gmp this is a third party vouching for the key over these
  # exact bytes. ⚠ Not a third DIGEST path, though: Arch publishes sha512sums
  # and b2sums, not sha256, so there is nothing to compare.
  sha256 = {
    "4.2.2" = "b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01"
  }
}

# ⛔ libmpfr links libgmp, so gmp is a RUNTIME dependency and not merely a build
# one. The floor is mpfr's own: its INSTALL and configure require GMP 5.0.0 or
# later for the 4.2 series, and `gnu.org/gmp`
# (go-zpkg/recipes#134) resolves 6.3.0.
dependencies = {
  "gnu.org/gmp" = ">=5"
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    "gnu.org/gmp"  = ">=5"
  }

  # ⛔ THE SWITCH CENSUS: nineteen AC_ARG_ENABLE/AC_ARG_WITH. Four are decided
  # here; the rest keep defaults that are fixed constants in configure.ac
  # (--enable-assert no, --enable-logging no, --enable-warnings no at :228,
  # --enable-shared-cache NO at :219 — which also keeps libmpfr from acquiring a
  # PTHREAD dependency — --enable-lto no, --enable-tune-for-coverage no,
  # --enable-debug-prediction no, --enable-formally-proven-code no,
  # --enable-gmp-internals no, --enable-tests-timeout, --with-mulhigh-size,
  # --with-mini-gmp unset, and the two --with-gmp-include/--with-gmp-lib
  # variants that :125 forbids combining with the one used below).
  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ WHERE GMP IS FOUND, STATED. configure.ac:117-127 is the documented
      # lever: `--with-gmp=DIR` adds `-I$DIR/include` and `-L$DIR/lib`, and
      # :125 REFUSES to be combined with --with-gmp-include/--with-gmp-lib. Left
      # unset, mpfr looks wherever CPPFLAGS/LDFLAGS happen to point — which in a
      # store is whatever the sandbox staged, i.e. the artifact's libgmp decided
      # by accident. This names our own.
      "--with-gmp={{deps.gnu.org/gmp.prefix}}",

      # ⛔⛔ THREE AUTO-DETECTIONS, AND TWO OF THEM CHANGE THE PUBLIC API.
      #
      #   configure.ac:268-271  --enable-decimal-float  [default=auto]
      #   configure.ac:280-283  --enable-float128       [default=autodetect]
      #
      # Each adds conversion functions to and from `_Decimal64`/`_Decimal128`
      # and `_Float128`/`__float128` IF THE COMPILER SUPPORTS THEM. So the
      # exported symbol set of libmpfr is decided by the build compiler — which
      # is worse than glibc's --enable-cet (go-zpkg/recipes#127), because
      # that changed code generation while this changes the ABI consumers link
      # against. A consumer built against a libmpfr that had __float128 fails on
      # one that did not, and nothing in either artifact says why.
      #
      # ⭐ Both switched OFF for determinism: the same symbol set on every
      # platform and every builder. ⚠ COST, STATED: a consumer wanting
      # mpfr_get_float128 or the decimal conversions does not get them. The
      # reason this is the right default here is that GCC — the project this
      # chain exists for — requires a VERSION of mpfr (>= 3.1.0 per its own
      # prerequisites page), not these conversion helpers; they exist for mpfr's
      # own callers converting between mpfr_t and those types. ⚠ Reasoned from
      # GCC's stated prerequisite, NOT from a build: if a GCC build turns out to
      # want them, these are two lines — but they should then be turned on by
      # NAMING a value, never by restoring the default.
      "--disable-decimal-float",
      "--disable-float128",

      # ⛔ The third detection, settled the other way. configure.ac:206-209
      # defaults --enable-thread-safe to AUTODETECT, so whether libmpfr uses
      # TLS — a behavioural property every threaded consumer depends on —
      # follows what the build compiler offered. Every target this tree builds
      # for has TLS under clang, so YES is both deterministic and correct.
      "--enable-thread-safe",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: mpfr installs a library and two headers — src/Makefile.am:30
# `include_HEADERS = mpfr.h mpf2mpfr.h` and :35 `lib_LTLIBRARIES = libmpfr.la`
# — and no programs. Same shape as zlib.net and gnu.org/gmp in this tree.

test {
  script = [
    "test -f \"{{prefix}}/include/mpfr.h\"",
    {
      run = <<EOT
ls "{{prefix}}"/lib/libmpfr.* >/dev/null
EOT
    },

    # ⛔⛔ IT HAS TO COMPUTE AND IT HAS TO LINK GMP. A correctly-rounded constant
    # at high precision exercises the paths that actually use libgmp, so this
    # fails both if mpfr was built against a gmp it cannot find at run time and
    # if the arithmetic is wrong.
    {
      run = <<EOT
cat > conftest.c <<'SRC'
#include <mpfr.h>
#include <string.h>
#include <stdio.h>
int main (void)
{
  mpfr_t x;
  char buf[64];
  mpfr_init2 (x, 200);
  mpfr_const_pi (x, MPFR_RNDN);
  mpfr_sprintf (buf, "%.20Rf", x);
  printf ("pi = %s\n", buf);
  /* 20 places of pi, correctly rounded, is a value no accident produces. */
  if (strncmp (buf, "3.14159265358979323846", 22) != 0)
    { printf ("wrong: %s\n", buf); return 1; }
  mpfr_clear (x);
  return 0;
}
SRC
cc conftest.c -I"{{prefix}}/include" -L"{{prefix}}/lib" \
   -I"{{deps.gnu.org/gmp.prefix}}/include" -L"{{deps.gnu.org/gmp.prefix}}/lib" \
   -lmpfr -lgmp -o conftest
./conftest
EOT
    },

    # ⛔ THE REGRESSION WITNESS for the two disabled detections. If a future edit
    # drops them, the compiler decides the ABI again. mpfr.h advertises the
    # conversions through a feature macro, so their ABSENCE is checkable without
    # running anything.
    {
      run = <<EOT
if grep -q "define MPFR_WANT_FLOAT128" "{{prefix}}/include/mpfr.h"; then
  echo "mpfr: MPFR_WANT_FLOAT128 is back in the installed header" >&2
  echo "  configure.ac:280-283 defaults --enable-float128 to autodetect," >&2
  echo "  which makes the exported API depend on the build compiler." >&2
  echo "  Restore --disable-float128 in build.env." >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",      # the nineteen-switch census; :105-127 the three --with-gmp* levers and their mutual refusal; :206-209 thread-safe AUTODETECT; :216-225 shared-cache no, with its PTHREAD note; :268-275 decimal-float auto; :280-288 float128 autodetect
    "src/mpfr.h",        # :8-11 the LGPL-3.0-or-later statement
    "src/Makefile.am",   # :30 include_HEADERS, :35 lib_LTLIBRARIES = libmpfr.la, no bin_PROGRAMS
    "COPYING.LESSER",    # the LGPL version 3 text that ships
    "COPYING",           # the GPL text that ships beside it
  ]

  consulted = [
    # Read for the key and for a possible third digest path; gave the first only.
    "archlinux/packaging/packages/mpfr PKGBUILD (validpgpkeys, source, sha512sums, b2sums)",
    # Read to place this recipe correctly in the walk, and it corrected the
    # framing go-zpkg/recipes#134 used for gmp.
    "go-zpkg/recipes projects/gnu.org/gawk/package.hcl:99-100",
  ]

  note = <<EOT
⭐ THE TRUST CHAIN IS THE STRONGER KIND, and the difference from gnu.org/gmp
(go-zpkg/recipes#134) is worth recording because the two look alike from
outside.

For gmp the fingerprint was doubly published — by gmplib.org itself and by Arch
— but the only obtainable key material was an expired 2013 copy, so the
signature could not be checked and the digest rested on two hash paths alone.

Here the key is in ftp.gnu.org's keyring, unexpired, and `sourcepin` VERIFIES
the signature: EdDSA/SHA-256 by A534BE3F83E241D918280AEB5831D11A0D4DB02A,
Vincent Lefevre. The fingerprint is corroborated by Arch's mpfr PKGBUILD, which
lists it and fetches the SAME ftp.gnu.org tarball — so a third party vouches for
the key over these exact bytes, which is what Arch's glibc and automake entries
could not do, both building signed git tags instead.

⚠ There is still no third DIGEST path: Arch publishes sha512sums and b2sums for
this file, not sha256, so there is nothing to compare against. Two paths.

⛔⛔ THE FINDING: TWO SWITCHES WHOSE DEFAULTS LET THE COMPILER CHOOSE libmpfr's
PUBLIC API. `--enable-decimal-float` is `[default=auto]` and `--enable-float128`
is `[default=autodetect]`, and each adds conversion functions to and from
`_Decimal64`/`_Decimal128` and `_Float128`/`__float128` when the compiler
supports them.

That is a step worse than the auto-detections this campaign has been finding.
curl's brotli, glibc's libgd and texinfo's terminal library decide what the
artifact LINKS or CONTAINS; glibc's --enable-cet decides code generation. These
two decide the set of symbols the library EXPORTS — so a consumer compiled
against a libmpfr that had `__float128` simply fails to link against one that
did not, and neither artifact records why. Both are switched off, which makes
the symbol set identical on every platform and every builder, and the cost is
stated in the recipe rather than discovered later.

⚠ And the reasoning behind "off" is cited rather than measured: GCC's own
prerequisites page asks for an mpfr VERSION (>= 3.1.0), not for these helpers,
which exist for mpfr's own callers. If a real GCC build turns out to want them,
it is two lines — but turning them ON must be done by naming a value, never by
restoring the default, or the builder's compiler decides the ABI again.

⭐ A measured negative worth keeping: `--enable-shared-cache` defaults to NO
(configure.ac:219), and its own help text says it "usually makes MPFR dependent
on PTHREAD". Left alone, so libmpfr acquires no pthread dependency — one fewer
thing for a from-scratch tree to carry.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS — all nineteen switches with every non-constant default
stated, the four decided with their mechanism traced to configure.ac, gmp
declared at run time because libmpfr links it, the installed set from
src/Makefile.am, and the licence from mpfr's own header. The test block computes
twenty correctly-rounded places of pi through libgmp — a value no accident
produces — and asserts the absence of MPFR_WANT_FLOAT128 from the installed
header, which is the regression witness for the two disabled detections.
EOT
}
