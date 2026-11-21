# google.com/glog — Google's C++ logging library.
#
# ⛔ WRITTEN FROM GLOG'S OWN FILES (go-zpkg/packages#440), at 0.7.1: folly, fizz,
# wangle, fbthrift, fb303, edencommon and watchman all require it.

summary = "glog: Google's application-level logging library for C++"

# COPYING:1-5 "Copyright (c) 2024, Google Inc." and the three-clause BSD text.
license = "BSD-3-Clause"

versions {
  github = "google/glog"
  ignore = ["/rc/"]
}

dependencies = {
  # WITH_GFLAGS is ON (CMakeLists.txt:37) and `find_package (gflags 2.2.2)` at
  # :77 is OPTIONAL: without gflags the build silently drops the flags.
  "gflags.github.io" = "^2.2"
}

distributable {
  # No release assets (v0.7.1 has none): the generated tag archive.
  url              = "https://github.com/google/glog/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 182681 bytes, `zpkb sourcepin`; a second fetch through codeload.github.com
  # gave the same digest.
  sha256 = {
    "0.7.1" = "00e4a87e87b7e7612f519a41e491f16623b12423620006f59f5688bfd8d13b08"
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

      # CMakeLists.txt:34 defaults to ON (shared); kept, and stated.
      "-DBUILD_SHARED_LIBS=ON",
      # :37 and :77: gflags is linked, by name.
      "-DWITH_GFLAGS=ON",
      # :38,:46,:55-57 tests need GTest; OFF also sets
      # CMAKE_DISABLE_FIND_PACKAGE_GTest, so a host googletest is not used.
      "-DWITH_GTEST=OFF",
      "-DWITH_GMOCK=OFF",
      # :39 default OFF: ON installs libglog.pc, which dependants' pkg-config
      # lookups can use.
      "-DWITH_PKGCONFIG=ON",
      "-DWITH_SYMBOLIZE=ON",
      "-DWITH_TLS=ON",
      "-DPRINT_UNSYMBOLIZED_STACK_TRACES=OFF",
      # :43,:51-53 the default is `libunwind`, and `find_package (Unwind)` at :86
      # links whichever unwinder the builder has. `none` sets
      # CMAKE_DISABLE_FIND_PACKAGE_Unwind, so the artifact does not depend on a
      # host libunwind.
      "-DWITH_UNWIND=none",
      "-DWITH_FUZZING=none",
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
    "test -f {{prefix}}/include/glog/logging.h",
    "pkg-config --exists libglog",
    {
      fixture = {
        content  = <<EOT
#include <glog/logging.h>

int main(int, char** argv) {
  google::InitGoogleLogging(argv[0]);
  FLAGS_logtostderr = true;
  LOG(INFO) << "glog works";
  return 0;
}
EOT
        extname = "cpp"
      }
      run = "g++ -std=c++17 $FIXTURE -o logcheck $(pkg-config --cflags --libs libglog)"
    },
    "./logcheck",
  ]
}

provenance {
  read = [
    "CMakeLists.txt", # :34-53 the options, WITH_UNWIND; :66-99 the GTest, gflags and Unwind probes
    "COPYING",        # :1-5
  ]

  consulted = [
    "homebrew-core Formula/g/glog.rb",
  ]

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt; the test block has not been run.

Not read: CMakeLists.txt past line 125, so nothing here is claimed about the
export or install rules.
EOT
}
