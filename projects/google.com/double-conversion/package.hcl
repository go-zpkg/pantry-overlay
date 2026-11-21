# google.com/double-conversion — efficient binary/decimal double conversion.
#
# ⛔ WRITTEN FROM DOUBLE-CONVERSION'S OWN FILES (go-zpkg/packages#440), at 3.4.0.
# folly requires it (`find_package(DoubleConversion MODULE REQUIRED)`) and this
# tree had no recipe, although the folly fragment named it.

summary = "double-conversion: efficient binary-decimal and decimal-binary conversion routines for IEEE doubles"

# LICENSE:1 "Copyright 2006-2011, the V8 project authors" — the three-clause BSD
# text of V8 (redistribution, binary form, no endorsement by the Google name).
license = "BSD-3-Clause"

versions {
  github = "google/double-conversion"
}

distributable {
  # The release has no assets: the generated tag archive.
  url              = "https://github.com/google/double-conversion/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 7035722 bytes, `zpkb sourcepin`; an independent fetch with curl hashed with
  # shasum gave the same digest (same GitHub generator, so a check on transfer).
  sha256 = {
    "3.4.0" = "42fd4d980ea86426e457b24bdfa835a6f5ad9517ddb01cdb42b99ab9c8dd5dc9"
  }
}

build {
  dependencies = {
    # CMakeLists.txt:4 cmake_minimum_required(VERSION 3.29...4.0.1): a 3.x older
    # than 3.29 is REFUSED, so "^3" would be wrong.
    "cmake.org"    = ">=3.29"
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      # CMakeLists.txt:7 defaults to OFF: static, which folly links.
      "-DBUILD_SHARED_LIBS=OFF",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
      # :41 defaults to OFF; the tests live in test/.
      "-DBUILD_TESTING=OFF",
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
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/double-conversion/double-conversion.h",
    "pkg-config --exists double-conversion",
    {
      fixture = {
        content  = <<EOT
#include <double-conversion/double-conversion.h>
#include <string>

int main() {
  using namespace double_conversion;
  int n = 0;
  StringToDoubleConverter conv(StringToDoubleConverter::NO_FLAGS, 0.0, 0.0, nullptr, nullptr);
  double d = conv.StringToDouble("2.5", 3, &n);
  return (d == 2.5 && n == 3) ? 0 : 1;
}
EOT
        extname = "cpp"
      }
      run = "g++ -std=c++17 $FIXTURE -o dccheck $(pkg-config --cflags --libs double-conversion)"
    },
    "./dccheck",
  ]
}

provenance {
  read = [
    "CMakeLists.txt", # :4 cmake 3.29; :7 BUILD_SHARED_LIBS; :41 BUILD_TESTING; :56-150 install, pkg-config and CMake config
    "LICENSE",        # :1 "Copyright 2006-2011, the V8 project authors"
  ]

  consulted = [
    "homebrew-core Formula/d/double-conversion.rb",
  ]

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt; the test block has not been run.

The licence field was taken from the opening of LICENSE and the V8 provenance
it names; the clause text was not read through.
EOT
}
