# graphite.sil.org — Graphite2: SIL's rendering engine for "smart fonts" (the
# Graphite shaping tables of complex-script fonts), as libgraphite2.
#
# ⛔ WRITTEN FROM THE RELEASE TARBALL'S OWN FILES (go-zpkg/packages#440), at
# 1.3.15, as a dependency of harfbuzz.org (its `graphite2` feature) and of
# tectonic-typesetting.github.io. The repository is silnrsi/graphite.

summary = "Graphite2: the rendering engine for Graphite smart fonts"

# CMakeLists.txt:1 `SPDX-License-Identifier: MIT OR MPL-2.0 OR LGPL-2.1-or-later
# OR GPL-2.0-or-later`; COPYING:1-9 states the LGPL 2.1 option in prose.
license = "MIT OR MPL-2.0 OR LGPL-2.1-or-later OR GPL-2.0-or-later"

versions {
  github = "silnrsi/graphite"
}

distributable {
  # The STORED release asset graphite2-1.3.15.tgz (the full tarball, not the
  # `-minimal` one).
  url              = "https://github.com/silnrsi/graphite/releases/download/{{version.raw}}/graphite2-{{version.raw}}.tgz"
  strip-components = 1

  # 13674849 bytes, fetched with `zpkb sourcepin`. The second witness is the
  # release's own graphite2-1.3.15.sha256sum, fetched separately: its line for
  # graphite2-1.3.15.tgz is the same digest. No signature is published.
  sha256 = {
    "1.3.15" = "c6bc8b4252724665297f7cad0c55897285c673f9b8e6db3522ace833593fe0b1"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
  }

  # Every option CMakeLists.txt declares (:12-28), stated:
  #   BUILD_SHARED_LIBS ON      :12, the default, stated: libgraphite2.so.
  #   BUILD_TESTING OFF         :13 defaults ON and would add the tests/ tree,
  #                             which needs a Python 3 (:69-83); the test suite
  #                             is not built.
  #   GRAPHITE2_VM_TYPE auto    :23, the default: `direct` for a Release build
  #                             with gcc or clang (:56-62), stated.
  #   GRAPHITE2_NFILEFACE OFF   :24, default: gr_make_file_face* APIs kept, and
  #                             gr2fonttest (:90-92) is built and installed.
  #   GRAPHITE2_NTRACING ON     :25, default: segment tracing compiled out.
  #   GRAPHITE2_TELEMETRY OFF   :26, default.
  #   GRAPHITE2_SANITIZERS      :27, empty (default): no sanitizer in a release.
  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_TESTING=OFF",
      "-DGRAPHITE2_VM_TYPE=auto",
      "-DGRAPHITE2_NFILEFACE=OFF",
      "-DGRAPHITE2_NTRACING=ON",
      "-DGRAPHITE2_TELEMETRY=OFF",
      "-DGRAPHITE2_SANITIZERS=",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# src/CMakeLists.txt:146 installs the library, gr2fonttest/CMakeLists.txt:23 the
# test program, CMakeLists.txt:100 the pkg-config file.
provides = [
  "bin/gr2fonttest",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/graphite2/Font.h",
    "pkg-config --exists graphite2",
    {
      fixture = {
        content  = <<EOT
#include <graphite2/Font.h>
#include <stdio.h>

int main(void) {
  int major = 0, minor = 0, bugfix = 0;
  gr_engine_version(&major, &minor, &bugfix);
  printf("%d.%d.%d\n", major, minor, bugfix);
  return (major == 3 || major == 2 || major == 1) ? 0 : 1;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o version $(pkg-config --cflags --libs graphite2)"
    },
    "./version",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",             # :1 the licence line; :12-28 every option; :56-62 the VM type; :69-83 the Python test probe; :85-92 subdirectories; :98-100 the pkg-config file
    "COPYING",                    # :1-9 the licence statement
    "gr2fonttest/CMakeLists.txt", # :13 the executable, :23 its install
    "src/CMakeLists.txt",         # :146-147 the install rules
    "include/graphite2/Font.h",   # :24 gr_engine_version
  ]

  consulted = [
    "graphite2-1.3.15.sha256sum from the release page",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the test
block has been run, on either platform.

The test fixture calls gr_engine_version, declared at include/graphite2/Font.h:24
(`void gr_engine_version(int *nMajor, int *nMinor, int *nBugFix)`). It prints the
engine's own API version and accepts 1, 2 or 3 as the major, a loose check made
because the number was not read from the source.
Not read: doc/CMakeLists.txt beyond the absence of install or option lines, and
src/ beyond the install rules.
EOT
}
