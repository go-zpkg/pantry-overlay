# graphite2 — SIL's font rendering engine for complex scripts: libgraphite2 and
# the gr2fonttest tool.
#
# ⛔ WRITTEN FROM GRAPHITE2'S OWN CMakeLists.txt AT 1.3.15, NOT CONVERTED
# (go-zpkg/packages#440). harfbuzz.org and tectonic-typesetting.github.io both
# name this package; it had no recipe of its own.

summary = "SIL Graphite2: a font rendering engine for complex scripts"

# ⛔ FOUR LICENCES, CHOSEN BY THE USER. LICENSE opens: "source code and
# documentation authored, or copyrighted, by SIL International in this
# repository is simultaneously licensed under 4 licenses (LGPL-2.1+, MPL-2.0,
# GPL2+, or MIT) that you may chose to use at your descretion". An SPDX OR
# expression says exactly that.
license = "LGPL-2.1-or-later OR MPL-2.0 OR GPL-2.0-or-later OR MIT"

versions {
  github = "silnrsi/graphite"
}

distributable {
  # The stored release asset, not the generated tag archive: the project
  # uploads graphite2-<version>.tgz itself.
  url              = "https://github.com/silnrsi/graphite/releases/download/{{version.raw}}/graphite2-{{version.raw}}.tgz"
  strip-components = 1

  # Fetched with `zpkb sourcepin` (13674849 bytes), and corroborated by the
  # AUTHOR's own file: the release publishes graphite2-1.3.15.sha256sum, which
  # lists c6bc8b42…fe0b1 for graphite2-1.3.15.tgz (and a different digest for
  # the graphite2-minimal tarball, which is not what this recipe builds). No
  # detached signature is published beside the asset.
  sha256 = {
    "1.3.15" = "c6bc8b4252724665297f7cad0c55897285c673f9b8e6db3522ace833593fe0b1"
  }
}

build {
  dependencies = {
    "cmake.org" = "*"
  }

  working-directory = "build"

  # Every option() and cache variable in CMakeLists.txt:12-28, stated, so that
  # nothing depends on the builder:
  #
  #   BUILD_SHARED_LIBS   :12 default ON; stated ON, dependents link the dylib.
  #   BUILD_TESTING       :13 default ON, and when ON with shared libs :69-70
  #                       runs find_package(Python3 3.6 REQUIRED) — a host
  #                       interpreter would become a build input. OFF.
  #   GRAPHITE2_NFILEFACE :24 default OFF; stated OFF, which KEEPS the
  #                       gr_make_file_face APIs and the gr2fonttest tool.
  #   GRAPHITE2_NTRACING  :25 default ON (tracing compiled out); stated.
  #   GRAPHITE2_TELEMETRY :26 default OFF; stated.
  #   GRAPHITE2_SANITIZERS :27 empty; stated empty.
  #   GRAPHITE2_VM_TYPE   :23 "auto" picks direct on GCC/Clang, call otherwise
  #                       (:56-66) — a function of the compiler, left as is.
  #
  # doc/CMakeLists.txt uses find_program for a2x, dblatex, doxygen and pdflatex,
  # but only attaches the results to a `docs` custom target that `all` does not
  # depend on, so nothing found there reaches the artifact. The fuzzer and
  # sanitizer paths need an explicit GRAPHITE2_SANITIZERS and are not entered.
  env {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX=\"{{ prefix }}\"",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_TESTING=OFF",
      "-DGRAPHITE2_NFILEFACE=OFF",
      "-DGRAPHITE2_NTRACING=ON",
      "-DGRAPHITE2_TELEMETRY=OFF",
      "-DGRAPHITE2_SANITIZERS=",
    ]
  }

  # The generator is pinned: with ninja on PATH cmake would otherwise pick it
  # and the `make` line would find no Makefile.
  script = [
    "cmake .. -G \"Unix Makefiles\" $ARGS",
    "make --jobs {{ hw.concurrency }} install",
  ]
}

# gr2fonttest/CMakeLists.txt:23 installs the tool to bin; src/CMakeLists.txt:146
# installs the library to lib and the headers to include/graphite2.
provides = [
  "bin/gr2fonttest",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
  }

  script = [
    "test -x {{prefix}}/bin/gr2fonttest",
    "test -f {{prefix}}/include/graphite2/Font.h",
    "pkg-config --exists graphite2",
    # The .pc `Version:` is the libtool-style API number (CMakeLists.txt:94 and
    # graphite2.pc.in), not the release, so the release is asserted through the
    # library itself: gr_engine_version returns GR2_VERSION_{MAJOR,MINOR,BUGFIX}.
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <graphite2/Font.h>

int main(void) {
  int major = 0, minor = 0, bugfix = 0;
  gr_engine_version(&major, &minor, &bugfix);
  printf("%d.%d.%d\n", major, minor, bugfix);
  return 0;
}
EOT
        extname = "c"
      }
      run = "cc -o grprobe $FIXTURE $(pkg-config --cflags --libs graphite2) -Wl,-rpath,{{prefix}}/lib"
    },
    "test \"$(./grprobe)\" = {{version.raw}}",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                  # :12-28 every option; :56-66 the vm type; :69-83 Python3 REQUIRED under BUILD_TESTING; :85-92 subdirectories; :94-100 the .pc and its install
    "src/CMakeLists.txt",              # :13 lib_so_version; :146-147 installs the library, headers and export set
    "doc/CMakeLists.txt",              # find_program a2x/dblatex/doxygen/pdflatex feeding only the `docs` custom target
    "gr2fonttest/CMakeLists.txt",      # :23 installs gr2fonttest to bin
    "graphite2.pc.in",                 # Version: ${version} is the API number
    "include/graphite2/Font.h",        # :7-9 GR2_VERSION_MAJOR/MINOR/BUGFIX; :24 gr_engine_version
    "src/gr_font.cpp",                 # :14-16 gr_engine_version fills them from those macros
    "LICENSE",                         # the four licences, chosen at the user's discretion
  ]

  consulted = [
    "https://github.com/silnrsi/graphite/releases/download/1.3.15/graphite2-1.3.15.sha256sum", # the author's own digest file
  ]

  note = <<EOT
NOT BUILT. Lint-only: this recipe was written from the source tree and checked
with `zpkb lint`, `zpkb versions` and `zpkb sourcepin`; no build or test was
run, so the option census and the fixture are unexecuted.

The release asset digest was fetched with `zpkb sourcepin` and equals the
digest in the project's own graphite2-1.3.15.sha256sum. There is no .asc/.sig,
so the second witness is the author's checksum file, not a signature.
EOT
}
