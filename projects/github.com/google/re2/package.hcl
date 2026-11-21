# RE2 — a regular expression library with guaranteed linear-time matching
# (the engine gRPC uses).
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1). It is a dependency of grpc.io, and no recipe existed.

summary = "Fast, safe regular expression library (linear time)"

# LICENSE: three-clause BSD ("Redistribution and use ...", "Neither the name of
# Google Inc."), copyright The RE2 Authors.
license = "BSD-3-Clause"

dependencies = {
  "abseil.io" = "*"
}

versions {
  # The tags are dates (2025-11-05), and the repository also holds a tag that is
  # not one (abseil.old), which the match below leaves out.
  github = "google/re2"
  match  = "/^\\d{4}-\\d{2}-\\d{2}$/"
}

distributable {
  # THE STORED RELEASE ASSET, not the generated tag archive: the release uploads
  # re2-<version>.zip, whose bytes do not change.
  #
  # {{version.tag}} and not {{version.raw}}: `versions` normalises the date tag
  # 2025-11-05 to 2025.11.05, and the asset is named with the tag.
  url              = "https://github.com/google/re2/releases/download/{{version.tag}}/re2-{{version.tag}}.zip"
  strip-components = 1

  # Fetched with `zpkb sourcepin` (457594 bytes). The project publishes no
  # signature and no checksum file. SECOND WITNESS: the Bazel Central Registry
  # records "sha256-x7Gnp8aNLXz400PcVmVcG1qMiq3twBfbRT1MHYkTuEQ=" for the same URL
  # in modules/re2/2025-11-05/source.json; that base64 decodes to the hex below.
  #
  # The pin is keyed by the NORMALISED version (2025.11.05, which `versions`
  # prints), while the URL uses the raw tag (2025-11-05): `lint
  # --check-newest-pinned` refused the dashed key.
  #
  # ⛔ WHAT THAT PROVES: the registry is a third party's record of the digest it
  # saw, not a signature by the project. It agrees with the bytes fetched here.
  sha256 = {
    "2025.11.05" = "c7b1a7a7c68d2d7cf8d343dc56655c1b5a8c8aadedc017db453d4c1d8913b844"
  }
}

build {
  dependencies = {
    "cmake.org"                  = "^3"
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  env {
    # ⛔ THE PROJECT'S CMAKE BUILD, NOT THE MAKEFILE: only CMakeLists.txt
    # :253-281 installs re2Config.cmake, re2ConfigVersion.cmake and the
    # re2::re2 target, and gRPC's `find_package(re2 REQUIRED)`
    # (cmake/re2.cmake:44) is a config-mode search the Makefile's install
    # (Makefile:322-348, headers, libraries and re2.pc only) cannot satisfy.
    # re2.pc is installed by the CMake build too (:281).
    #
    # CMakeLists.txt:6 needs cmake 3.22. Options: :15 BUILD_SHARED_LIBS (default
    # OFF, kept: static, built position-independent so gRPC can link it into
    # shared objects, as the abseil and protobuf recipes do); :16 RE2_USE_ICU
    # OFF; :19 USEPCRE OFF; :30-32 tests and benchmarks OFF (they need
    # GoogleTest and Benchmark); :36 RE2_INSTALL ON. Abseil is found by
    # find_package(absl REQUIRED) (:94), so its prefix goes on
    # CMAKE_PREFIX_PATH.
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCMAKE_PREFIX_PATH={{deps.abseil.io.prefix}}",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
      "-DBUILD_SHARED_LIBS=OFF",
      "-DRE2_USE_ICU=OFF",
      "-DUSEPCRE=OFF",
      "-DRE2_TEST=OFF",
      "-DRE2_BENCHMARK=OFF",
      "-DRE2_BUILD_TESTING=OFF",
      "-DRE2_INSTALL=ON",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{hw.concurrency}}",
    "cmake --install build",
  ]
}

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  env {
    PKG_CONFIG_PATH = "{{prefix}}/lib/pkgconfig:{{deps.abseil.io.prefix}}/lib/pkgconfig"
  }

  script = [
    "test -f {{prefix}}/include/re2/re2.h",
    "test -f {{prefix}}/lib/cmake/re2/re2Config.cmake",
    "pkg-config --exists re2",
    {
      # The project's own install test (testinstall.cc), the same call the
      # Makefile's `shared-testinstall` makes.
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <re2/filtered_re2.h>
#include <re2/re2.h>

int main() {
  re2::FilteredRE2 f;
  int id;
  f.Add("a.*b.*c", RE2::DefaultOptions, &id);
  std::vector<std::string> v;
  f.Compile(&v);
  std::vector<int> ids;
  f.FirstMatch("abbccc", ids);

  int n;
  if (RE2::FullMatch("axbyc", "a.*b.*c") &&
      RE2::PartialMatch("foo123bar", "(\\d+)", &n) && n == 123) {
    printf("PASS\n");
    return 0;
  }

  printf("FAIL\n");
  return 2;
}
EOT
        extname = "cc"
      }
      run = "g++ $FIXTURE -o testinstall -std=c++17 $(pkg-config --cflags --libs re2)"
    },
    "./testinstall",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",  # :6 cmake 3.22; :15-36 options; :94 find_package(absl); :253-281 install of targets, re2Config.cmake, re2.pc
    "Makefile",        # :322-348 install (no cmake config, hence the CMake build)
    "LICENSE",         # BSD three-clause
    "testinstall.cc",  # the test the fixture reproduces
    "re2.pc.in",       # the installed pkg-config file
  ]

  consulted = [
    "https://raw.githubusercontent.com/bazelbuild/bazel-central-registry/main/modules/re2/2025-11-05/source.json",
  ]

  note = <<EOT
NOT BUILT: written from the sources and the stored release asset; not run on a
builder. The Abseil recipe (abseil.io) is written in the same campaign.
Switched from the Makefile to the project's CMake build so that
re2Config.cmake is installed (gRPC needs it); same version and pin.
EOT
}
