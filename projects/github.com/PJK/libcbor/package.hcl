# libcbor — a CBOR (RFC 8949) encoder and decoder in C.
#
# ⛔ WRITTEN FROM LIBCBOR'S OWN FILES at 0.15.0 (go-zpkg/packages#440 step 1).
# developers.yubico.com/libfido2 names `github.com/PJK/libcbor` as a dependency
# and no recipe existed, so libfido2 had been skipped.

summary = "CBOR serialization format implementation for C"

# LICENSE.md opens with "MIT License" and "Copyright (c) 2014-2026 Pavel Kalvoda";
# CMakeLists.txt:2 says SPDX-License-Identifier: MIT.
license = "MIT"

versions {
  github = "PJK/libcbor"
}

distributable {
  # ⚠ A GENERATED TAG ARCHIVE: the project attaches no asset to its releases
  # (the release API lists none for v0.15.0), so there is no stored file to
  # prefer. The digest is therefore fragile by construction, and is
  # corroborated only by a second independent fetch.
  url              = "https://github.com/PJK/libcbor/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 0.15.0: 393898 bytes. Fetched with `zpkb sourcepin` and again with curl, on
  # its own, a minute apart: the two agree byte for byte.
  sha256 = {
    "0.15.0" = "c94145d3c22e67cff9a3325dc036b4545a49a42231553995be4947d52cf2ef57"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # src/CMakeLists.txt:89-90 build the .pc paths from CMAKE_INSTALL_LIBDIR,
      # which GNUInstallDirs makes lib64 on some Linux builders; pinned to lib.
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:14: defaults to false (a static library). libfido2 and
      # most dependents link it dynamically, so it is stated ON.
      "-DBUILD_SHARED_LIBS=ON",

      # CMakeLists.txt:32 and :39: the tests need CMocka and a C++ compiler
      # (:35-37); the examples are not installed. Both OFF.
      "-DWITH_TESTS=OFF",
      "-DWITH_EXAMPLES=OFF",

      # CMakeLists.txt:47: default ON, "Enable ASan & a few compatible
      # sanitizers in Debug mode". It only acts in a Debug build, and the build
      # type is Release, but it is named off so no sanitizer can be linked in.
      "-DSANITIZE=OFF",

      # CMakeLists.txt:21: default ON; stated, because cbor_describe is part
      # of the public header.
      "-DCBOR_PRETTY_PRINTER=ON",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# ⚠ NO `provides`: the installs are src/CMakeLists.txt:94-124 (the library,
# cbor.h, libcbor.pc and the cmake package); there is no program.

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/cbor.h",
    "test -f {{prefix}}/include/cbor/configuration.h",
    "test -f {{prefix}}/lib/pkgconfig/libcbor.pc",
    "pkg-config --exists libcbor",
    "test \"$(pkg-config --modversion libcbor)\" = {{version.raw}}",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <stdlib.h>
#include <cbor.h>

int main(void) {
  cbor_item_t *item = cbor_build_uint8(42);
  unsigned char *buf = NULL;
  size_t size = 0;
  size_t n = cbor_serialize_alloc(item, &buf, &size);
  /* 42 is the two-byte item 0x18 0x2a (RFC 8949 appendix A). */
  int ok = n == 2 && buf[0] == 0x18 && buf[1] == 0x2a;
  free(buf);
  cbor_decref(&item);
  if (!ok) {
    puts("encoding of 42 is not 18 2a");
    return 1;
  }
  printf("libcbor %d.%d.%d encoded 42\n", CBOR_MAJOR_VERSION, CBOR_MINOR_VERSION, CBOR_PATCH_VERSION);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o encode $(pkg-config --cflags --libs libcbor)"
    },
    "./encode",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",      # :6 project libcbor VERSION 0.15.0; :14 BUILD_SHARED_LIBS; :21 CBOR_PRETTY_PRINTER; :32-39 WITH_TESTS/WITH_EXAMPLES; :47 SANITIZE
    "src/CMakeLists.txt",  # :89-91 the .pc paths; :94-124 what is installed
    "src/libcbor.pc.in",   # Name/Libs: -lcbor
    "LICENSE.md",          # "MIT License", Copyright (c) 2014-2026 Pavel Kalvoda
  ]

  consulted = []

  note = <<EOT
Written, not converted: no recipe existed.

⛔ NOT BUILT. This recipe was written from the project's CMake files and the
test block was NOT run on a built libcbor in this session.

The source is a GitHub-generated tag archive (the project uploads no release
assets); the pin rests on two independent fetches that agreed. The upstream
publishes no signature or checksum file.

The fixture's CBOR_MAJOR_VERSION is defined at src/cbor/configuration.h.in:9
and cbor_serialize_alloc at src/cbor/serialization.h:66.
EOT
}
