# libksba — X.509 certificates, CMS and the ASN.1 plumbing under them.
#
# WRITTEN FROM THE PROJECT'S OWN FILES at 1.9.1 (go-zpkg/packages#440). There
# was no recipe; gnupg.org and gnupg.org/v2.5 name it as a dependency.

summary = "X.509 and CMS library used by GnuPG's S/MIME support"

# src/ksba.h.in:9-29 offers the library under two licences at once, and :29 is
# "SPDX-License-Identifier: LGPL-3.0-or-later OR GPL-2.0-or-later".
license = "LGPL-3.0-or-later OR GPL-2.0-or-later"

versions {
  url   = "https://gnupg.org/ftp/gcrypt/libksba/"
  match = "/libksba-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^libksba-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://gnupg.org/ftp/gcrypt/libksba/libksba-{{version.raw}}.tar.bz2"
  strip-components = 1

  # `versions` resolves 1.9.1 as the newest. Fetched with `zpkb sourcepin`
  # (767904 bytes); the detached signature verified against the key file
  # gnupg.org links from its signature page, no keyserver:
  #
  #   signed by  6DAA6E64A76D2840571B4902528897B826403ADA
  #              Werner Koch (dist signing 2020)
  #   key file   https://gnupg.org/signature_key.asc
  #   fprs from  https://gnupg.org/signature_key.html
  #   signature  https://gnupg.org/ftp/gcrypt/libksba/libksba-1.9.1.tar.bz2.sig
  #
  # Checked when the digest was recorded, not at every build.
  sha256 = {
    "1.9.1" = "9afdd398b4a076735e1e7fd29c7f6e7670b6c382aee2d3a55aa937b283f43e5b"
  }
}

build {
  dependencies = {
    "gnupg.org/libgpg-error" = "^1"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # configure.ac:408 is AM_PATH_GPG_ERROR("$NEED_GPG_ERROR_VERSION"), with
      # NEED_GPG_ERROR_VERSION=1.28 (:61): mandatory, and the only external
      # package the configure script looks for. Naming the staged prefix stops
      # it finding a host copy.
      "--with-libgpg-error-prefix={{deps.gnupg.org/libgpg-error.prefix}}",

      # configure.ac:484 builds the manual with makeinfo unless disabled.
      "--disable-doc",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:32-34: ksba-config is noinst when gpgrt-config is used and
# bin otherwise. libgpg-error installs gpgrt-config, so it is not installed
# here: a library only, no `provides`.

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/ksba.h",
    "test -f {{prefix}}/lib/pkgconfig/ksba.pc",
    "pkg-config --exists ksba",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <ksba.h>

int main(void) {
  /* header and library must agree, or a system copy was linked */
  const char *v = ksba_check_version(KSBA_VERSION);
  if (!v) {
    puts("library older than header");
    return 1;
  }
  ksba_cert_t cert;
  gpg_error_t err = ksba_cert_new(&cert);
  if (err) {
    printf("ksba_cert_new failed: %s\n", gpg_strerror(err));
    return 1;
  }
  ksba_cert_release(cert);
  printf("libksba %s\n", v);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o check $(pkg-config --cflags --libs ksba)"
    },
    "./check",
  ]
}

provenance {
  read = [
    "configure.ac",     # :61 NEED_GPG_ERROR_VERSION=1.28; :408 AM_PATH_GPG_ERROR; :484 doc; :417 USE_GPGRT_CONFIG
    "src/Makefile.am",  # :32-37 ksba-config and the library
    "src/ksba.h.in",    # :9-29 dual licence; :48 KSBA_VERSION; :332-334 ksba_cert_new/release; :731 ksba_check_version
    "https://gnupg.org/signature_key.html",
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the source and checked by `zpkb lint` and `zpkb
versions` only; the fixture's API names were read from src/ksba.h.in.
EOT
}
