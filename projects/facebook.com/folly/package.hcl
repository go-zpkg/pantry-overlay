# facebook.com/folly — Facebook's open-source C++ library.
#
# ⛔ WRITTEN FROM FOLLY'S OWN FILES (go-zpkg/packages#440), at v2026.10.26.00,
# the newest tag folly has: the fragment that stood here named dependencies read
# from an older release, and two of them are WRONG for this one (see the note).
#
# ONE DATE-LIKE RELEASE IS PINNED ACROSS THE STACK (folly, fizz, wangle,
# fbthrift, fb303, edencommon, watchman): 2026.10.26.00. Folly has no tag after
# it, and the other six repositories ship the same date, so the seven are built
# from one snapshot.

summary = "folly: an open-source C++ library developed and used at Facebook"

# LICENSE:2-3 "Apache License / Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "facebook/folly"
}

dependencies = {
  "boost.org"                       = "<1.89"
  "facebook.com/zstd"               = "^1"
  "fmt.dev"                         = "^12"
  "gflags.github.io"                = "^2.2"
  "github.com/fastfloat/fast_float" = "^8"
  "google.com/glog"                 = "^0.7"
  "google.github.io/snappy"         = "^1"
  "libevent.org"                    = "^2"
  "lz4.org"                         = "^1"
  "openssl.org"                     = "^3"
  "sourceware.org/bzip2"            = "^1"
  "tukaani.org/xz"                  = "^5"
  "zlib.net"                        = "^1"
}

distributable {
  # No release assets (the release has none), so the generated tag archive.
  url              = "https://github.com/facebook/folly/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 5653881 bytes, `zpkb sourcepin`; an independent fetch with curl hashed with
  # shasum gave the same digest (same GitHub generator: a check on the transfer).
  sha256 = {
    "2026.10.26.00" = "b47fe04b804adfb51c65cda6b171505e67b9d1d69621106e54697821d1bf7ebc"
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
      "-DCMAKE_PREFIX_PATH={{deps.boost.org.prefix}};{{deps.facebook.com/zstd.prefix}};{{deps.fmt.dev.prefix}};{{deps.gflags.github.io.prefix}};{{deps.github.com/fastfloat/fast_float.prefix}};{{deps.google.com/glog.prefix}};{{deps.google.github.io/snappy.prefix}};{{deps.libevent.org.prefix}};{{deps.lz4.org.prefix}};{{deps.openssl.org.prefix}};{{deps.sourceware.org/bzip2.prefix}};{{deps.tukaani.org/xz.prefix}};{{deps.zlib.net.prefix}}",

      # CMakeLists.txt:91-97 BUILD_SHARED_LIBS defaults OFF; folly does not
      # commit to a stable ABI (its own text), so static.
      "-DBUILD_SHARED_LIBS=OFF",
      # CMake/folly-deps.cmake:43-95 fetches a missing package with FetchContent
      # (include at :46, MakeAvailable at :92). With this switch a miss is an
      # error, never a download. The OpenSSL ExternalProject (:383) is not
      # covered, but is reached only when OpenSSL is not found, and it is declared.
      "-DFETCHCONTENT_FULLY_DISCONNECTED=ON",
      # :98-102 the Python bindings; ON needs Cython and a shared build.
      "-DPYTHON_EXTENSIONS=OFF",
      # :422-423 tests and benchmarks default OFF; :445-453 GMock and GTest are
      # only probed when tests are on.
      "-DBUILD_TESTS=OFF",
      "-DBUILD_BENCHMARKS=OFF",

      # OPTIONAL PACKAGES, one switch each, cited at folly-deps.cmake:LINE. They
      # have no folly ON/OFF option; CMake's own CMAKE_DISABLE_FIND_PACKAGE_<Pkg>
      # makes find_package(<Pkg>) report not-found whatever the host has. The
      # ones found from this recipe's dependencies stay enabled (below), so
      # every `find_package` read in the file is either listed here or a
      # declared dependency.
      "-DCMAKE_DISABLE_FIND_PACKAGE_LibDwarf=ON", # :520
      "-DCMAKE_DISABLE_FIND_PACKAGE_Libiberty=ON", # :524
      "-DCMAKE_DISABLE_FIND_PACKAGE_LibAIO=ON", # :528
      "-DCMAKE_DISABLE_FIND_PACKAGE_LibUring=ON", # :532
      "-DCMAKE_DISABLE_FIND_PACKAGE_Libsodium=ON", # :536
      "-DCMAKE_DISABLE_FIND_PACKAGE_LibUnwind=ON", # :551
      "-DCMAKE_DISABLE_FIND_PACKAGE_Backtrace=ON", # :568
      # :548 Cython is only probed when PYTHON_EXTENSIONS is ON; disabled anyway.
      "-DCMAKE_DISABLE_FIND_PACKAGE_Cython=ON",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

test {
  script = [
    "test -f {{prefix}}/include/folly/Format.h",
    "test -f {{prefix}}/lib/cmake/folly/folly-config.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",          # :15 cmake 3.14; :91-102 BUILD_SHARED_LIBS and PYTHON_EXTENSIONS; :127-130 C++20; :422-453 tests, benchmarks, GMock/GTest
    "CMake/folly-deps.cmake",  # :43-95 FetchContent from a manifest when a package is missing; :122 Boost; :153 FastFloat; :174 Gflags; :204 Glog; :273 LibEvent; :310-513 ZLIB, OpenSSL, BZip2, LibLZMA, LZ4, Zstd, Snappy; :520-551 the optional ones; :701 fmt
    "LICENSE",                 # :2-3 Apache 2.0
  ]

  consulted = [
    "the previous fragment in this tree (versions of dependencies only)",
  ]

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt and CMake/folly-deps.cmake; the test
block only checks installed files and has not been run.

TWO THINGS THE FRAGMENT SAID THAT THIS RELEASE CONTRADICTS: it listed
google.com/double-conversion and googletest. `grep -rn "DoubleConversion\|
double-conversion"` over CMake/ and CMakeLists.txt of this tag finds nothing,
and tests are off. Both are dropped. The fragment's linux-only jemalloc and
elfutils were NOT confirmed either way (no find_package for them in the files
read) and are not declared.

NETWORK: folly-deps.cmake:43-95 FETCHES a missing Boost, FastFloat, gflags or
glog at configure time. They are declared dependencies and put on
CMAKE_PREFIX_PATH so they are found, and FETCHCONTENT_FULLY_DISCONNECTED=ON
turns a miss into a configure error. Not run, so not confirmed.

BOOST: "<1.89" is inherited from the fragment; the cap was not re-derived.
Folly asks for 1.69.0 or newer (:122).

Not read: folly-deps.cmake lines 204-300 (Glog, LibEvent probes) and 310-455
in detail, so how a found package is told to the build is taken from the
cited call sites only.
EOT
}
