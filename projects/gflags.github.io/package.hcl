# gflags.github.io — gflags, Google's command line flags library for C++.
#
# ⛔ WRITTEN FROM GFLAGS' OWN FILES (go-zpkg/packages#440), at 2.3.1, because
# folly, fizz, wangle, fbthrift, fb303, edencommon and watchman all find it
# (`find_package(Gflags)`) and glog links it, and this tree had no recipe.

summary = "gflags: a C++ library for command line flag processing"

# COPYING.txt:1-8 is the three-clause BSD text ("Copyright (c) 2006, Google Inc.",
# redistribution conditions, then the name-of-Google clause).
license = "BSD-3-Clause"

versions {
  github = "gflags/gflags"
}

distributable {
  # The release publishes NO assets (`gh release view` on v2.3.1 lists none), so
  # the generated tag archive is the only source.
  url              = "https://github.com/gflags/gflags/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 121197 bytes, `zpkb sourcepin`; a second fetch through codeload.github.com
  # gave the same digest. Both are GitHub's generator, so this is a check on the
  # transfer and not on the generator.
  sha256 = {
    "2.3.1" = "1b5e0648d7b94021895086e65479b4eaca7935eecfffd7dd9512eb576181c53d"
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

      # CMakeLists.txt:173-185, the `gflags_define` table, default then
      # subproject default. Every switch is stated.
      # STATIC ONLY: the Facebook stack links static archives, and a shared
      # libgflags beside them would carry a second copy of the flag registry.
      "-DBUILD_SHARED_LIBS=OFF",
      "-DBUILD_STATIC_LIBS=ON",
      "-DINSTALL_SHARED_LIBS=OFF",
      "-DINSTALL_STATIC_LIBS=ON",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
      # The multi-threaded library is what folly and glog use; the
      # single-threaded one (default ON, :176) is not wanted.
      "-DBUILD_gflags_LIB=ON",
      "-DBUILD_gflags_nothreads_LIB=OFF",
      "-DBUILD_TESTING=OFF",
      "-DBUILD_PACKAGING=OFF",
      "-DINSTALL_HEADERS=ON",
      # :182-183 REGISTER_INSTALL_PREFIX defaults ON: it writes the install
      # prefix into the USER'S CMake package registry (~/.cmake), a side effect
      # of a build on the builder's home directory.
      "-DREGISTER_BUILD_DIR=OFF",
      "-DREGISTER_INSTALL_PREFIX=OFF",
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
    "test -f {{prefix}}/include/gflags/gflags.h",
    "test -f {{prefix}}/lib/pkgconfig/gflags.pc",
    {
      fixture = {
        content  = <<EOT
#include <gflags/gflags.h>
#include <cstdio>

DEFINE_int32(answer, 0, "the answer");

int main(int argc, char** argv) {
  gflags::ParseCommandLineFlags(&argc, &argv, true);
  if (FLAGS_answer != 42) {
    std::printf("answer is %d\n", FLAGS_answer);
    return 1;
  }
  return 0;
}
EOT
        extname = "cpp"
      }
      run = "g++ -std=c++17 $FIXTURE -o flagcheck -I{{prefix}}/include -L{{prefix}}/lib -lgflags -lpthread"
    },
    "./flagcheck --answer=42",
  ]
}

provenance {
  read = [
    "CMakeLists.txt", # :173-185 the gflags_define switches and defaults
    "COPYING.txt",    # :1-8 BSD-3-Clause
  ]

  consulted = [
    "homebrew-core Formula/g/gflags.rb",
  ]

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt; the test block has not been run.

The shipped version is 2.3.1, the newest tag. glog 0.7.1 asks for gflags
2.2.2 or newer (its CMakeLists.txt:77).
EOT
}
