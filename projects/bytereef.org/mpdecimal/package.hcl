# bytereef.org/mpdecimal — correctly-rounded arbitrary precision decimal
# arithmetic, which 1 recipe in this tree names (python.org, whose `decimal`
# module is this library).
#
# ⛔ WRITTEN FROM MPDECIMAL'S OWN FILES (go-zpkg/packages#431), at 4.0.1.
# Twelfth of the twenty-two in go-zpkg/recipes#143.

summary = "mpdecimal: correctly-rounded arbitrary precision decimal arithmetic"

# Read from `COPYRIGHT.txt` — ⚠ not LICENSE.txt, which this tarball does not
# contain: the two-clause BSD text, over "Copyright (c) 2008-2025 Stefan Krah.
# All rights reserved." The two conditions are the source-form and binary-form
# notices and nothing else, so the expression is BSD-2-Clause and not -3-.
license = "BSD-2-Clause"

versions {
  url   = "https://www.bytereef.org/mpdecimal/download.html"
  match = "/mpdecimal-\\d+\\.\\d+\\.\\d+\\.tar\\.gz/"
  strip = [
    "/^mpdecimal-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://www.bytereef.org/software/mpdecimal/releases/mpdecimal-{{version.raw}}.tar.gz"
  strip-components = 1

  # 316268 bytes.
  sha256 = {
    "4.0.1" = "96d33abb4bb0070c7be0fed4246cd38416188325f820468214471938545b1ac8"
  }

  # ⚠ NO SIGNATURE, AND A CHECKSUM ON THE SAME PAGE AS THE LINK. The download
  # page carries a `sha256sum` column per release, and the value for 4.0.1
  # reproduces ours exactly — but it is served by the same host over the same
  # connection as the tarball, so it establishes that we fetched what
  # bytereef.org published, not that nobody else could have published it. The
  # same rung as gnome.org/libxml2 (#149), and below libxcrypt (#156), whose
  # signing key has an independent copy.
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⭐ THE DOCUMENTATION IS DROPPED WITH THE FLAG THE PROJECT PROVIDES, not
      # by deleting it afterwards. The pantry's recipe ends with
      #
      #   rm -rf {{prefix}}/share   # docs are online
      #
      # — a recipe removing part of its own prefix, with a reason that is about
      # the web rather than about this build, and one mis-expansion away from
      # removing something else. configure:1394 offers `--enable-doc (default
      # is yes)`, so `--disable-doc` is the same outcome asked for rather than
      # undone. The same shape as the `rm -rf {{prefix}}/include` not carried
      # into invisible-island.net/ncurses (#152).
      "--disable-doc",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: mpdecimal installs libraries and headers and no programs.
# The pantry names none either.

test {
  script = [
    "test -f \"{{prefix}}/include/mpdecimal.h\"",
    {
      run = <<EOT
set -eu
ls "{{prefix}}"/lib/libmpdec.* >/dev/null 2>&1 \
  || { echo "libmpdec is missing from {{prefix}}/lib" >&2; exit 1; }
EOT
    },

    # ⛔⛔ AND IT HAS TO BE CORRECTLY ROUNDED, which is the entire claim of this
    # library and the reason python.org uses it. 1/3 at 9 digits of precision
    # has one right answer, and a decimal implementation that is merely
    # arbitrary-precision gets it wrong in the last place.
    {
      run = <<EOT
set -eu
cat > probe.c <<'CEOF'
#include <stdio.h>
#include <string.h>
#include <mpdecimal.h>
int main(void) {
  mpd_context_t ctx;
  mpd_init(&ctx, 9);
  mpd_t *a = mpd_new(&ctx), *b = mpd_new(&ctx), *q = mpd_new(&ctx);
  mpd_set_string(a, "1", &ctx);
  mpd_set_string(b, "3", &ctx);
  mpd_div(q, a, b, &ctx);
  char *s = mpd_to_sci(q, 1);
  printf("%s\n", s);
  int ok = strcmp(s, "0.333333333") == 0;
  mpd_free(s); mpd_del(a); mpd_del(b); mpd_del(q);
  return ok ? 0 : 1;
}
CEOF
cc probe.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lmpdec -o probe
./probe > out.txt || { echo "1/3 at 9 digits is not 0.333333333:" >&2; cat out.txt >&2; exit 1; }
EOT
    },

    # ⚠ AND THE DOCUMENTATION MUST NOT HAVE BEEN INSTALLED, which is what
    # `--disable-doc` asks for. Without this the flag could be dropped and
    # nothing would notice until a bottle grew a share/ tree again.
    {
      run = <<EOT
set -eu
if [ -d "{{prefix}}/share/doc" ]; then
  echo "documentation was installed — --disable-doc was dropped" >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "COPYRIGHT.txt", # the two-clause BSD text and "Copyright (c) 2008-2025 Stefan Krah" — the licence file is NOT named LICENSE.txt here
    "configure",    # :1391-1395 the five switches and their stated defaults, all written "(default is yes)"
    "configure.ac", # :460-474 ENABLE_CXX defaults yes unless MACHINE is ansi-legacy; :612-618 it is forced off for xlc/suncc/ccomp; :883-919 DETECTED_MACHINE, which reads sizeof(size_t), have_gcc_asm_for_x64, __uint128_t support and the compiler's NAME; :703 the refusal when a toolchain cannot handle the MACHINE it was given
    "Makefile.in",  # :9, :42, :110, :130, :139 — what ENABLE_CXX switches on; no bin_PROGRAMS anywhere
  ]

  consulted = [
    "pkgxdev/pantry projects/bytereef.org/mpdecimal/package.yml", # read deliberately: the `rm -rf {{prefix}}/share` this recipe replaces with a flag is its
    "https://www.bytereef.org/mpdecimal/download.html",           # the per-release sha256sum column
  ]

  note = <<EOT
⚠ THE ARITHMETIC BACKEND IS CHOSEN FROM THE COMPILER, NOT THE TARGET — and this
recipe deliberately does NOT pin it, which is a decision rather than an
oversight. configure.ac:883-919 picks DETECTED_MACHINE from four things:
`sizeof(size_t)` (a target property), `have_gcc_asm_for_x64` (a COMPILE PROBE),
`ac_cv_type___uint128_t` (a compiler property) and, on 32-bit, the compiler's
NAME. So one target with two different compilers can yield `x64`, `uint128` or
`ansi64` — three implementations of the same arithmetic.

⭐ Unlike sourceware.org/libffi (#154), where the builder's CPUID chose
`-march` and the artifact could SIGILL elsewhere, the three backends here are
behaviourally identical: mpdecimal is correctly rounded by construction and the
backends differ in how they reach the same digits. What varies is the binary,
not the answer.

⛔ AND PINNING IT WOULD TRADE A REAL RISK FOR A WORSE ONE. MACHINE is settable
from the environment (configure.ac:917, `if test -z "$MACHINE"`), so this recipe
COULD force `x64` — and configure.ac:703 then refuses outright with "toolchain
cannot handle MACHINE=$MACHINE" on any toolchain that cannot. Pinning would
convert a variable-but-working build into one that fails on an unanticipated
compiler, for no change in results. The reading is recorded instead, which is
the same call libpng.org (#155) made about its SIMD switch.

⭐ THE DOCUMENTATION IS DROPPED WITH THE FLAG THE PROJECT PROVIDES. The pantry
ends its build with `rm -rf {{prefix}}/share   # docs are online` — a recipe
removing part of its own prefix, with a reason about the web rather than about
this build, one mis-expansion away from removing something else.
configure:1394 offers `--enable-doc (default is yes)`, so `--disable-doc` asks
for the same outcome instead of undoing it. Same shape as the
`rm -rf {{prefix}}/include` not carried into ncurses (#152). The test asserts the
absence, so dropping the flag goes red.

⚠ `acdefault` (go-fleettools/fleettools#347, #352) REFUSED THIS TREE, and the
refusal is a third measured gap in the tool rather than in the project.
mpdecimal's help lines DO state their defaults — `--enable-cxx  enable building
libmpdec++ (default is yes)` — in a spelling the command's pattern does not
recognise, which matches only a trailing `(on)`/`(off)`/`[default=X]`. It
reported "documents 6 switch(es) and a stated default for NONE of them", which
is true of its own reading and false of the file. Three projects now: pcre2 and
ncurses state nothing, mpdecimal states it in words.

⚠ NOT BUILT. Measured here: the digest against the sha256sum column on
bytereef.org's own download page, the switch census by hand after the tool
refused, and `zpkb lint`. The scripts are a claim about mpdecimal's build system
read from that build system, and they stay a claim until a factory runs them.
EOT
}
