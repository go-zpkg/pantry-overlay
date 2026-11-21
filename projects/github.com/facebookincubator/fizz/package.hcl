# github.com/facebookincubator/fizz — Facebook's TLS 1.3 implementation in C++.
#
# ⛔ WRITTEN FROM FIZZ'S OWN FILES (go-zpkg/packages#440), at v2026.10.26.00.
# One date-like release is pinned across the stack (folly, fizz, wangle, mvfst,
# fbthrift, fb303, edencommon): 2026.10.26.00, the newest tag folly has. Newer
# fizz tags are ignored so that `versions` resolves to the pinned one and the
# stack is built from one snapshot.

summary = "Fizz: a C++14 implementation of the TLS 1.3 protocol"

# LICENSE:1-17 "BSD License", three clauses (the third: "Neither the name
# Facebook nor the names of its contributors may be used to endorse").
license = "BSD-3-Clause"

versions {
  github = "facebookincubator/fizz"
  ignore = ["/^v2026\\.(1[12])\\./"]
}

dependencies = {
  "boost.org"                       = "<1.89"
  "facebook.com/folly"              = "^2026"
  "facebook.com/zstd"               = "^1"
  "fmt.dev"                         = "^12"
  "gflags.github.io"                = "^2.2"
  "github.com/fastfloat/fast_float" = "^8"
  "google.com/glog"                 = "^0.7"
  "google.github.io/snappy"         = "^1"
  "libevent.org"                    = "^2"
  "libsodium.org"                   = "^1"
  "lz4.org"                         = "^1"
  "openssl.org"                     = "^3"
  "sourceware.org/bzip2"            = "^1"
  "tukaani.org/xz"                  = "^5"
  "zlib.net"                        = "^1"
}

distributable {
  # No release assets, so the generated tag archive.
  url              = "https://github.com/facebookincubator/fizz/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 876356 bytes, `zpkb sourcepin`; an independent curl fetch hashed with
  # shasum gave the same digest (same GitHub generator: a check on the transfer).
  sha256 = {
    "2026.10.26.00" = "3f481c7157e91ff3dbede77290db539355f297db73f74593c81bf7c602229ebe"
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
      "-DCMAKE_PREFIX_PATH={{deps.boost.org.prefix}};{{deps.facebook.com/folly.prefix}};{{deps.facebook.com/zstd.prefix}};{{deps.fmt.dev.prefix}};{{deps.gflags.github.io.prefix}};{{deps.github.com/fastfloat/fast_float.prefix}};{{deps.google.com/glog.prefix}};{{deps.google.github.io/snappy.prefix}};{{deps.libevent.org.prefix}};{{deps.libsodium.org.prefix}};{{deps.lz4.org.prefix}};{{deps.openssl.org.prefix}};{{deps.sourceware.org/bzip2.prefix}};{{deps.tukaani.org/xz.prefix}};{{deps.zlib.net.prefix}}",

      # No FetchContent or ExternalProject appears in fizz/CMakeLists.txt (read
      # whole up to :130 and :320-353). Set anyway, for the same switch in every
      # recipe of this stack: a miss is an error, never a download
      # (folly's CMake/folly-deps.cmake:43-95 does fetch).
      "-DFETCHCONTENT_FULLY_DISCONNECTED=ON",

      # fizz/CMakeLists.txt:343-346 BUILD_TESTS defaults ON (OFF only when
      # cross-compiling); :350-353 it then requires GMock and GTest.
      "-DBUILD_TESTS=OFF",
      # :488 BUILD_EXAMPLES defaults ON.
      "-DBUILD_EXAMPLES=OFF",
      # cmake/FizzOptions.cmake:4 and :9-16 are fizz's own switches; the
      # defaults (OpenSSL certificates, glog backend) are what the declared
      # dependencies serve, and are kept.
      "-DBUILD_SHARED_LIBS=OFF",

      # OPTIONAL PACKAGES: CMake's own CMAKE_DISABLE_FIND_PACKAGE_<Pkg> makes the
      # find_package report not-found whatever the host has.
      "-DCMAKE_DISABLE_FIND_PACKAGE_liboqs=ON", # fizz/CMakeLists.txt:118 (FIZZ_HAVE_OQS)
      "-DCMAKE_DISABLE_FIND_PACKAGE_aegis=ON", # :123 (FIZZ_HAVE_LIBAEGIS)
    ]
  }

  script = [
    "cmake -S fizz -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

test {
  script = [
    "test -f {{prefix}}/lib/cmake/fizz/fizz-config.cmake",
    "test -f {{prefix}}/include/fizz/protocol/Protocol.h",
  ]
}

provenance {
  read = [
    "fizz/CMakeLists.txt",                    # :4 cmake 3.14; :21-26 C++20; :56-126 every find_package; :337-353 export, BUILD_TESTS; :488 BUILD_EXAMPLES
    "fizz/cmake/FizzOptions.cmake",           # :4-16 certificate and logging options
    "fizz/cmake/fizz-config.cmake.in",        # :35-42 what a consumer must find again (Sodium, folly, ZLIB; liboqs and aegis only if built in)
    "LICENSE",                                # :1-17 BSD, three clauses
  ]

  consulted = [
    "the previous fragment in this tree (versions of dependencies only)",
  ]

  note = <<EOT
NOT BUILT. Written from fizz/CMakeLists.txt; the test block only checks
installed files and has not been run (Protocol.h is assumed from the source
tree layout, not listed).

mvfst is NOT needed: nothing in fizz's CMake mentions it (mvfst needs fizz, the
other way round). The CMake project lives in the fizz/ subdirectory of the
tarball, hence `-S fizz`.

Librt (fizz/CMakeLists.txt:73-75, linux only) is part of the C library and is
left to the host's libc, not to a recipe. Sodium is found through fbcode_builder's
FindSodium module; the libsodium prefix is on CMAKE_PREFIX_PATH.
Folly's own dependencies (boost, fast_float, snappy, lz4, bzip2, xz, zstd...)
are listed because folly-config.cmake finds them again for every consumer.
EOT
}
