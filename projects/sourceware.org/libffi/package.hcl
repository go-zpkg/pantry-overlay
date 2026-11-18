# sourceware.org/libffi — the foreign function interface library, which 5
# recipes in this tree name.
#
# ⛔ WRITTEN FROM LIBFFI'S OWN FILES (go-zpkg/packages#431), at 3.8.1. Ninth of
# the twenty-two in go-zpkg/recipes#143, after openssl.org (#145), zstd (#146),
# bzip2 (#147), libexpat (#148), libxml2 (#149, corrected by #150),
# pcre.org/v2 (#151), invisible-island.net/ncurses (#152) and gnu.org/readline
# (#153).
#
# ⚠ THE PANTRY'S RECIPE IS THREE LINES — `./configure --prefix --disable-debug`
# — so almost nothing about this project had been examined. The two findings
# below are both in that gap.

summary = "libffi: calling functions whose signature is known only at run time"

# Read from `LICENSE`: the MIT text, headed "libffi - Copyright (c) 1996-2026
# Anthony Green, Red Hat, Inc and others." ⚠ Its second line, "See source files
# for details", points at per-file notices rather than at another licence; the
# expression stays one identifier.
license = "MIT"

versions {
  github = "libffi/libffi/tags"
  strip  = ["/^v/"]
}

distributable {
  url              = "https://github.com/libffi/libffi/releases/download/v{{version.raw}}/libffi-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1650946 bytes, measured on the fetched asset.
  sha256 = {
    "3.8.1" = "81e879c094cc5ec3186c48510c6385ac6b3e866192e8bc71a35245703757ee40"
  }

  # ⛔⛔ THE WEAKEST PROVENANCE OF THE NINE, AND THE ONLY ONE WHERE THE TARBALL
  # CARRIES NO STATEMENT AT ALL. Measured, not assumed:
  #
  #   release assets   libffi-3.8.1.tar.gz and three MSVC binary zips.
  #                    NO .sig, NO .asc, NO .sha256 — nothing beside it.
  #   attestation      `gh attestation verify --repo libffi/libffi` answers
  #                    HTTP 404: there is none.
  #   release body     3377 bytes of release notes, naming no digest.
  #
  # So below gnome.org/libxml2 (#149), which at least publishes its own
  # SHA-256 beside the tarball: here nothing upstream says what these bytes
  # should be, and the pin below is OUR statement about what we fetched.
  #
  # ⭐ WHAT IS SIGNED IS THE TAG, AND ITS KEY IS REACHABLE — which is worth
  # stating because it is the one cryptographic fact available. The v3.8.1 tag
  # object (a09b362) carries a signature by
  # 2FE877C62789281A9FFE08DA146B940EEB360EBA, and `users/atgreen/gpg_keys`
  # publishes exactly `146B940EEB360EBA` — the same key, from the maintainer's
  # own account.
  #
  # ⚠ GitHub reports that tag `"verified": false`, and the reason matters:
  # `bad_email`, NOT `unknown_key`. The tagger used green@moxielogic.com while
  # the key's verified GitHub address is green@redhat.com. The signature is
  # sound; only the address binding is not. (Contrast pcre.org/v2 (#151), where
  # the reason IS `unknown_key` and the signing key is unreachable.)
  #
  # ⛔ AND THE TAG'S SIGNATURE DOES NOT COVER THESE BYTES. This tarball is an
  # UPLOADED asset, not GitHub's generated source archive, and an autotools
  # `make dist` adds files no git tree holds. So the chain stops at the tag:
  # nothing ties the published tarball to it, and no amount of reading makes
  # that gap smaller than it is.
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ LIBFFI TUNES ITSELF TO THE BUILD MACHINE'S CPU, AND FIVE RECIPES
      # HERE LINK IT. configure:19801-19808 defaults `ax_gcc_arch=yes`, and
      # :19824-20145 then read the BUILDER'S CPUID through a table that maps it
      # to a -march value — :19962-19974 alone names pentium, pentium2,
      # pentium3, pentium-m, yonah, core2, penryn, nehalem, westmere,
      # sandybridge, ivybridge, and the table continues. :20155 then builds the
      # flag list as `-march= -mcpu= -m`.
      #
      # A library built on one runner therefore carries instructions the next
      # machine may not have, and the failure is a SIGILL at the call site —
      # from a package that installed cleanly.
      #
      # ⚠ ITS REACHABILITY IS CONDITIONAL, AND SAYING SO IS THE POINT: :19395
      # guards the whole block with `if test "x$ac_test_CFLAGS" = "x"`, so it
      # runs only when CFLAGS was NOT set in the environment. That makes the
      # defect depend on the sandbox as well as on the hardware — two unknowns
      # rather than one, which is worse and not better.
      #
      # ⭐ `--with-gcc-arch=no` IS THE COMPLETE ANSWER, and it was chosen over
      # `--enable-portable-binary` after reading both. :20147 skips the entire
      # flag selection when `ax_gcc_arch` is `no`, on every compiler and
      # whatever CFLAGS holds. `--enable-portable-binary` only switches the
      # prefix list to `-mtune=` (:20148-20149) — and :20150 then puts `-march=`
      # back for clang, which is exactly the non-portable case it claims to
      # prevent.
      "--with-gcc-arch=no",

      # ⛔ AND WHERE THE LIBRARY LANDS IS DECIDED BY THE COMPILER.
      # configure:21536-21541: unless this is disabled, libffi runs
      # `$CC $CFLAGS -print-multi-os-directory` and appends the answer to
      # `toolexeclibdir`. A gcc configured for multilib answers `../lib64`, and
      # the library installs into {{prefix}}/lib64 — a path the five consumers
      # do not look in. Disabling it pins the layout to {{prefix}}/lib.
      "--disable-multi-os-directory",

      # Documentation is ON by default (configure:21388 `enable_docs=yes`) and
      # needs makeinfo. Nothing here reads libffi's manual.
      "--disable-docs",

      # `--disable-debug` states the default rather than changing it: there is
      # no `enable_debug=` assignment in the generated script at all, so the
      # variable is empty and its consumers test for "yes". Named for the same
      # reason gnome.org/libxml2 names `--without-python` (#150) — a default
      # this recipe does not control.
      "--disable-debug",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`, AND THAT IS NOT AN OMISSION. libffi installs no programs:
# Makefile.am has no `bin_PROGRAMS` and no `bin_SCRIPTS` — measured, with
# `lib_LTLIBRARIES` matching once as the control. The pantry's recipe names none
# either, and this is the one place the two agree by construction.

test {
  script = [
    "test -f \"{{prefix}}/include/ffi.h\"",

    # ⛔⛔ THE REGRESSION TEST FOR `--disable-multi-os-directory`. If the flag is
    # dropped on a multilib compiler the build still succeeds and the library
    # lands in lib64, where nothing here looks. Asserted on the installed tree,
    # including the absence of the wrong directory.
    {
      run = <<EOT
set -eu
ls "{{prefix}}"/lib/libffi.* >/dev/null 2>&1 \
  || { echo "libffi is not in {{prefix}}/lib — --disable-multi-os-directory was dropped" >&2; exit 1; }
if ls "{{prefix}}"/lib64/libffi.* >/dev/null 2>&1; then
  echo "libffi also installed into lib64 — the compiler's multi-os directory was honoured" >&2
  exit 1
fi
test -f "{{prefix}}/lib/pkgconfig/libffi.pc"
EOT
    },

    # ⭐ AND IT HAS TO CALL SOMETHING. libffi's whole purpose is building a call
    # at run time from a signature, so the test does that rather than checking
    # that a file exists.
    {
      run = <<EOT
set -eu
cat > probe.c <<'CEOF'
#include <stdio.h>
#include <ffi.h>
static long add(long a, long b) { return a + b; }
int main(void) {
  ffi_cif cif;
  ffi_type *args[2] = { &ffi_type_slong, &ffi_type_slong };
  if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, &ffi_type_slong, args) != FFI_OK) return 1;
  long a = 17, b = 25, r = 0;
  void *values[2] = { &a, &b };
  ffi_call(&cif, FFI_FN(add), &r, values);
  printf("%ld\n", r);
  return r == 42 ? 0 : 1;
}
CEOF
cc probe.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lffi -o probe
./probe > out.txt
grep -q '^42$' out.txt
EOT
    },
  ]
}

provenance {
  read = [
    "LICENSE",     # the MIT text; "See source files for details" points at per-file notices, not another licence
    "Makefile.am", # no bin_PROGRAMS and no bin_SCRIPTS, with lib_LTLIBRARIES as the control — why `provides` is absent
    "configure",   # the GENERATED script: :19384-19391 --enable-portable-binary defaults `no`; :19395 the WHOLE tuning block is guarded on CFLAGS being unset; :19801-19808 --with-gcc-arch defaults `yes`; :19824-20145 the CPUID→-march table, :19962-19974 its x86 rows; :20147 the skip when ax_gcc_arch is `no`; :20148-20150 portable mode uses -mtune= except on clang, where it is -march= again; :21388 docs default yes; :21505-21541 the multi-os directory probe that calls $CC -print-multi-os-directory
  ]

  consulted = [
    "pkgxdev/pantry projects/sourceware.org/libffi/package.yml", # read deliberately: three lines, which is what made the two findings above findable
    "github.com/libffi/libffi releases/tag/v3.8.1",              # the assets, the release body and the signed tag object
  ]

  note = <<EOT
⛔⛔ LIBFFI TUNES ITSELF TO THE BUILD MACHINE'S CPU, AND FIVE RECIPES HERE LINK
IT. configure:19801-19808 defaults `ax_gcc_arch=yes`, and :19824-20145 then read
the BUILDER'S CPUID through a table mapping it to a -march value — :19962-19974
alone names pentium through ivybridge, and the table continues. :20155 builds
the flag list as `-march= -mcpu= -m`. A library built on one runner carries
instructions the next machine may not have, and the failure is a SIGILL at the
call site, from a package that installed cleanly.

⚠ ITS REACHABILITY IS CONDITIONAL AND THAT IS WORSE, NOT BETTER. :19395 guards
the block with `if test "x$ac_test_CFLAGS" = "x"`, so it runs only when CFLAGS
was not set in the environment — the artifact then depends on the sandbox AND on
the hardware, two unknowns instead of one.

⭐ `--with-gcc-arch=no` WAS CHOSEN OVER `--enable-portable-binary` AFTER READING
BOTH, which is the kind of choice this campaign exists to make. :20147 skips the
entire flag selection when ax_gcc_arch is `no`, on every compiler and whatever
CFLAGS holds. `--enable-portable-binary` only switches the prefix list to
`-mtune=` (:20148-20149) — and :20150 puts `-march=` back for clang, which is
the non-portable case it claims to prevent. The weaker flag looks like the
answer because of its name.

⛔ AND WHERE THE LIBRARY LANDS IS DECIDED BY THE COMPILER. configure:21536-21541
runs `$CC $CFLAGS -print-multi-os-directory` and appends the answer to
toolexeclibdir unless --disable-multi-os-directory is given. A multilib gcc
answers `../lib64` and the library installs into {{prefix}}/lib64, where the
five consumers do not look. The test asserts both halves: libffi present in
lib, and ABSENT from lib64.

⛔⛔ THE WEAKEST PROVENANCE OF THE NINE, and the only one where the tarball
carries no statement at all. The release ships the tarball and three MSVC zips
and NOTHING beside them — no .sig, no .asc, no .sha256; `gh attestation verify`
answers HTTP 404; the 3377-byte release body names no digest. That is below
gnome.org/libxml2 (#149), which at least publishes its own SHA-256.

⭐ What IS signed is the TAG, and its key is reachable: the v3.8.1 tag object
(a09b362) is signed by 2FE877C62789281A9FFE08DA146B940EEB360EBA, and
`users/atgreen/gpg_keys` publishes exactly 146B940EEB360EBA — the maintainer's
own account. ⚠ GitHub reports that tag "verified": false for the reason
`bad_email`, NOT `unknown_key`: the tagger used green@moxielogic.com while the
key's verified address is green@redhat.com. The signature is sound; the address
binding is not. Contrast pcre.org/v2 (#151), where the reason IS `unknown_key`.

⛔ AND THE TAG'S SIGNATURE DOES NOT COVER THESE BYTES. The tarball is an
UPLOADED asset, not GitHub's generated archive, and `make dist` adds files no
git tree holds. The chain stops at the tag, and no amount of reading makes that
gap smaller than it is.

⚠ NOT BUILT. Measured here: the digest, the absence of every upstream integrity
statement with the commands that looked, the tag signature and its key, the
switch census (`acdefault`: 3 of 18 documented switches examined, 15 walked
past), and `zpkb lint`. The scripts are a claim about libffi's build system read
from that build system, and they stay a claim until a factory runs them.
EOT
}
