# gpgme — GnuPG Made Easy: the C library applications use to drive gpg, gpgsm
# and gpgconf.
#
# WRITTEN FROM THE PROJECT'S OWN FILES at 2.3.1 (go-zpkg/packages#440). It was
# a fragment declaring two dependency edges.
#
# gpgme runs the GnuPG programs at RUN time, through PATH and gpgconf; nothing
# in configure.ac links against GnuPG, so this recipe does not depend on
# gnupg.org (which would also make a cycle for anything that wants both).
#
# THE BINDINGS ARE SEPARATE TARBALLS (C++ gpgmepp, Qt qgpgme, Python gpgmepy
# on https://gnupg.org/ftp/gcrypt/) and are not built here. The Common Lisp
# binding is the only one this tarball carries.

summary = "GnuPG Made Easy: C library for applications that use GnuPG"

# src/gpgme.h.in:19 "SPDX-License-Identifier: LGPL-2.1-or-later". The programs
# gpgme-tool and gpgme-json are under their own headers; COPYING (GPL) and
# COPYING.LESSER both ship.
license = "LGPL-2.1-or-later"

versions {
  url   = "https://gnupg.org/ftp/gcrypt/gpgme/"
  match = "/gpgme-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^gpgme-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://gnupg.org/ftp/gcrypt/gpgme/gpgme-{{version.raw}}.tar.bz2"
  strip-components = 1

  # `versions` resolves 2.3.1 as the newest. Fetched with `zpkb sourcepin`
  # (1427150 bytes); the detached signature verified against the key file
  # gnupg.org links from its signature page, no keyserver:
  #
  #   signed by  6DAA6E64A76D2840571B4902528897B826403ADA
  #              Werner Koch (dist signing 2020)
  #   key file   https://gnupg.org/signature_key.asc
  #   fprs from  https://gnupg.org/signature_key.html
  #   signature  https://gnupg.org/ftp/gcrypt/gpgme/gpgme-2.3.1.tar.bz2.sig
  #
  # Checked when the digest was recorded, not at every build.
  sha256 = {
    "2.3.1" = "2bf94e0e677e5a8fc31f79dd323f91c5416b36fb851058bc1e8bce39f2642434"
  }
}

build {
  dependencies = {
    # configure.ac:72-73 NEED_LIBASSUAN_API=2, NEED_LIBASSUAN_VERSION=2.4.2:
    # gpgme 2.3.1 asks for the 2 API line, and libassuan 3.x is API 3, so
    # `^2` is the constraint, not `*`.
    "gnupg.org/libassuan"    = "^2"
    "gnupg.org/libgpg-error" = "^1"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # configure.ac:586 AM_PATH_GPG_ERROR("1.47") and :596 AM_PATH_LIBASSUAN
      # are both required. Naming the staged prefixes stops the probes finding
      # host copies (m4/gpg-error.m4:24, m4/libassuan.m4:106).
      "--with-libgpg-error-prefix={{deps.gnupg.org/libgpg-error.prefix}}",
      "--with-libassuan-prefix={{deps.gnupg.org/libassuan.prefix}}",

      # configure.ac:329-348: the only available language is `cl`, and the
      # default is to build it ("maybe"). A Lisp ASDF file is not something a
      # C library package should install unasked.
      "--disable-languages",

      # configure.ac:397-418: these four switches only decide which regression
      # tests run, and the tests need a gpg that is not a dependency here.
      "--disable-gpgconf-test",
      "--disable-gpg-test",
      "--disable-gpgsm-test",
      "--disable-g13-test",
    ]
  }

  # Left at their defaults: :657 fd-passing (default yes) and so the uiserver
  # (:673-681) depend on struct cmsghdr and libassuan, both fixed by the
  # platform and the declared dependency. :317 fixed-path is empty, so gpg is
  # found through PATH at run time.
  #
  # doc/ ships gpgme.info prebuilt, so no makeinfo is needed; yat2m is probed
  # with a fallback of ":" (configure.ac:90), so man pages are skipped when it
  # is absent.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:38 bin_PROGRAMS = gpgme-tool gpgme-json; :29-33 gpgme-config
# is noinst under gpgrt-config.
provides = [
  "bin/gpgme-tool",
  "bin/gpgme-json",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/gpgme.h",
    "test -f {{prefix}}/lib/pkgconfig/gpgme.pc",
    "pkg-config --exists gpgme",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <gpgme.h>

int main(void) {
  /* must be called first; also checks header against library */
  const char *v = gpgme_check_version(GPGME_VERSION);
  if (!v || strcmp(v, GPGME_VERSION) != 0) {
    puts("library does not match header");
    return 1;
  }
  gpgme_ctx_t ctx;
  gpgme_error_t err = gpgme_new(&ctx);
  if (err) {
    printf("gpgme_new failed: %s\n", gpgme_strerror(err));
    return 1;
  }
  gpgme_release(ctx);
  printf("gpgme %s\n", v);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o check $(pkg-config --cflags --libs gpgme)"
    },
    "./check",
  ]
}

provenance {
  read = [
    "configure.ac",     # :71-73 NEED_*; :90 yat2m; :245-246 languages; :317 fixed-path; :329-348 enable-languages; :397-418 test switches; :586 AM_PATH_GPG_ERROR; :596 AM_PATH_LIBASSUAN; :657 fd-passing
    "src/Makefile.am",  # :29-38 gpgme-config, headers, bin_PROGRAMS
    "src/gpgme.h.in",   # :19 SPDX; :45 GPGME_VERSION; :2576 gpgme_check_version
    "src/gpgme.pc.in",  # :10 Requires.private gpg-error, libassuan
    "doc/Makefile.am",  # :34-42 yat2m guard, info_TEXINFOS = gpgme.texi
    "https://gnupg.org/signature_key.html",
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the source and checked by `zpkb lint` and `zpkb
versions` only. The libassuan `^2` constraint is read from configure.ac; it
was not tried against a staged libassuan 3.
EOT
}
