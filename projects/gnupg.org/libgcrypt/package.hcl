# libgcrypt — GnuPG's general purpose cryptographic library.
#
# WRITTEN FROM THE PROJECT'S OWN FILES at 1.12.4 (go-zpkg/packages#440). There
# was no recipe at all; gnupg.org and gnupg.org/v2.5 named it as a dependency.

summary = "General purpose cryptographic library from the GnuPG project"

# README:273-279 says library LGPL and helper programs GPL, but that text is
# older than the sources: src/gcrypt.h.in:20 is "SPDX-License-Identifier:
# LGPL-2.1-or-later", and the helper programs say the same in their own
# --version text (src/mpicalc.c:378 "License LGPLv2.1+", src/hmac256.c:693).
# The files, not the README, decide.
license = "LGPL-2.1-or-later"

versions {
  url   = "https://gnupg.org/ftp/gcrypt/libgcrypt/"
  match = "/libgcrypt-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^libgcrypt-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-{{version.raw}}.tar.bz2"
  strip-components = 1

  # `versions` resolves 1.12.4 as the newest. Fetched with `zpkb sourcepin`
  # (4473329 bytes); the detached signature verified against the key file
  # gnupg.org links from its signature page, no keyserver:
  #
  #   signed by  6DAA6E64A76D2840571B4902528897B826403ADA
  #              Werner Koch (dist signing 2020)
  #   key file   https://gnupg.org/signature_key.asc
  #   fprs from  https://gnupg.org/signature_key.html
  #   signature  https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.12.4.tar.bz2.sig
  #
  # Checked when the digest was recorded, not at every build.
  sha256 = {
    "1.12.4" = "d77f68f48879510e79a2f65977ccc68981781ea0923e5bdffac2a193ea3d660e"
  }
}

build {
  dependencies = {
    "gnupg.org/libgpg-error" = "^1"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # configure.ac:830 is AM_PATH_GPG_ERROR("$NEED_GPG_ERROR_VERSION") with
      # NEED_GPG_ERROR_VERSION=1.56 (:77): mandatory. Naming the staged prefix
      # stops the probe finding a host copy.
      "--with-libgpg-error-prefix={{deps.gnupg.org/libgpg-error.prefix}}",

      # configure.ac:4431 builds the manual with makeinfo unless disabled.
      "--disable-doc",

      # Optional behaviours that read the HOST, each named so none is left to
      # detection:
      #   :563 --with-capabilities   default no (Linux libcap), stated anyway
      #   :571 --enable-hmac-binary-check  default no; it needs objcopy and
      #        readelf and is a FIPS feature
      "--without-capabilities",
      "--disable-hmac-binary-check",
    ]
  }

  # Left at their defaults on purpose, because none reads an external package:
  #   :601 jent-support (default yes) is the bundled random/jitterentropy
  #   :531 asm and :609-:713 the *-support switches select the library's OWN
  #        assembly by CPU architecture and assembler, not by host libraries
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:39 bin_PROGRAMS = dumpsexp hmac256 mpicalc; libgcrypt-config
# is noinst when gpgrt-config is used (:30-32), which libgpg-error provides.
provides = [
  "bin/dumpsexp",
  "bin/hmac256",
  "bin/mpicalc",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "hmac256 --version",
    "mpicalc --version",
    "test -f {{prefix}}/include/gcrypt.h",
    "test -f {{prefix}}/lib/pkgconfig/libgcrypt.pc",
    "pkg-config --exists libgcrypt",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <gcrypt.h>

int main(void) {
  /* header and library must agree, or a system copy was linked */
  const char *v = gcry_check_version(GCRYPT_VERSION);
  if (!v) {
    puts("library older than header");
    return 1;
  }

  /* FIPS 180-2 test vector: SHA-256("abc") */
  static const unsigned char want[32] = {
    0xba,0x78,0x16,0xbf,0x8f,0x01,0xcf,0xea,0x41,0x41,0x40,0xde,0x5d,0xae,0x22,0x23,
    0xb0,0x03,0x61,0xa3,0x96,0x17,0x7a,0x9c,0xb4,0x10,0xff,0x61,0xf2,0x00,0x15,0xad
  };
  unsigned char got[32];
  gcry_md_hash_buffer(GCRY_MD_SHA256, got, "abc", 3);
  if (memcmp(got, want, 32) != 0) {
    puts("SHA-256(abc) mismatch");
    return 1;
  }
  printf("libgcrypt %s: SHA-256(abc) ok\n", v);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o check $(pkg-config --cflags --libs libgcrypt)"
    },
    "./check",
  ]
}

provenance {
  read = [
    "README",           # :273-279 licence text, superseded by the file headers
    "configure.ac",     # :77 NEED_GPG_ERROR_VERSION=1.56; :531 asm; :563 capabilities; :571 hmac-binary-check; :601 jent-support; :830 AM_PATH_GPG_ERROR; :839 USE_GPGRT_CONFIG; :4431 doc
    "src/Makefile.am",  # :30-39 libgcrypt-config, m4 data, bin_PROGRAMS
    "src/gcrypt.h.in",  # :20 SPDX LGPL-2.1-or-later; :59 GCRYPT_VERSION; :261 gcry_check_version; :1398 gcry_md_hash_buffer
    "src/libgcrypt.pc.in", # :13 Requires.private gpg-error
    "https://gnupg.org/signature_key.html",
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the source and checked by `zpkb lint` and `zpkb
versions` only; the fixture's API names were read from src/gcrypt.h.in.
EOT
}
