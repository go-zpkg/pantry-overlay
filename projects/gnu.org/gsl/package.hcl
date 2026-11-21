# GSL — the GNU Scientific Library (libgsl, libgslcblas, gsl-config).
# A dependency of nco.
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1), as a dependency of the nco chain.

summary = "GNU Scientific Library: numerical routines for C"

# COPYING is the GPLv3 text (:2 "Version 3, 29 June 2007") and randist/gauss.c:8
# carries "either version 3 of the License, or (at your option) any later".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/gsl/"
  match = "/gsl-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = [
    "/^gsl-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/gsl/gsl-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin --sig auto` (8997136 bytes, 2.8). The
  # signature is VALID and made by DD61B7FC02790F978360F399245FB74BAE05B3E9
  # (Patrick Alken <alken@colorado.edu>), signed 2024-05-25. The fingerprint
  # was found by reading the signature's issuer key id (245FB74BAE05B3E9) and
  # looking it up in ftp.gnu.org's own gnu-keyring.gpg; no keyserver was asked.
  # The signature URL is https://ftp.gnu.org/gnu/gsl/gsl-2.8.tar.gz.sig
  #
  # Where this is weaker: the keyring and the tarball are served by the same
  # host, which is continuity, not an independent attestation.
  sha256 = {
    "2.8" = "6a99eeed15632c6354895b1dd542ed5a855c0f15d9ad1326c6fe2b2c9e423190"
  }
}

build {
  env {
    # configure.ac has no AC_ARG_ENABLE or AC_ARG_WITH of its own (read in
    # full for AC_INIT and LT_INIT([win32-dll]), :3 and :117): the library has
    # no optional dependency to detect, so there is nothing to name on or off
    # beyond the libtool defaults, stated here for both library kinds.
    ARGS = [
      "--prefix={{prefix}}",
      "--enable-shared",
      "--enable-static",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }}
make install
EOT
}

# Makefile.am:11 `bin_SCRIPTS = gsl-config`; :29 `bin_PROGRAMS = gsl-randist
# gsl-histogram`.
provides = [
  "bin/gsl-config",
  "bin/gsl-histogram",
  "bin/gsl-randist",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "gsl-config --version",
    "test -f {{prefix}}/include/gsl/gsl_version.h",
    "pkg-config --exists gsl",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <gsl/gsl_sf_bessel.h>
#include <gsl/gsl_version.h>

int main(void) {
  double y = gsl_sf_bessel_J0(5.0);
  printf("gsl %s, J0(5) = %.6f\n", gsl_version, y);
  return (y < -0.1775 && y > -0.1777) ? 0 : 1;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o bessel $(pkg-config --cflags --libs gsl)"
    },
    "./bessel",
  ]
}

provenance {
  read = [
    "configure.ac", # :3 AC_INIT, :117 LT_INIT; no AC_ARG_* options
    "Makefile.am",  # :11 bin_SCRIPTS; :13-14 gsl.pc under libdir/pkgconfig; :29 bin_PROGRAMS
    "COPYING",      # :2 GPL version 3
    "randist/gauss.c", # :8 "either version 3 of the License, or (at your option) any later"
  ]

  consulted = [
    "https://ftp.gnu.org/gnu/gnu-keyring.gpg",
  ]

  note = <<EOT
NOT BUILT: written from the sources and the signed release; not run on a
builder. The fixture checks gsl_sf_bessel_J0(5) lies in (-0.1777, -0.1775);
the value J0(5) = -0.17760 is from the standard tables, not from a run.
EOT
}
