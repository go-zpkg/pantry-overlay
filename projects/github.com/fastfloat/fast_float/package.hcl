# github.com/fastfloat/fast_float — fast and exact float parsing, header-only.
#
# ⛔ WRITTEN FROM FAST_FLOAT'S OWN FILES (go-zpkg/packages#440), at 8.3.3. folly
# includes it (folly-deps.cmake:153-172: `find_package(FastFloat MODULE)`, and
# if absent it FETCHES it from the network at configure time).

summary = "fast_float: fast and exact number parsing for C++"

# Upstream is tri-licensed (Apache-2.0, MIT and BSL-1.0, per its README); the
# README was NOT opened for this recipe, so the field is the one the pantry
# convention records and is flagged in the provenance note.
license = "Apache-2.0 OR MIT OR BSL-1.0"

versions {
  github = "fastfloat/fast_float"
}

distributable {
  # The only release asset is the single header fast_float.h, not the project
  # (no CMake files), so the generated tag archive is used.
  url              = "https://github.com/fastfloat/fast_float/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 156846 bytes, `zpkb sourcepin`; second fetch through codeload.github.com
  # gave the same digest.
  sha256 = {
    "8.3.3" = "4dd695f051893c8218faf2ed9871fa4a4990aa6aee2d3190ed7bfa2e83092245"
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
      # CMakeLists.txt:7,:16,:27,:36.
      "-DFASTFLOAT_TEST=OFF",
      "-DFASTFLOAT_SANITIZE=OFF",
      "-DFASTFLOAT_INSTALL=ON",
      "-DFASTFLOAT_BENCHMARKS=OFF",
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
    "test -f {{prefix}}/include/fast_float/fast_float.h",
    {
      fixture = {
        content  = <<EOT
#include <fast_float/fast_float.h>
#include <cstring>

int main() {
  const char* s = "3.14159";
  double d = 0;
  auto r = fast_float::from_chars(s, s + std::strlen(s), d);
  return (r.ec == std::errc() && d == 3.14159) ? 0 : 1;
}
EOT
        extname = "cpp"
      }
      run = "g++ -std=c++17 $FIXTURE -o ffcheck -I{{prefix}}/include"
    },
    "./ffcheck",
  ]
}

provenance {
  read = [
    "CMakeLists.txt", # :1-36 version 8.3.3 and the four options
  ]

  consulted = [
    "homebrew-core Formula/f/fast_float.rb",
  ]

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt; the test block has not been run.

The licence field was NOT checked against the project's LICENSE files: only
CMakeLists.txt was read. It records the three licences the project is known to
offer and should be confirmed.
EOT
}
