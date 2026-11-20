# gnu.org/gcc/libstdcxx — the GNU C++ runtime, and the LAST unread member of
# go-zpkg/recipes#88.
#
# ⛔ WRITTEN FROM GCC'S OWN FILES (go-zpkg/packages#431), at 14.4.0.
#
# ⛔⛔ THIS MEMBER IS A BOOTSTRAP CYCLE, AND SAYING SO IS PART OF THE RECIPE.
# `go-zpkg/base-toolchain` declares it (package.hcl:120) for a reason its own
# comment states and measured in an Incus container on 2026-08-27: the llvm.org
# artifact this tree installs is MIRRORED, so clang is linked against whatever
# distribution built it, and in a tree with no distribution
#
#   clang: error while loading shared libraries: libstdc++.so.6:
#   cannot open shared object file
#
# So clang needs libstdc++.so.6 to START; libstdc++ cannot be built apart from
# GCC — its own manual says "Building libstdc++ separately from the rest of GCC
# is not supported" — and GCC needs a C++ compiler to build. The cycle has no
# entry point from inside the set.
#
# ⭐ IT IS NOT A BLOCKER, because the factory already has the door: `zpkb
# factory --bootstrap` is documented as "FIRST FILL ONLY on an architecture no
# registry has: build without the base toolchain in the environment, taking
# those tools from the host", and build.BootstrapToolDeps exists because "the
# base toolchain is a cycle with no entry point". This recipe is what that first
# fill builds; every later build uses the artifact it produced.

summary = "GNU libstdc++: the C++ standard library and its runtime, from the GCC tree"

# ⛔⛔ A LICENCE WITH AN EXCEPTION, and it is the fourth distinct shape in this
# chain — the three siblings it depends on are each different again:
#
#   gnu.org/gmp  (#134)  LGPL-3.0-or-later OR GPL-2.0-or-later   recipient CHOOSES
#   gnu.org/mpfr (#135)  LGPL-3.0-or-later                       one licence
#   gnu.org/mpc  (#136)  LGPL-3.0-or-later AND GFDL-1.3-or-later two at once
#   here                 GPL-3.0-or-later WITH GCC-exception-3.1 one, MODIFIED
#
# Read from libstdc++'s own source rather than from the project's reputation:
# src/c++11/mutex.cc:6-9 places the library under "the GNU General Public
# License … either version 3, or (at your option) any later version", and
# :16-18 adds "Under Section 7 of GPL version 3, you are granted additional
# permissions described in the GCC Runtime Library Exception, version 3.1".
# Both texts ship: COPYING3 and COPYING.RUNTIME.
#
# ⛔ THE EXCEPTION IS THE WHOLE POINT and a plain `GPL-3.0-or-later` would be a
# serious misstatement: without it every program compiled against this library
# would inherit the GPL. `WITH` is SPDX's operator for exactly this, and it is
# why the expression cannot be simplified.
license = "GPL-3.0-or-later WITH GCC-exception-3.1"

versions {
  # ⚠ ftp.gnu.org/gnu/gcc/ lists one DIRECTORY per release, not tarballs, so
  # the match reads the directory names and `distributable.url` rebuilds the
  # nested path below.
  url   = "https://ftp.gnu.org/gnu/gcc/"
  match = "/gcc-\\d+\\.\\d+\\.\\d+/"
  strip = [
    "/^gcc-/",
    "/\\/$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/gcc/gcc-{{version.raw}}/gcc-{{version.raw}}.tar.xz"
  strip-components = 1

  # ⭐⭐ THE STRONGEST TRUST CHAIN IN THIS CAMPAIGN, and for one reason: the
  # fingerprint is published BY THE PROJECT ITSELF.
  #
  #   signed by D3A93CAD751C2AF4F8C7AD516C35B99309B5FA62
  #   Jakub Jelinek <jakub@redhat.com>
  #   RSA/SHA-1, created 2026-06-26 — VERIFIED, no keyserver was asked
  #
  # gcc.gnu.org/mirrors.html says "The archives there will be signed by one of
  # the following GnuPG keys" and lists seven release managers with full
  # fingerprints; this is the `4096R/09B5FA62` one. Every earlier recipe in this
  # chain had to borrow a fingerprint from Arch (gmp, mpfr, mpc) or go without
  # (glibc, automake); here the publisher and the signer are the same project.
  #
  # ⚠ TWO THINGS THE CHECK NEEDED, both recorded because they will recur:
  #
  # 1. The signature carries only a 64-bit KEY ID (6c35b99309b5fa62), not a
  #    fingerprint. On its own that is a weak selector; it is the PUBLISHED
  #    fingerprint that makes it meaningful, which is why --fingerprint is
  #    mandatory here rather than nice to have.
  # 2. ftp.gnu.org's gnu-keyring.gpg CANNOT BE READ WHOLE — it stops after 402
  #    primary keys on `openpgp: invalid data: Cannot have multiple embedded
  #    signatures` — and this key is beyond that point. `keyringscan -extract`
  #    pulled it out verbatim (5785 bytes, reading back as exactly one primary
  #    key) and sourcepin verified against that. A tool that gave up at the
  #    truncation would have reported this key ABSENT, which is not the same
  #    thing (go-zpkg/zpkb#482's neighbourhood).
  #
  # ⭐ And RSA/SHA-1 verifies fine. go-zpkg/zpkb#482 is about a DSA/SHA-1
  # signature being refused as "made by unknown entity"; this one is RSA with
  # the same digest and passes, which narrows that issue rather than widening it.
  #
  # ⚠ TWO DIGEST PATHS, not three: the builder's own fetcher and an independent
  # `curl --fail` + `shasum -a 256`, both 91586872 bytes. Arch cannot corroborate
  # — its gcc PKGBUILD builds from a GIT COMMIT (16.2.1+r23+gd564253eb6c8) with
  # no `validpgpkeys` at all, so it pins neither these bytes nor this key.
  #
  # ⛔⛔ 16.2.0 ADDED 2026-11-20, AND IT WAS A DEFECT THAT IT WAS MISSING.
  # `versions` resolves 16.2.0 first (`zpkb versions`), base-toolchain asks for
  # this member as "*", and a recipe that pins refuses to build a version it
  # did not pin (zpkb build/pinneddigest_test.go:28-43). So the default build of
  # this member was a refusal. 16.2.0 is the same digest gnu.org/gcc pins, and
  # the two move together: a program compiled by g++ N needs a libstdc++ at
  # least as new as N. Signer and the subkey finding: gnu.org/gcc's
  # provenance.note. The facts above were read at 14.4.0. At 16.2.0 they moved
  # but did not change: floors at configure.ac:1795/1813/1830, the clocale
  # re-probe at libstdc++-v3/acinclude.m4:2833-2838, `__uselocale` x3 in the
  # gnu c_locale.h and x0 in the generic one, so the witness still tells them
  # apart.
  sha256 = {
    "16.2.0" = "e6738e29597f733270731aa90600f37ffdc045079dfc27ec7e8192cc81085c3e"
    "14.4.0" = "752b6f567beac83159c77a7680b1316bdd784738bff9a9d070112c09da90f6d9"
  }
}

# ⛔ THE THREE ARE BUILD-ONLY, WHICH IS THE WHOLE POINT OF THIS SUBPROJECT.
# GCC's compiler links libgmp, libmpfr and libmpc; `libstdc++.so` and
# `libgcc_s.so` link NEITHER of them, and this recipe installs only the runtime.
# Declaring them at run time would put three multiple-precision libraries into
# the closure of every C++ program in the tree.
#
# The floors are GCC's own, each a `choke me` in its configure.ac rather than a
# number from its web page:
#
#   gmp  >= 4.2.3   configure.ac:1675
#   mpfr >= 3.1.0   configure.ac:1693
#   mpc  >= 0.8.0   configure.ac:1710
#
# This tree resolves gmp 6.3.0 (#134), mpfr 4.2.2 (#135) and mpc 1.4.1 (#136),
# which is why those three were written first.
build {
  dependencies = {
    "gnu.org/make" = "*"
    "gnu.org/gmp"  = ">=4.2.3"
    "gnu.org/mpfr" = ">=3.1.0"
    "gnu.org/mpc"  = ">=0.8.0"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--with-gmp={{deps.gnu.org/gmp.prefix}}",
      "--with-mpfr={{deps.gnu.org/mpfr.prefix}}",
      "--with-mpc={{deps.gnu.org/mpc.prefix}}",

      # ⛔ ONLY THE TWO LANGUAGES THIS ARTIFACT NEEDS. The default builds every
      # front end in the tree — fortran, go, d, ada, objc — and each is compiler
      # we neither install nor test here. C is not optional beside C++: libgcc
      # and the C++ front end are built by it.
      "--enable-languages=c,c++",

      # ⛔⛔ NO THREE-STAGE BOOTSTRAP, deliberately, and it is the decision this
      # recipe turns on. A bootstrap builds GCC with the host compiler, then
      # rebuilds it with itself twice and compares — which is how a compiler
      # proves it reproduces itself, and it triples the build. What this
      # subproject installs is the RUNTIME, not the compiler: nothing here ships
      # the xgcc that stage 3 would have produced, so the comparison would prove
      # a property of a binary that is then discarded.
      #
      # ⚠ COST, STATED: the libstdc++ shipped here is compiled by the HOST
      # compiler (clang, per #127), not by a GCC that built itself. That is a
      # real difference from a distribution's libstdc++ and the reason to say it
      # out loud rather than let `--disable-bootstrap` look like a speed choice.
      "--disable-bootstrap",

      # ⛔ ONE ARCHITECTURE'S RUNTIME. --enable-multilib would build a 32-bit
      # libstdc++ beside the 64-bit one, needing 32-bit glibc headers this tree
      # does not carry, and nothing in it asks for i686.
      "--disable-multilib",

      # ⛔ NO NATIVE LANGUAGE SUPPORT, which here is a DEPENDENCY decision and
      # not a preference: --enable-nls makes the build look for libintl, and on
      # a glibc target that resolves into libc, but on any other it pulls
      # gnu.org/gettext into a runtime library's closure.
      "--disable-nls",

      # ⭐ THE LOCALE MODEL, NAMED — and ⛔ NAMING IT IS NOT ENOUGH, which is the
      # finding below. `generic` is a stub: with it, constructing any named
      # locale other than "C"/"POSIX" throws. `gnu` is the real implementation.
      "--enable-clocale=gnu",

      # ⛔ THE DEFAULT ALLOCATOR, NAMED. acinclude.m4:3041 defaults
      # --enable-libstdcxx-allocator to `auto`, and the allocator is a property
      # every C++ program in the tree inherits. `new` is the portable choice and
      # the one a consumer can reason about.
      "--enable-libstdcxx-allocator=new",

      # ⛔ POSIX THREADS, NAMED rather than detected, because whether
      # std::thread works at all follows from it — and a libstdc++ built
      # `--enable-threads=single` compiles every threaded program and then fails
      # at run time.
      "--enable-threads=posix",

      # ⭐ C++ STATIC DESTRUCTORS RUN THROUGH __cxa_atexit, which is the ABI
      # every modern C++ implementation assumes. Without it, destructors for
      # objects in shared libraries are registered with atexit() and run in the
      # wrong order at unload.
      "--enable-__cxa_atexit",

      # ⚠ NO PRECOMPILED HEADERS IN THE ARTIFACT. They are a build-time
      # accelerator for consumers of this tree that nothing here uses, and they
      # are large: `--disable-libstdcxx-pch` keeps the installed tree to the
      # library and its headers.
      "--disable-libstdcxx-pch",
    ]
  }

  # ⛔ OUT-OF-TREE, which GCC's own INSTALL requires rather than recommends, and
  # ⛔ ONLY THE RUNTIME TARGETS. `make all` would build the whole compiler and
  # `make install` would install it; `all-target-libstdc++-v3` and
  # `all-target-libgcc` build the two libraries this member exists to provide,
  # and their `install-` counterparts install exactly those.
  #
  # ⚠ The compiler is still BUILT on the way there — libstdc++ is compiled by
  # the xgcc this tree produces, not by the host compiler — it is simply not
  # installed.
  script = [
    "mkdir -p build",
    "cd build && ../configure $ARGS",
    "cd build && make --jobs {{ hw.concurrency }} all-target-libgcc all-target-libstdc++-v3",
    "cd build && make install-target-libgcc install-target-libstdc++-v3",
  ]
}

# ⚠ NO `provides`: this subproject installs libraries and headers, no programs.
# The compiler binaries are deliberately not installed — `gnu.org/gcc` would be
# a different recipe with a different `provides`, and nothing in this tree asks
# for one yet.

test {
  script = [
    {
      run = <<EOT
ls "{{prefix}}"/lib*/libstdc++.so.6* >/dev/null
ls "{{prefix}}"/lib*/libgcc_s.so.1 >/dev/null
EOT
    },

    # ⛔⛔ THE WITNESS FOR THE FINDING, and it exists because NAMING THE VALUE
    # CANNOT FIX THIS ONE. acinclude.m4:2824-2830 re-probes `<features.h>` AFTER
    # the model has been chosen — including when the model was chosen by
    # `--enable-clocale=gnu` on the command line — and silently rewrites it to
    # `generic` unless it can see glibc >= 2.3:
    #
    #   if test $enable_clocale_flag = gnu; then
    #     AC_EGREP_CPP([_GLIBCXX_ok], [
    #     #include <features.h>
    #     #if (__GLIBC__ > 2 || (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 3)) && !defined(__UCLIBC__)
    #       _GLIBCXX_ok
    #     #endif
    #     ], enable_clocale_flag=gnu, enable_clocale_flag=generic)
    #
    # In a sovereign build those headers come from whatever glibc the sandbox
    # staged, so a sysroot that is absent or not yet installed does not fail the
    # build — it produces a libstdc++ whose std::locale cannot open a named
    # locale, and nothing in the artifact says why.
    #
    # ⭐ The model is legible in an INSTALLED file: `bits/c++locale.h` is copied
    # from config/locale/<model>/c_locale.h, and the two differ unmistakably —
    # the gnu one declares `__uselocale` (six occurrences), the generic one does
    # not mention it at all.
    {
      run = <<EOT
hdr="$(find "{{prefix}}/include" -name c++locale.h -path '*bits*' | head -1)"
if [ -z "$hdr" ]; then
  echo "libstdcxx: no bits/c++locale.h was installed" >&2
  exit 1
fi
if ! grep -q "__uselocale" "$hdr"; then
  echo "libstdcxx: the GENERIC locale model was installed, not gnu" >&2
  echo "  $hdr does not mention __uselocale." >&2
  echo "  acinclude.m4:2824-2830 re-probes <features.h> AFTER --enable-clocale=gnu" >&2
  echo "  and falls back to generic when it cannot see glibc >= 2.3, so this is" >&2
  echo "  a sysroot problem rather than a flag problem: std::locale(\"xx_YY\")" >&2
  echo "  would throw in every program linked against this library." >&2
  exit 1
fi
EOT
    },

    # ⛔⛔ IT HAS TO LINK AND IT HAS TO RUN. A C++ program that throws across a
    # shared-library boundary and catches by reference exercises the three
    # things this artifact exists to provide — the standard library, the
    # unwinder in libgcc_s, and the ABI that makes a `throw` in one translation
    # unit catchable in another. A libstdc++ that installs but whose unwinder is
    # missing passes every file check above and dies here.
    {
      run = <<EOT
cat > conftest.cc <<'SRC'
#include <stdexcept>
#include <string>
#include <iostream>
int main()
{
  try {
    throw std::runtime_error("unwound");
  } catch (const std::exception& e) {
    std::string s = e.what();
    if (s != "unwound") { std::cerr << "wrong: " << s << "\n"; return 1; }
    std::cout << "caught: " << s << "\n";
    return 0;
  }
  return 1;
}
SRC
c++ conftest.cc -I"{{prefix}}/include" -L"{{prefix}}/lib" -o conftest
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" ./conftest
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                      # :1675 gmp >= 4.2.3, :1693 mpfr >= 3.1.0, :1710 mpc >= 0.8.0 — each a `choke me`, not a web page
    "libstdc++-v3/configure.ac",         # :163-199 and :234-458, the 33 GLIBCXX_ENABLE switches this subproject has
    "libstdc++-v3/acinclude.m4",         # :2774-2830 clocale auto AND its post-hoc <features.h> downgrade; :1746-1783 libstdcxx-time's auto, keyed on target_os; :3041 allocator auto; :3207 cstdio constant
    "libstdc++-v3/config/locale/gnu/c_locale.h",     # __uselocale ×6 — the witness the test greps for
    "libstdc++-v3/config/locale/generic/c_locale.h", # zero occurrences — the other side of that boundary
    "libstdc++-v3/src/c++11/mutex.cc",   # :6-9 GPLv3-or-later, :16-18 the Runtime Library Exception 3.1
    "COPYING3",                          # the GPL v3 text that ships
    "COPYING.RUNTIME",                   # the GCC Runtime Library Exception 3.1 text that ships
    "contrib/download_prerequisites",    # :30-34, the versions GCC itself fetches when asked to
  ]

  consulted = [
    # Read for a fingerprint and a second digest path; gave NEITHER, and that is
    # why it is recorded: Arch builds gcc from a git commit with no validpgpkeys.
    "archlinux/packaging/packages/gcc PKGBUILD (pkgver, source, sha256sums)",
    # The key fingerprints, from the project itself.
    "gcc.gnu.org/mirrors.html (seven release managers' GnuPG fingerprints)",
    # Why this member is in the set at all, and the cycle it sits in.
    "go-zpkg/recipes projects/go-zpkg/base-toolchain/package.hcl:120-128",
  ]

  note = <<EOT
⛔⛔ THE FINDING: A SILENT DOWNGRADE OF std::locale, DECIDED BY WHETHER
CONFIGURE CAN SEE glibc's HEADERS — and it is the first one in this campaign
that NAMING THE VALUE DOES NOT FIX.

libstdc++-v3/acinclude.m4:2774 defaults `--enable-clocale` to `auto`, and the
auto branch keys on target_os, which for linux chooses `gnu`. That part is
deterministic. But :2824-2830 then re-checks, and the check runs whether the
model was chosen by the default or named on the command line:

  if test $enable_clocale_flag = gnu; then
    AC_EGREP_CPP([_GLIBCXX_ok], [
    #include <features.h>
    #if (__GLIBC__ > 2 || (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 3)) && !defined(__UCLIBC__)
      _GLIBCXX_ok
    #endif
    ], enable_clocale_flag=gnu, enable_clocale_flag=generic)

`generic` is a stub implementation: constructing any named locale other than
"C" or "POSIX" throws. So a sysroot that configure cannot read produces a
libstdc++ that builds cleanly, installs cleanly, links cleanly, and then throws
in every program that asks for a locale — with nothing in the artifact recording
which model it got.

Every earlier finding in this campaign was fixable by naming a value: mpfr's
--enable-float128, mpc's gmp.h compiler extraction, glibc's --enable-cet, gmp's
CPU tuning. This one is not, because the project overrides the named value
afterwards. The only way to make the outcome a STATED property of the artifact
is to assert it, which the test block does on an installed file:
`bits/c++locale.h` is the model-specific header, and the gnu one declares
`__uselocale` where the generic one never mentions it.

⭐ A MEASURED NEGATIVE THAT LOOKED IDENTICAL FROM OUTSIDE, and keeping it is the
point: `--enable-libstdcxx-time` is ALSO `auto` (acinclude.m4:1748), and it is
NOT this class. Its auto branch is a `case "$${target_os}"` with no probe of the
build machine at all (:1765-1783) — linux takes one arm, darwin another — so it
is reproducible for a given target and naming it would add a flag that changes
nothing. Two switches, both `auto`, and only one of them is a defect: the
difference is whether the decision reads the TARGET or the BUILD HOST, and it
cost reading both macro bodies to tell them apart.

⭐ THE TRUST CHAIN IS THE BEST OF THE CAMPAIGN, because the fingerprint is
published by the project itself. gcc.gnu.org/mirrors.html lists seven release
managers with full fingerprints; the signature on gcc-14.4.0.tar.xz names the
`4096R/09B5FA62` one (Jakub Jelinek) by 64-bit key id, and sourcepin VERIFIES
it. gmp, mpfr and mpc all had to borrow their fingerprint from Arch; glibc and
automake had no third party at all.

⚠ Two obstacles worth recording because they will recur. The signature carries
only a key ID, which is a weak selector on its own — the published fingerprint
is what makes it meaningful, so `--fingerprint` is load-bearing here. And
ftp.gnu.org's gnu-keyring.gpg cannot be read whole: it stops after 402 primary
keys on `Cannot have multiple embedded signatures`, and this key is past that
point. `keyringscan -extract` pulled it out verbatim; a reader that stopped at
the truncation would have called the key ABSENT, which is a different claim from
"not there".

⚠ ONLY TWO DIGEST PATHS. Arch's gcc PKGBUILD builds from a git commit
(16.2.1+r23+gd564253eb6c8) and carries no validpgpkeys, so it corroborates
neither these bytes nor this key — unlike mpc, where Arch pinned the same
tarball.

⛔⛔ AND THE BOOTSTRAP CYCLE IS REAL, stated so the next reader does not treat
this recipe as a straightforward build. base-toolchain declares this member
because the MIRRORED llvm.org artifact's clang cannot start without
libstdc++.so.6 in a tree with no distribution — measured in a container on
2026-08-27 — while libstdc++ cannot be built apart from GCC and GCC needs a C++
compiler. The factory's `--bootstrap` is the documented entry point: the first
fill takes its tools from the host, and every later build uses the artifact that
fill produced. Nothing here can close that cycle from inside the set, and a
recipe that pretended otherwise would be wrong rather than incomplete.

⚠ NOT BUILT, and for this one the gap is wider than for its siblings. No session
here runs the factory, and this is a compiler build. What is established is the
recipe's INPUTS: the three dependency floors traced to `choke me` blocks in
GCC's own configure.ac, the licence read from libstdc++'s own source including
the exception that makes `GPL-3.0-or-later` alone a misstatement, the two
`auto` switches read far enough into their macro bodies to tell a host probe
from a target case, the installed set, and a verified signature. The test block
asserts the two libraries exist, that the gnu locale model survived, and that a
C++ exception thrown and caught across the library actually unwinds.
EOT
}
