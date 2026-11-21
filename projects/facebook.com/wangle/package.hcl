# facebook.com/wangle — Facebook's C++ networking library (client/server
# abstractions built on folly).
#
# ⛔ WRITTEN FROM WANGLE'S OWN FILES (go-zpkg/packages#440), at v2026.10.26.00.
# One date-like release is pinned across the stack (folly, fizz, wangle, mvfst,
# fbthrift, fb303, edencommon): 2026.10.26.00, the newest tag folly has. The
# v2026.11.09.00 and v2026.11.16.00 tags are ignored (`git ls-remote` shows them).

summary = "Wangle: a C++ framework for building asynchronous network clients and servers"

# LICENSE:2-3 "Apache License / Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "facebook/wangle"
  ignore = ["/^v2026\\.(1[12])\\./"]
}

dependencies = {
  "boost.org"                         = "<1.89"
  "facebook.com/folly"                = "^2026"
  "facebook.com/zstd"                 = "^1"
  "fmt.dev"                           = "^12"
  "gflags.github.io"                  = "^2.2"
  "github.com/facebookincubator/fizz" = "^2026"
  "github.com/fastfloat/fast_float"   = "^8"
  "google.com/glog"                   = "^0.7"
  "google.github.io/snappy"           = "^1"
  "libevent.org"                      = "^2"
  "libsodium.org"                     = "^1"
  "lz4.org"                           = "^1"
  "openssl.org"                       = "^3"
  "sourceware.org/bzip2"              = "^1"
  "tukaani.org/xz"                    = "^5"
  "zlib.net"                          = "^1"
}

distributable {
  url              = "https://github.com/facebook/wangle/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 455848 bytes, `zpkb sourcepin`; an independent curl fetch hashed with
  # shasum gave the same digest (same GitHub generator: a check on the transfer).
  sha256 = {
    "2026.10.26.00" = "5c482135fbea0ca6359c2093f1b725e5abfbed205fa59cecb0ed2fb9234cfbf3"
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
      "-DCMAKE_PREFIX_PATH={{deps.boost.org.prefix}};{{deps.facebook.com/folly.prefix}};{{deps.facebook.com/zstd.prefix}};{{deps.fmt.dev.prefix}};{{deps.gflags.github.io.prefix}};{{deps.github.com/facebookincubator/fizz.prefix}};{{deps.github.com/fastfloat/fast_float.prefix}};{{deps.google.com/glog.prefix}};{{deps.google.github.io/snappy.prefix}};{{deps.libevent.org.prefix}};{{deps.libsodium.org.prefix}};{{deps.lz4.org.prefix}};{{deps.openssl.org.prefix}};{{deps.sourceware.org/bzip2.prefix}};{{deps.tukaani.org/xz.prefix}};{{deps.zlib.net.prefix}}",

      # wangle/CMakeLists.txt has no FetchContent of its own (it only tests
      # folly_SOURCE_DIR / fizz_SOURCE_DIR, :72-78). Set for the whole stack: a
      # miss is an error, never a download (folly-deps.cmake:43-95 fetches).
      "-DFETCHCONTENT_FULLY_DISCONNECTED=ON",

      # wangle/CMakeLists.txt:245-247 BUILD_TESTS defaults ON (OFF only when
      # cross-compiling); :250-253 it then looks for GMock.
      "-DBUILD_TESTS=OFF",
      # :354 BUILD_EXAMPLES defaults OFF; stated.
      "-DBUILD_EXAMPLES=OFF",
      "-DBUILD_SHARED_LIBS=OFF",
    ]
  }

  script = [
    "cmake -S wangle -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

test {
  script = [
    "test -f {{prefix}}/lib/cmake/wangle/wangle-config.cmake",
    "test -f {{prefix}}/include/wangle/bootstrap/ServerBootstrap.h",
  ]
}

provenance {
  read = [
    "wangle/CMakeLists.txt",             # :15 cmake 3.14; :36 C++20; :72-113 folly, fizz, fmt, OpenSSL, Glog, gflags, LibEvent, Threads, Librt; :245-253 tests; :354 examples
    "LICENSE",                           # :2-3 Apache 2.0
  ]

  consulted = [
    "the previous fragment in this tree (versions of dependencies only)",
  ]

  note = <<EOT
NOT BUILT. Written from wangle/CMakeLists.txt. The CMake project is in the
wangle/ subdirectory of the tarball, hence `-S wangle`. The test block only
checks installed files and has not been run (ServerBootstrap.h is assumed from
the source layout).

No optional find_package: every one read (:72-113) is REQUIRED or a declared
dependency. Librt (:111-113, linux only) belongs to the C library. The
fragment's double-conversion, boost-as-direct and linux-only libstdcxx entries
were not confirmed by any find_package in the file and are dropped; boost,
zstd, fast_float, snappy, lz4, bzip2, xz and zlib stay because folly-config.cmake
finds them again for every consumer of folly.
EOT
}
