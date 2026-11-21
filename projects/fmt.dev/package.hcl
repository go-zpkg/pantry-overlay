# fmt.dev — {fmt}, a formatting library for C++: the fast, safe replacement for
# printf and iostreams that C++20 std::format standardises.
#
# ⛔ WRITTEN FROM {FMT}'S OWN FILES (go-zpkg/packages#440), at 12.2.1, because the
# Facebook C++ stack (folly, fizz, wangle, fbthrift, fb303, edencommon, watchman)
# links it through `find_package(fmt CONFIG)` and this tree had no recipe for it.

summary = "{fmt}: a modern formatting library for C++"

# LICENSE:1-20 is the MIT text ("Permission is hereby granted, free of charge").
# It is the whole file: the "optional exception for binary distribution" that
# some copies of the licence append is NOT present at this tag.
license = "MIT"

versions {
  github = "fmtlib/fmt"
}

distributable {
  # THE STORED RELEASE ASSET, NOT THE GENERATED TAG ARCHIVE. fmt uploads
  # fmt-<version>.zip (and a SLSA provenance fmt-<version>.intoto.jsonl) to every
  # release; zpkb's fetcher extracts zip and honours strip-components.
  url              = "https://github.com/fmtlib/fmt/releases/download/{{version.raw}}/fmt-{{version.raw}}.zip"
  strip-components = 1

  # 1487547 bytes, fetched with `zpkb sourcepin`; a second, independent fetch
  # (curl, then shasum -a 256) gave the same digest. The project's own witness
  # is the .intoto.jsonl beside the asset, which was fetched (20187 bytes) but
  # not verified here: that needs a SLSA verifier.
  sha256 = {
    "12.2.1" = "870a49acec5bcdab236aeea834ebd7f0b8548a7d8cea33c996b6873a37f2d50c"
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

      # ⛔ STATIC, AND THAT IS A DECISION. BUILD_SHARED_LIBS is not an option()
      # of this project (CMakeLists.txt:80-90 lists none), it is CMake's own
      # switch, default OFF. folly links fmt into a library it ships as static
      # archives, and fizz/wangle/fbthrift are built against the same copy, so a
      # position-independent static library is what they need; ON would put a
      # second libfmt.so in the closure.
      "-DBUILD_SHARED_LIBS=OFF",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",

      # CMakeLists.txt:80-86: every `option()` defaults to ${FMT_MASTER_PROJECT},
      # i.e. ON for a top-level build, so tests and docs are ON unless said.
      "-DFMT_TEST=OFF",
      "-DFMT_DOC=OFF",
      "-DFMT_FUZZ=OFF",
      "-DFMT_CUDA_TEST=OFF",
      # FMT_INSTALL is ON by default for a master project; named so a change of
      # default cannot silently drop the install rules.
      "-DFMT_INSTALL=ON",
      # :85 OS-specific APIs (fmt/os.h): the default, kept because fizz and
      # folly include it.
      "-DFMT_OS=ON",
      # :87 OFF is the default: headers are NOT exposed as system headers, so
      # warnings in them stay visible.
      "-DFMT_SYSTEM_HEADERS=OFF",
      "-DFMT_UNICODE=ON",
      "-DFMT_PEDANTIC=OFF",
      "-DFMT_WERROR=OFF",
      # :86 defaults to ON only when CMake >= 3.28, the generator is Ninja and
      # the compiler is GCC >= 15 / Clang >= 16 / MSVC. This recipe uses make,
      # so it would be OFF anyway; named, because a module build installs
      # different files.
      "-DFMT_MODULE=OFF",
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
    "test -f {{prefix}}/include/fmt/format.h",
    "test -f {{prefix}}/lib/pkgconfig/fmt.pc",
    "pkg-config --exists fmt",
    {
      fixture = {
        content  = <<EOT
#include <fmt/core.h>
#include <fmt/format.h>

int main() {
  std::string s = fmt::format("{}-{:04d}-{:.2f}", "fmt", 42, 3.14159);
  if (s != "fmt-0042-3.14") {
    fmt::print("unexpected: {}\n", s);
    return 1;
  }
  fmt::print("libfmt {} formatted {}\n", FMT_VERSION, s);
  return 0;
}
EOT
        extname = "cpp"
      }
      run = "g++ -std=c++17 $FIXTURE -o fmtcheck $(pkg-config --cflags --libs fmt)"
    },
    "./fmtcheck",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                  # :80-90 the options and their master-project defaults; :86 FMT_MODULE
    "LICENSE",                         # :1-20 the MIT text
  ]

  consulted = [
    "homebrew-core Formula/f/fmt.rb",
  ]

  note = <<EOT
NOT BUILT. This recipe was written from the project's own files and its test
block has not been run on either platform.

fmt.pc and fmt-config.cmake are installed by the FMT_INSTALL rules; both are
asserted by the test block (pkg-config --exists fmt) because the dependants
find fmt through `find_package(fmt CONFIG)`.
EOT
}
