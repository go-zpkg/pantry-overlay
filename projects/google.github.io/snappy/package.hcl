# google.github.io/snappy — Snappy, a fast compressor/decompressor.
#
# ⛔ WRITTEN FROM SNAPPY'S OWN FILES (go-zpkg/packages#440), at 1.3.1. folly and
# wangle find it (`find_package(Snappy MODULE)`, folly-deps.cmake:513).

summary = "Snappy: a fast compression library"

# COPYING:1-4 "Copyright 2011, Google Inc." — three-clause BSD.
license = "BSD-3-Clause"

versions {
  github = "google/snappy"
}

distributable {
  # No release assets: the generated tag archive (the tag is `1.3.1`, no `v`).
  url              = "https://github.com/google/snappy/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 1116583 bytes, `zpkb sourcepin`; a second fetch through codeload.github.com
  # gave the same digest.
  sha256 = {
    "1.3.1" = "893f708a0bf4b5529d555ffcee390e940e932fcf90261f682604475a76cd0247"
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
      # CMakeLists.txt:112 defaults to OFF: static, which the Facebook stack
      # wants; PIC so it can be linked into their shared pieces.
      "-DBUILD_SHARED_LIBS=OFF",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
      # :114,:116 the tests and benchmarks default to ON, and the tests fetch
      # googletest.
      "-DSNAPPY_BUILD_TESTS=OFF",
      "-DSNAPPY_BUILD_BENCHMARKS=OFF",
      "-DSNAPPY_FUZZING_BUILD=OFF",
      # :120,:122 default OFF: the generic x86-64 build, not one that needs AVX.
      "-DSNAPPY_REQUIRE_AVX=OFF",
      "-DSNAPPY_REQUIRE_AVX2=OFF",
      "-DSNAPPY_INSTALL=ON",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/snappy.h",
    {
      fixture = {
        content  = <<EOT
#include <snappy.h>
#include <string>

int main() {
  std::string in(1000, 'a'), packed, back;
  snappy::Compress(in.data(), in.size(), &packed);
  if (!snappy::Uncompress(packed.data(), packed.size(), &back)) return 1;
  return (back == in && packed.size() < in.size()) ? 0 : 1;
}
EOT
        extname = "cpp"
      }
      run = "g++ -std=c++17 $FIXTURE -o snapcheck -I{{prefix}}/include -L{{prefix}}/lib -lsnappy"
    },
    "./snapcheck",
  ]
}

provenance {
  read = [
    "CMakeLists.txt", # :112-124 the options and defaults
    "COPYING",        # :1-4
  ]

  consulted = [
    "homebrew-core Formula/s/snappy.rb",
  ]

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt; the test block has not been run.
EOT
}
