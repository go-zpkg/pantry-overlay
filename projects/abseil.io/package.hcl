# Abseil C++ — Google's common libraries for C++ (strings, containers, hashing,
# synchronization, time, flags, logging).
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1). It is a dependency of grpc.io, protobuf.dev and github.com/google/re2,
# and no recipe existed.

summary = "Abseil C++ common libraries"

# LICENSE: Apache License, Version 2.0.
license = "Apache-2.0"

versions {
  # Releases are "LTS branch" tags named <yyyymmdd>.<patch> (20260817.0). A
  # release candidate is published as a pre-release (20260526.rc1), which the
  # ignore below leaves out.
  github = "abseil/abseil-cpp"
  ignore = ["/rc/"]
}

distributable {
  # THE STORED RELEASE ASSET, not the generated tag archive: the release uploads
  # abseil-cpp-<version>.tar.gz.
  url              = "https://github.com/abseil/abseil-cpp/releases/download/{{version.raw}}/abseil-cpp-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin` (2430876 bytes). The project publishes no
  # signature and no checksum file. SECOND WITNESS: the Bazel Central Registry
  # records "sha256-9+BRed85xFQ0ytQz9Xg4QLs3iO8yKXb5E4vGtys6EH0=" for the same URL
  # in modules/abseil-cpp/20260817.0/source.json; that base64 decodes to the hex
  # below.
  #
  # ⛔ WHAT THAT PROVES: the registry is a third party's record of the digest it
  # saw, not a signature by the project. It agrees with the bytes fetched here.
  sha256 = {
    "20260817.0" = "f7e05179df39c45434cad433f5783840bb3788ef322976f9138bc6b72b3a107d"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
  }

  env {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # ⛔ STATIC, POSITION-INDEPENDENT, AND THAT IS A DECISION. BUILD_SHARED_LIBS
      # is CMake's own switch (default OFF); the project also has
      # ABSL_BUILD_MONOLITHIC_SHARED_LIBS (CMakeLists.txt:128), left OFF. Abseil
      # has no stable ABI between versions, and protobuf, gRPC and RE2 are built
      # against this one copy, so static archives that can be linked into their
      # shared libraries (-fPIC) are what they need; ON would put the Abseil
      # shared objects into each consumer's closure.
      "-DBUILD_SHARED_LIBS=OFF",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",

      # GNUInstallDirs picks lib64 on some systems; the consumers' recipes look
      # in <prefix>/lib/pkgconfig (AbseilHelpers.cmake:225 installs the absl_*.pc
      # files into CMAKE_INSTALL_LIBDIR/pkgconfig).
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # C++17 is the minimum (AbseilHelpers.cmake:304) and C++20 is supported
      # (CMake/README.md:46). 17 is stated so the compiler's default cannot
      # change the ABI of what gets installed. ABSL_PROPAGATE_CXX_STD
      # (CMakeLists.txt:48, default ON) records it for consumers.
      "-DCMAKE_CXX_STANDARD=17",
      "-DABSL_PROPAGATE_CXX_STD=ON",

      # CMakeLists.txt:39-41: install rules are ON for a top-level build; named
      # so a change of default cannot silently drop them.
      "-DABSL_ENABLE_INSTALL=ON",

      # :102-107 tests and test helpers are OFF by default and need GoogleTest.
      "-DABSL_BUILD_TESTING=OFF",
      "-DABSL_BUILD_TEST_HELPERS=OFF",
      "-DABSL_USE_EXTERNAL_GOOGLETEST=OFF",
      "-DABSL_USE_GOOGLETEST_HEAD=OFF",
      "-DBUILD_TESTING=OFF",

      # :52 OFF is the default: headers are not marked SYSTEM, so warnings in
      # them stay visible.
      "-DABSL_USE_SYSTEM_INCLUDES=OFF",
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

  script = [
    "test -f {{prefix}}/include/absl/strings/str_cat.h",
    "pkg-config --exists absl_strings absl_str_format absl_synchronization",
    {
      fixture = {
        content  = <<EOT
#include <iostream>
#include <string>
#include "absl/strings/str_cat.h"
#include "absl/strings/str_format.h"

int main() {
  std::string s = absl::StrCat("abseil-", 20260817, "-", absl::StrFormat("%04d", 42));
  if (s != "abseil-20260817-0042") {
    std::cout << "unexpected: " << s << "\n";
    return 1;
  }
  std::cout << s << "\n";
  return 0;
}
EOT
        extname = "cc"
      }
      # The project's own install test (CMake/install_test_project/test.sh:101-104)
      # links through `pkg-config --cflags --libs absl_str_format`; the same here.
      run = "g++ -std=c++17 $FIXTURE -o abslcheck $(pkg-config --cflags --libs absl_strings absl_str_format)"
    },
    "./abslcheck",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                   # :19 cmake 3.16; :26 version; :39-41 install; :48 CXX_STD; :102-131 testing and shared options
    "CMake/AbseilHelpers.cmake",        # :154-225 absl_*.pc generated and installed; :304 C++17 minimum
    "CMake/README.md",                  # :46 C++17 and C++20
    "CMake/install_test_project/test.sh", # :101-104 pkg-config install test
    "LICENSE",                          # Apache License 2.0
  ]

  consulted = [
    "https://raw.githubusercontent.com/bazelbuild/bazel-central-registry/main/modules/abseil-cpp/20260817.0/source.json",
  ]

  note = <<EOT
NOT BUILT: written from the sources and the stored release asset; not run on a
builder. The Bazel build the project also ships was not used.
EOT
}
