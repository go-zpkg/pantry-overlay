# npth — the New GNU Portable Threads library, the scheduler gpg-agent and
# dirmngr use over pthreads.
#
# WRITTEN FROM THE PROJECT'S OWN FILES at 1.8 (go-zpkg/packages#440). There was
# no recipe; gnupg.org and gnupg.org/v2.5 name it as a dependency.

summary = "New GNU Portable Threads library"

# src/npth.h.in:8-10: "GNU Lesser General Public License ... or (at your
# option) any later version"; COPYING.LIB is the licence text it ships.
license = "LGPL-2.1-or-later"

versions {
  url   = "https://gnupg.org/ftp/gcrypt/npth/"
  match = "/npth-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.bz2/"
  strip = [
    "/^npth-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://gnupg.org/ftp/gcrypt/npth/npth-{{version.raw}}.tar.bz2"
  strip-components = 1

  # `versions` resolves 1.8 as the newest. Fetched with `zpkb sourcepin`
  # (317739 bytes); the detached signature verified against the key file
  # gnupg.org links from its signature page, no keyserver:
  #
  #   signed by  6DAA6E64A76D2840571B4902528897B826403ADA
  #              Werner Koch (dist signing 2020)
  #   key file   https://gnupg.org/signature_key.asc
  #   fprs from  https://gnupg.org/signature_key.html
  #   signature  https://gnupg.org/ftp/gcrypt/npth/npth-1.8.tar.bz2.sig
  #
  # Checked when the digest was recorded, not at every build.
  sha256 = {
    "1.8" = "8bd24b4f23a3065d6e5b26e98aba9ce783ea4fd781069c1b35d149694e90ca3e"
  }
}

build {
  env {
    ARGS = [
      "--prefix={{prefix}}",

      # configure.ac:154 builds the test programs; they are not installed.
      "--disable-tests",

      # configure.ac:147-150: npth-config is deprecated in favour of npth.pc,
      # and is installed only on request. Stated off.
      "--disable-install-npth-config",
    ]
  }

  # configure.ac has no AC_ARG_WITH and no AC_CHECK_LIB: npth looks for no
  # package of the host, only for the threads library of the platform.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:25 lib_LTLIBRARIES = libnpth.la, and nothing else: no program.

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/npth.h",
    "test -f {{prefix}}/lib/pkgconfig/npth.pc",
    "pkg-config --exists npth",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <npth.h>

int main(void) {
  if (npth_init() != 0) {
    puts("npth_init failed");
    return 1;
  }
  printf("npth %s\n", NPTH_VERSION);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o check $(pkg-config --cflags --libs npth)"
    },
    "./check",
  ]
}

provenance {
  read = [
    "configure.ac",    # :147-150 install-npth-config; :154 tests; no AC_ARG_WITH, no AC_CHECK_LIB
    "src/Makefile.am", # :25 the one library
    "src/npth.h.in",   # :8-10 licence; :74 NPTH_VERSION; :87 npth_init
    "npth.pc.in",      # :11-12 Libs and Cflags carry the thread flags
    "https://gnupg.org/signature_key.html",
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the source and checked by `zpkb lint` and `zpkb
versions` only; the fixture's API names were read from src/npth.h.in.
EOT
}
