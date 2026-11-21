# UDUNITS-2 — Unidata's library and `udunits2` program for physical units
# (parse "km/h", convert between compatible units). A dependency of nco.
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1), as a dependency of the nco chain.

summary = "Library and program for manipulating and converting physical units"

# COPYRIGHT is NOT plain BSD-3-Clause: its clauses 1-3 (:11-18) are the BSD
# ones, and clause 4 (:19-25) adds a patent-termination condition ("This
# license shall terminate automatically ... alleging that this software
# infringes a patent"). No SPDX identifier matches that text, so a LicenseRef
# is recorded rather than a BSD-3-Clause that would under-report it.
license = "LicenseRef-UCAR-BSD-with-patent-termination"

versions {
  github = "Unidata/UDUNITS-2"
  ignore = ["/beta|alpha|rc/"]
}

distributable {
  # Unidata's download server holds udunits-<version>.tar.gz (1224503 bytes for
  # 2.2.28); the GitHub repository publishes tags only, no release asset. The
  # tarball ships `configure`.
  #
  # Fetched with `zpkb sourcepin`. The second witness is the project's own
  # checksum file next to the tarball, udunits-2.2.28.tar.gz.sha256, fetched
  # separately: it says the same digest. It is served from the same host as the
  # tarball and no detached signature is published (the .asc answers 404), so
  # it guards against a corrupted fetch, not a compromised server.
  url              = "https://downloads.unidata.ucar.edu/udunits/{{version}}/udunits-{{version}}.tar.gz"
  strip-components = 1

  sha256 = {
    "2.2.28" = "590baec83161a3fd62c00efa66f6113cec8a7c461e3f61a5182167e0cc5d579e"
  }
}

build {
  dependencies = {
    "gnu.org/make"          = "*"
    "libexpat.github.io"    = "*"
  }

  env {
    # configure.ac options, read in full:
    #   :25  --enable-coverage  default off, not passed
    #   :37  --enable-debug     default off, not passed
    #   :58  --enable-udunits-1 the legacy udunits-1 API
    # and the libraries it probes: :105 AC_SEARCH_LIBS([XML_StopParser],
    # [expat]) which is REQUIRED and is why libexpat is declared above, :108
    # dlopen in libc or -ldl, :118 CUnit only to build its tests (not a
    # dependency, so the tests are simply not built).
    ARGS = [
      "--prefix={{prefix}}",
      "--enable-shared",
      "--enable-static",
      "--disable-debug",
      "--disable-coverage",
      "--disable-udunits-1",
      "CPPFLAGS=-I{{deps.libexpat.github.io.prefix}}/include",
      "LDFLAGS=-L{{deps.libexpat.github.io.prefix}}/lib -Wl,-rpath,{{deps.libexpat.github.io.prefix}}/lib",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }}
make install
EOT
}

# prog/Makefile.am:8 `bin_PROGRAMS = udunits2`. The project installs no
# pkg-config file (none in the tarball), so the test links by name.
provides = [
  "bin/udunits2",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -x {{prefix}}/bin/udunits2",
    "test -f {{prefix}}/include/udunits2.h",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <udunits2.h>

int main(void) {
  ut_set_error_message_handler(ut_ignore);
  ut_system *sys = ut_read_xml(NULL);
  if (sys == NULL) {
    puts("ut_read_xml failed: the units database was not found");
    return 1;
  }
  ut_unit *km = ut_parse(sys, "km", UT_ASCII);
  ut_unit *m = ut_parse(sys, "m", UT_ASCII);
  if (km == NULL || m == NULL) {
    puts("ut_parse failed");
    return 1;
  }
  cv_converter *c = ut_get_converter(km, m);
  if (c == NULL) {
    puts("no converter km to m");
    return 1;
  }
  double v = cv_convert_double(c, 1.0);
  printf("1 km = %g m\n", v);
  return v == 1000.0 ? 0 : 1;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o conv -I{{prefix}}/include -L{{prefix}}/lib -Wl,-rpath,{{prefix}}/lib -ludunits2"
    },
    "./conv",
  ]
}

provenance {
  read = [
    "configure.ac",    # :25 :37 :58 options; :105 expat required; :108 dl; :118 CUnit for tests
    "prog/Makefile.am", # :8 bin_PROGRAMS = udunits2
    "COPYRIGHT",       # :11-18 BSD clauses 1-3; :19-25 patent-termination clause 4
    "udunits-2.2.28.tar.gz.sha256", # published digest, same as the pin
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the sources; not run on a builder. The fixture
reads the units database (udunits2.xml) through ut_read_xml(NULL), so it
fails if the database is not found at its installed path.
EOT
}
