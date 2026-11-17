# gnu.org/gmp — GNU multiple-precision arithmetic, and the first of the four
# projects `gnu.org/gcc/libstdcxx` needs before it can exist at all.
#
# ⛔ WRITTEN FROM GMP'S OWN FILES (go-zpkg/packages#431), at 6.3.0.
#
# ⭐ WHY THIS PROJECT NOW, when it is not a member of go-zpkg/base-toolchain.
# go-zpkg/recipes#88's campaign is down to one unread member,
# `gnu.org/gcc/libstdcxx`, and that one is not recipe-shaped: libstdc++'s own
# manual states "Building libstdc++ separately from the rest of GCC is not
# supported", so it needs a `gnu.org/gcc`, which in turn needs gmp (>=4.2),
# mpfr (>=2.4.0) and mpc (>=0.8.0) — none of them in this tree. gmp is the only
# one of the four with no prerequisite but a C compiler, so it is where that
# chain starts. Reported in full on go-zpkg/recipes#88.

summary = "GNU MP: arbitrary-precision arithmetic on integers, rationals and floats"

# ⛔⛔ AN **OR**, NOT AN AND, AND THE DISTINCTION IS THE WHOLE POINT. Four
# licence texts ship — COPYING, COPYINGv2, COPYINGv3, COPYING.LESSERv3 — and
# gmp-h.in:8-19 says which applies:
#
#   The GNU MP Library is free software; you can redistribute it and/or modify
#   it under the terms of EITHER:
#     * the GNU Lesser General Public License … version 3 … or any later
#   or
#     * the GNU General Public License … version 2 … or any later
#
# So the recipient CHOOSES. That is a disjunction, unlike gnu.org/glibc
# (go-zpkg/recipes#127), whose expression is an AND because the library
# and nscd are under different terms simultaneously. Writing `AND` here would
# overstate the obligation on every consumer.
license = "LGPL-3.0-or-later OR GPL-2.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/gmp/"
  match = "/gmp-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^gmp-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  # ⚠ ftp.gnu.org's `.tar.xz` and NOT gmplib.org's `.tar.lz`, which is the
  # upstream's own preferred format. Two reasons, both stated because the choice
  # is visible in the digest: `.lz` needs lzip, which this tree does not carry,
  # and every other recipe here takes an xz from a GNU mirror. ⚠ The
  # consequence is in `provenance.note`: Arch pins the `.lz`, so its published
  # digest is for different bytes and cannot corroborate this one.
  url              = "https://ftp.gnu.org/gnu/gmp/gmp-{{version.raw}}.tar.xz"
  strip-components = 1

  # 2094196 bytes. Two independent hash paths, one answer: the builder's own
  # fetcher and an independent `curl --fail` + `shasum -a 256`.
  #
  # ⚠⚠ THE SIGNATURE IS PUBLISHED, THE FINGERPRINT IS DOUBLY PUBLISHED, AND THE
  # KEY MATERIAL IS ONLY OBTAINABLE EXPIRED. Measurement in `provenance.note`.
  sha256 = {
    "6.3.0" = "a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898"
  }
}

# ⚠ NO RUNTIME DEPENDENCIES: libgmp links nothing but libc. And no `provides`
# block — gmp installs a library and headers, no programs, which is the shape
# zlib.net already has in this tree.

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  # ⛔ THE SWITCH CENSUS: twelve AC_ARG_ENABLE/AC_ARG_WITH. Three are decided
  # here and the rest keep defaults that are fixed constants in gmp's own
  # configure.ac:
  #
  #   :86   --enable-assert       default no
  #   :104  --enable-alloca       default (detect, but a compiler property)
  #   :129  --enable-cxx          default NO -> no libgmpxx, no gmpxx.h
  #   :138  --enable-assembly     default yes
  #   :147  --enable-fft          default yes
  #   :161  --enable-old-fft-full default no
  #   :175  --enable-nails        default no
  #   :194  --enable-profiling    default no
  #   :228  --with-readline       default DETECT   <- decided below
  #   :238  --enable-fat          default NO       <- decided below
  #   :248  --enable-minithres    default no (testing)
  #   :258  --enable-fake-cpuid   default no (testing)
  #
  # ⚠ `--enable-cxx` stays at its default `no`, stated because it changes what
  # is installed: Makefile.am:143,145 gate `libgmpxx.la` and `gmpxx.h` behind it.
  # GCC's prerequisite is libgmp, the C library, so nothing in the chain this
  # recipe exists to unblock needs the C++ wrapper. A consumer that does will
  # need this flipped, and then the recipe has a C++ compiler dependency it does
  # not have today.
  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ THE DEFECT THIS RECIPE EXISTS TO PREVENT: GMP TUNES ITSELF TO THE
      # BUILD MACHINE'S EXACT CPU, AND A DISTRIBUTED ARTIFACT THEN CRASHES
      # ELSEWHERE.
      #
      # gmp ships its OWN config.guess — 209 lines of CPU probing, including
      # `/proc/cpuinfo` (config.guess:185), Apple M1/M2 detection (:179-181),
      # and an `exact_cpu` variable (:74-82) whose stated purpose is to identify
      # the running chip. configure.ac then branches on the resulting triple,
      # and acinclude.m4:66's X86_64_PATTERN is the proof of how fine-grained
      # that is — it enumerates `skylake*`, `zen*`, `icelake*`, `alderlake*`,
      # `raptorlake*` and a dozen more as distinct hosts.
      #
      # So a default build on a Skylake runner emits Skylake code paths, and the
      # artifact SIGILLs on anything older. For a package manager shipping one
      # binary to many machines that is not a tuning choice, it is a
      # portability defect.
      #
      # ⭐ TWO LEVERS, AND BOTH ARE NEEDED:
      #
      # 1. `--build={{hw.target}}` stops the probe. Autoconf runs config.guess
      #    only when --build is absent, so naming the target explicitly yields
      #    the GENERIC arm of each pattern (`x86_64-*-*` rather than
      #    `skylake-*-*`). {{hw.target}} is the builder's own notion of the
      #    target triple — `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu`,
      #    `aarch64-apple-darwin` — all of which gmp's patterns accept.
      "--build={{hw.target}}",

      # ⛔ 2. `--with-readline=no`. Its default is DETECT (configure.ac:235), an
      # auto-detection of an external library, which is the class this campaign
      # keeps meeting. ⭐ MEASURED NEGATIVE, recorded so nobody thinks it was
      # load-bearing: readline's only consumer is `demos/calc`, and both
      # demos/Makefile.am:44 and demos/calc/Makefile.am:40 declare their
      # programs as `EXTRA_PROGRAMS` — automake builds those only on an explicit
      # `make allprogs` and never installs them. So the detection could not have
      # reached the artifact. It is switched off anyway, because a build whose
      # configure log differs by what happened to be staged is still not
      # reproducible.
      "--with-readline=no",
    ]

    # ⛔⛔ LEVER 1 IS NOT ENOUGH ON x86-64, WHICH IS WHY THIS IS PLATFORM-KEYED.
    # A generic `--build` removes the microarchitecture tuning but also removes
    # the SPEED that tuning bought. `--enable-fat` is gmp's own answer: build
    # every variant and dispatch on the CPU at RUN time
    # (configure.ac:2343-2374 lists the fat function set and the per-chip
    # search path).
    #
    # ⚠ AND IT IS SUPPORTED ON x86/x86-64 ONLY — measured, not assumed. The
    # whole `enable_fat = yes` block sits inside
    # `case $host in X86_PATTERN | X86_64_PATTERN)` (configure.ac:2336-2339),
    # and `fat_path` is assigned nowhere else. On aarch64 or s390x the flag is
    # therefore accepted by configure and acted on by NOTHING — a recipe flag
    # the project does not honour, which is go-zpkg/zpkb#486's subject and the
    # same trap go-zpkg/recipes#131 declined with libtool's inert
    # `--disable-ltdl-install`.
    #
    # So it is passed where it works and omitted where it would be theatre.
    # ⚠ On aarch64 and s390x the artifact is therefore generic-tuned with no
    # runtime dispatch: correct everywhere, slower than a host-tuned build. That
    # is the right trade for a distributed binary and is stated rather than
    # hidden.
    "linux/x86-64" = {
      ARGS = [
        "--prefix={{prefix}}",
        "--build={{hw.target}}",
        "--with-readline=no",
        "--enable-fat",
      ]
    }
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

test {
  script = [
    # The library and its header are the whole artifact.
    "test -f \"{{prefix}}/include/gmp.h\"",
    {
      run = <<EOT
ls "{{prefix}}"/lib/libgmp.* >/dev/null
EOT
    },

    # ⛔⛔ AND IT HAS TO COMPUTE, not merely exist. A gmp built for the wrong CPU
    # links and installs and then dies on the first multiply — so the test does
    # arithmetic big enough to leave the single-limb paths, where the tuned
    # assembly actually lives.
    {
      run = <<EOT
cat > conftest.c <<'SRC'
#include <gmp.h>
#include <stdio.h>
int main (void)
{
  mpz_t a, b;
  mpz_init_set_ui (a, 3);
  mpz_init (b);
  /* 3^5000 exercises multi-limb multiplication, not a single-limb path. */
  mpz_pow_ui (b, a, 5000);
  if (mpz_sizeinbase (b, 2) < 7000)
    { printf ("unexpectedly small result\n"); return 1; }
  printf ("ok %zu bits\n", mpz_sizeinbase (b, 2));
  return 0;
}
SRC
cc conftest.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lgmp -o conftest
./conftest
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",            # the twelve-switch census; :235 --with-readline default DETECT; :245 --enable-fat default NO; :2336-2374 the fat block inside the X86/X86_64 host case
    "acinclude.m4",            # :62,:66 X86_PATTERN and X86_64_PATTERN — the per-microarchitecture host list that proves how fine-grained the tuning is
    "config.guess",            # gmp's OWN, 209 CPU probes: :74-82 exact_cpu, :179-181 Apple M1/M2, :185 /proc/cpuinfo
    "Makefile.am",             # :116 SUBDIRS includes demos; :143,:145 libgmpxx and gmpxx.h gated on --enable-cxx; lib_LTLIBRARIES = libgmp.la
    "demos/Makefile.am",       # :44 EXTRA_PROGRAMS — never built by `make all`, never installed
    "demos/calc/Makefile.am",  # :40 the same, and calc is readline's only consumer
    "gmp-h.in",                # :8-19 the LGPLv3+ OR GPLv2+ disjunction
    "COPYING",                 # one of four licence texts that ship
  ]

  consulted = [
    # Read for the key and for a possible second digest path; it gave the first
    # and not the second.
    "archlinux/packaging/packages/gmp PKGBUILD (validpgpkeys, source, sha256sums)",
    # The project's own page, which publishes the fingerprint.
    "https://gmplib.org/ (the release-signing key block)",
  ]

  note = <<EOT
⭐ THE FINGERPRINT IS PUBLISHED TWICE, INDEPENDENTLY, AND ONE OF THE TWO IS THE
PROJECT ITSELF — which is better than every recipe written before it today.

gmplib.org's own download page states:

    Key ID: 0x28C67298
    Key type: 2560 bit RSA
    Fingerprint: 343C 2FF0 FBEE 5EC2 EDBE  F399 F359 9FF8 28C6 7298

and Arch's gmp PKGBUILD carries the same string as
`validpgpkeys=('343C2FF0FBEE5EC2EDBEF399F3599FF828C67298')  # Niels Möller`.
The signature on the tarball names that key (RSA/SHA-512, created 2023-07-30,
issuer fingerprint present in the packet). So WHO is settled from two sources,
neither of which is the signature itself.

⛔⛔ AND THE KEY MATERIAL IS ONLY OBTAINABLE EXPIRED, so the signature is NOT
verified here. The one copy this fleet can reach is in
ftp.gnu.org/gnu/gnu-keyring.gpg, and reading it:

    primary 343c2ff0fbee5ec2edbef399f3599ff828c67298, created 2013-01-07
    identity "Niels Möller <nisse@lysator.liu.se>"
      self-sig created 2013-01-07, key expiry 2023-01-05 (EXPIRED)
      subkey  48c9de74…, expiry 2023-01-05 (EXPIRED)

`sourcepin` refuses it with `openpgp: key expired`, correctly: the signature is
dated 2023-07-30, seven months after that copy's expiry.

⚠ WHAT IS **NOT** CLAIMED, and the distinction matters because
go-zpkg/recipes#131 could make it and this recipe cannot. For libtool
there were TWO copies of the key to compare, so "the governing self-signature
had lapsed" was a measurement. Here there is ONE copy. A 2013 self-signature
with a ten-year lifetime says nothing about whether Niels Möller extended it in
2023 — he is still releasing gmp, so he very likely did. So the honest statement
is about the copy, not the key: **the only copy obtainable says expired; whether
a newer self-signature exists is unknown to this session.**

Routes tried and exhausted: no WKD for nisse@lysator.liu.se (both the advanced
and direct methods 404), and gmplib.org publishes the fingerprint but directs
the reader to "a key server directly to get the key" — which is the one source
this fleet does not accept, since accepting an unknown key from a pool degrades
the check to "somebody signed it".

So the digest rests on its two independent hash paths, as
kernel.org/linux-headers (#126), gnu.org/libtool (#131) and
freedesktop.org/pkg-config (#133) do. ⚠ And there is no third path here: Arch
pins gmplib.org's `.tar.lz`, a DIFFERENT archive, whose published sha256
(`be5c908a…`) is for different bytes than this `.tar.xz` (`a3c2b802…`). Treating
those as corroborating each other would be the mistake this note exists to
prevent.

⚠ One thing read in Arch's recipe and deliberately not copied: it applies a
`gmp-gcc-15.patch` "Fix build with GCC 15". This tree's compiler is clang
(go-zpkg/recipes#127 established that clang ≥ 18 is what the toolchain
offers), so that patch addresses a compiler this build does not use — and
go-zpkg/packages#431 forbids seeding from other distributions' packaging in any
case.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS — all twelve switches with every default stated, the three
decided with their mechanism traced to configure.ac and acinclude.m4, the
licence disjunction from gmp's own header, and the measured negative that
readline cannot reach the artifact. The test block is written to fail on the
thing most likely to be wrong: a library that installs and then cannot multiply,
which is what a wrong-CPU build looks like.
EOT
}
