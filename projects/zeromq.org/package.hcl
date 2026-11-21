# zeromq.org — libzmq, the ZeroMQ core library (github.com/zeromq/libzmq).
# Written whole from libzmq's own files at 4.3.5 (go-zpkg/packages#440 step 1)
# because getmonero.org needs it (`zeromq.org` = ^4.2) and there was no recipe.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. MOST FEATURES DEFAULT OFF, AND CURVE IS ONE OF THEM. CMakeLists.txt:261-264
#      has WITH_LIBSODIUM OFF and ENABLE_CURVE OFF; a build that is silent
#      publishes a libzmq with no CURVE security. Monero links libsodium next to
#      libzmq (its CMakeLists.txt:1212, 1236-1239), so both are named ON here and
#      libsodium is a dependency.
#   2. SEVERAL SWITCHES DEPEND ON THE BUILD HOST. WITH_LIBBSD defaults ON on its
#      platforms (:246), WITH_TLS ON (:199) and ENABLE_DRAFTS is chosen by the
#      build type (:156-158). Each is named, so a libbsd, gnutls or an
#      installed header on the builder is not silently linked.
#   3. THE ARCHIVE CARRIES A GENERATED `configure`, and a CMakeLists.txt as well
#      (the project supports both). CMake is used because the options named
#      below were read from CMakeLists.txt; configure.ac was not read.
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "ZeroMQ (libzmq): high-performance asynchronous messaging library, with CURVE security"

# LICENSE is the Mozilla Public License Version 2.0 text (its first line).
license = "MPL-2.0"

versions {
  github = "zeromq/libzmq/tags"
  strip  = ["/^v/"]
}

distributable {
  # The stored release asset (it carries the generated configure), not the
  # GitHub tag archive.
  url              = "https://github.com/zeromq/libzmq/releases/download/v{{version.raw}}/zeromq-{{version.raw}}.tar.gz"
  strip-components = 1

  # 2530237 bytes, recorded with `zpkb sourcepin` (v0.97.0). The project
  # publishes no checksum file and no signature next to the asset, so this is a
  # single witness from the release host.
  sha256 = {
    "4.3.5" = "6653ef5910f17954861fe72332e68b03ca6e4d9c7160eb3a8de5a5a913bfab43"
  }
}

dependencies = {
  # CURVE (see point 1).
  "libsodium.org" = "*"
}

build {
  dependencies = {
    "cmake.org"                  = "*"
    "gnu.org/make"               = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCMAKE_PREFIX_PATH={{deps.libsodium.org.prefix}}",

      # CMakeLists.txt:261-264 (see point 1).
      "-DWITH_LIBSODIUM=ON",
      "-DENABLE_CURVE=ON",
      "-DWITH_LIBSODIUM_STATIC=OFF",

      # :246, :199-200 (see point 2): builtin strlcpy, builtin sha1, no TLS for
      # WSS.
      "-DWITH_LIBBSD=OFF",
      "-DWITH_TLS=OFF",
      "-DWITH_NSS=OFF",

      # :147-149 transports that need other libraries: all OFF upstream, named.
      "-DWITH_OPENPGM=OFF",
      "-DWITH_NORM=OFF",
      "-DWITH_VMCI=OFF",

      # :156-158 draft API is unstable by definition; a consumer built against
      # a stable library should not see it.
      "-DENABLE_DRAFTS=OFF",

      # Not for a consumer: html docs (:1255, asciidoc), tests (:1650-1652),
      # perf tools (:1589-1591), cpack (:1759), analysis (:622).
      "-DWITH_DOCS=OFF",
      "-DBUILD_TESTS=OFF",
      "-DWITH_PERF_TOOL=OFF",
      "-DENABLE_CPACK=OFF",
      "-DENABLE_ANALYSIS=OFF",

      # Both library kinds (:1306-1307, default ON): the shared library for
      # ordinary consumers, the archive for static links such as Monero's
      # STATIC option (its CMakeLists.txt:505-511 adds -DZMQ_STATIC).
      "-DBUILD_SHARED=ON",
      "-DBUILD_STATIC=ON",

      # :666-667 pedantic stays on (warnings only), Werror off.
      "-DLIBZMQ_WERROR=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# A library: tools/ and perf/ are not built (WITH_PERF_TOOL=OFF).
provides = []

test {
  script = [
    "test -f \"{{prefix}}/include/zmq.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/libzmq.pc\"",
    {
      run = <<EOT
set -eu
ls "{{prefix}}"/lib/libzmq.* >/dev/null
# CURVE is asked for by name above; the header's capability probe answers it.
cat > curve.c <<'EOC'
#include <stdio.h>
#include <zmq.h>
int main(void) {
  if (!zmq_has("curve")) { fprintf(stderr, "libzmq has no CURVE\n"); return 1; }
  int a, b, c;
  zmq_version(&a, &b, &c);
  printf("%d.%d.%d\n", a, b, c);
  return 0;
}
EOC
cc curve.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lzmq -o curve
if [ "$(uname)" = Darwin ]; then
  DYLD_LIBRARY_PATH="{{prefix}}/lib" ./curve > v.txt
else
  LD_LIBRARY_PATH="{{prefix}}/lib" ./curve > v.txt
fi
grep -qx '{{version.raw}}' v.txt
EOT
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",  # :147-149 WITH_OPENPGM/NORM/VMCI; :156-158 ENABLE_DRAFTS; :199-200 WITH_TLS/NSS; :246 WITH_LIBBSD; :261-264 WITH_LIBSODIUM, ENABLE_CURVE; :622 ENABLE_ANALYSIS; :1255 WITH_DOCS; :1306-1307 BUILD_SHARED/STATIC; :1589 WITH_PERF_TOOL; :1650 BUILD_TESTS; :1759 ENABLE_CPACK
    "LICENSE",         # Mozilla Public License Version 2.0
  ]

  consulted = [
    "projects/github.com/awslabs/aws-c-common in this tree",  # the cmake configure/build/install shape
  ]

  note = <<EOT
⚠ THE SOURCE RUNG: a single witness, the digest of the stored release asset
recorded with `zpkb sourcepin`; the project publishes neither a signature nor a
checksum file.

⚠ SELECTED BY READING, NOT TRIED: that CMAKE_PREFIX_PATH is how this tree's
libsodium is found (libzmq's cmake module for it was not read, only the
option lines); that `cc` is available in the test environment; that the
-DWITH_* names are those of 4.3.5's cache (read from the option lines, not
from a configure log); that DYLD_LIBRARY_PATH / LD_LIBRARY_PATH is what the
test loader needs (no rpath set).

⛔ NOT BUILT by the factory, and not by hand. Lint only. The first factory run is
this file's test.
EOT
}
