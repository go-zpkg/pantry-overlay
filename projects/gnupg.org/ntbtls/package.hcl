# ntbtls — GnuPG's own TLS library, the one dirmngr uses to speak HTTPS and
# LDAPS without GnuTLS.
#
# WRITTEN FROM THE PROJECT'S OWN FILES at 0.3.2 (go-zpkg/packages#440). There
# was no recipe; gnupg.org names it as the TLS library for dirmngr.

summary = "GnuPG's TLS library (the alternative to GnuTLS in dirmngr)"

# src/ntbtls.h.in:18 "SPDX-License-Identifier: GPL-3.0-or-later" (and :7-9
# says GPL version 3 or later). Unlike the other libraries of this family it
# is a GPL library, not an LGPL one.
license = "GPL-3.0-or-later"

versions {
  url   = "https://gnupg.org/ftp/gcrypt/ntbtls/"
  match = "/ntbtls-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^ntbtls-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://gnupg.org/ftp/gcrypt/ntbtls/ntbtls-{{version.raw}}.tar.bz2"
  strip-components = 1

  # `versions` resolves 0.3.2 as the newest. Fetched with `zpkb sourcepin`
  # (373932 bytes); the detached signature verified against the key file
  # gnupg.org links from its signature page, no keyserver:
  #
  #   signed by  6DAA6E64A76D2840571B4902528897B826403ADA
  #              Werner Koch (dist signing 2020)
  #   key file   https://gnupg.org/signature_key.asc
  #   fprs from  https://gnupg.org/signature_key.html
  #   signature  https://gnupg.org/ftp/gcrypt/ntbtls/ntbtls-0.3.2.tar.bz2.sig
  #
  # Checked when the digest was recorded, not at every build.
  sha256 = {
    "0.3.2" = "bdfcb99024acec9c6c4b998ad63bb3921df4cfee4a772ad6c0ca324dbbf2b07c"
  }
}

build {
  dependencies = {
    # configure.ac:64-70 NEED_GPG_ERROR_VERSION=1.25, NEED_LIBGCRYPT_API=1 with
    # 1.8.0, NEED_KSBA_API=1 with 1.2.0. All three are mandatory: :261, :272
    # and :279 are AM_PATH_* probes whose failure ends in the errors at
    # :668-688.
    "gnupg.org/libgpg-error" = "^1"
    "gnupg.org/libgcrypt"    = "^1"
    "gnupg.org/libksba"      = "^1"

    # configure.ac:86 use_zip=yes is fixed, and :479-497 then looks for
    # zlib.h and -lz with no switch to stop it: zlib is an unconditional
    # input, so it is named, and its prefix is handed to --with-zlib (:482).
    "zlib.net" = "^1"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # Naming the staged prefixes stops the probes finding host copies
      # (m4/gpg-error.m4:25, m4/libgcrypt.m4:33, m4/ksba.m4:30).
      "--with-libgpg-error-prefix={{deps.gnupg.org/libgpg-error.prefix}}",
      "--with-libgcrypt-prefix={{deps.gnupg.org/libgcrypt.prefix}}",
      "--with-libksba-prefix={{deps.gnupg.org/libksba.prefix}}",
      "--with-zlib={{deps.zlib.net.prefix}}",
    ]
  }

  # configure.ac has no other AC_ARG_ENABLE/WITH that reads the host: :326
  # ld-version-script, :342 libtool-modification, :372 endian-check, :600
  # optimization and :639 build-timestamp are all about how the library itself
  # is built. src/Makefile.am:33 ntbtls-cli is noinst_PROGRAMS, so it is not
  # installed.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:26-30: ntbtls-config is noinst under gpgrt-config (which
# libgpg-error provides) and bin otherwise. A library only, no `provides`.

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/ntbtls.h",
    "test -f {{prefix}}/lib/pkgconfig/ntbtls.pc",
    "pkg-config --exists ntbtls",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <ntbtls.h>

int main(void) {
  /* header and library must agree, or a system copy was linked */
  const char *v = ntbtls_check_version(NTBTLS_VERSION);
  if (!v) {
    puts("library older than header");
    return 1;
  }
  printf("ntbtls %s\n", v);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o check $(pkg-config --cflags --libs ntbtls)"
    },
    "./check",
  ]
}

provenance {
  read = [
    "configure.ac",     # :64-70 NEED_*; :86 use_zip=yes; :261 AM_PATH_GPG_ERROR; :272 AM_PATH_LIBGCRYPT; :279 AM_PATH_KSBA; :482-497 zlib probe
    "src/Makefile.am",  # :22 ntbtls.pc; :26-30 ntbtls-config; :32-33 library and noinst ntbtls-cli
    "src/ntbtls.h.in",  # :18 SPDX GPL-3.0-or-later; :44 NTBTLS_VERSION; :93 ntbtls_check_version
    "m4/gpg-error.m4",  # :25 --with-libgpg-error-prefix
    "m4/libgcrypt.m4",  # :33 --with-libgcrypt-prefix
    "m4/ksba.m4",       # :30 --with-libksba-prefix
    "https://gnupg.org/signature_key.html",
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the source and checked by `zpkb lint` and `zpkb
versions` only; the fixture's API names were read from src/ntbtls.h.in.
EOT
}
