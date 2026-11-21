# libassuan — the IPC library GnuPG, gpg-agent, dirmngr and GPGME speak through.
#
# WRITTEN FROM THE PROJECT'S OWN FILES at 3.0.2 and 2.5.7 (go-zpkg/packages#440).
# It was a fragment declaring one dependency edge.
#
# TWO API LINES LIVE UNDER ONE NAME, AND BOTH ARE PINNED. configure.ac sets
# LIBASSUAN_CONFIG_API_VERSION=3 at 3.0.2 (:71) and =2 at 2.5.7 (:69), and
# consumers ask for a line: gpgme 2.3.1 has NEED_LIBASSUAN_API=2 (configure.ac:72)
# and gnupg 2.4.9 has NEED_LIBASSUAN_API=2 (:63), while gnupg 2.5.24 has
# NEED_LIBASSUAN_API=3 (:65). So `^2` and `^3` must both resolve to a digested
# release; pinning only the newest would leave 2.5.7 fetched unpinned.

summary = "IPC library used by GnuPG, gpg-agent and GPGME"

# README:11-13: the software is LGPLv2.1+ (COPYING.LIB), the documentation
# GPLv3+ (COPYING). The documentation is not installed (--disable-doc below).
license = "LGPL-2.1-or-later"

versions {
  url   = "https://gnupg.org/ftp/gcrypt/libassuan/"
  match = "/libassuan-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^libassuan-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://gnupg.org/ftp/gcrypt/libassuan/libassuan-{{version.raw}}.tar.bz2"
  strip-components = 1

  # `versions` resolves 3.0.2 as the newest; 2.5.7 is the newest of the 2 line.
  # Both fetched with `zpkb sourcepin` (593917 and 605076 bytes), and both
  # signatures verified against the key file gnupg.org links from its signature
  # page, with no keyserver:
  #
  #   signed by  6DAA6E64A76D2840571B4902528897B826403ADA
  #              Werner Koch (dist signing 2020)
  #   key file   https://gnupg.org/signature_key.asc
  #   fprs from  https://gnupg.org/signature_key.html
  #   signatures https://gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2.sig
  #              https://gnupg.org/ftp/gcrypt/libassuan/libassuan-2.5.7.tar.bz2.sig
  #
  # Checked when the digests were recorded, not at every build.
  sha256 = {
    "2.5.7" = "0103081ffc27838a2e50479153ca105e873d3d65d8a9593282e9c94c7e6afb76"
    "3.0.2" = "d2931cdad266e633510f9970e1a2f346055e351bb19f9b78912475b8074c36f6"
  }
}

build {
  dependencies = {
    "gnupg.org/libgpg-error" = "^1"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # configure.ac:407 (3.0.2) / :411 (2.5.7) is AM_PATH_GPG_ERROR(1.17,,
      # AC_MSG_ERROR(...)): the dependency is mandatory, and m4/gpg-error.m4:24
      # defines the prefix option. Naming the staged prefix means the probe
      # cannot find a host copy instead.
      "--with-libgpg-error-prefix={{deps.gnupg.org/libgpg-error.prefix}}",

      # configure.ac:487 builds the manual (makeinfo) unless disabled.
      "--disable-doc",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:30-34: with gpgrt-config in use (it is, libgpg-error installs
# it) libassuan-config is noinst, so no program is installed. This is a library.

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/assuan.h",
    "test -f {{prefix}}/lib/pkgconfig/libassuan.pc",
    "pkg-config --exists libassuan",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <assuan.h>

int main(void) {
  /* a context needs no peer; creating and releasing one exercises the library */
  assuan_context_t ctx;
  gpg_error_t err = assuan_new(&ctx);
  if (err) {
    printf("assuan_new failed: %s\n", gpg_strerror(err));
    return 1;
  }
  assuan_release(ctx);
  printf("libassuan %s\n", ASSUAN_VERSION);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o check $(pkg-config --cflags --libs libassuan)"
    },
    "./check",
  ]
}

provenance {
  read = [
    "README",           # :11-13 licences
    "configure.ac",     # 3.0.2 :71 and 2.5.7 :69 API version; :407/:411 AM_PATH_GPG_ERROR(1.17); :485-487 doc
    "src/Makefile.am",  # :30-38 libassuan-config noinst under gpgrt-config; headers and library
    "m4/gpg-error.m4",  # :24 --with-libgpg-error-prefix
    "https://gnupg.org/signature_key.html",
    "gpgme 2.3.1 configure.ac",    # :72 NEED_LIBASSUAN_API=2
    "gnupg 2.4.9 configure.ac",    # :63 NEED_LIBASSUAN_API=2
    "gnupg 2.5.24 configure.ac",   # :65 NEED_LIBASSUAN_API=3
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the source and checked by `zpkb lint` and `zpkb
versions` only. The test's symbols were read from src/assuan.h.in of both
releases (:58 ASSUAN_VERSION, :148 assuan_new), but no build was run.
EOT
}
