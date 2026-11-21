# facebook.com/mvfst — Facebook's C++ implementation of QUIC.
#
# ⛔ WRITTEN FROM MVFST'S OWN FILES (go-zpkg/packages#440), at v2026.10.26.00.
# Written because fbthrift's CMakeLists.txt:82-85 and :285-319 (THRIFT_RPC, ON by
# default) needs an installed mvfst: without one it FETCHES mvfst and then turns
# off every install rule (:99-106, :315-319), and fb303 needs the RPC targets.
#
# One date-like release is pinned across the stack (folly, fizz, wangle, mvfst,
# fbthrift, fb303, edencommon): 2026.10.26.00. v2026.11.09.00 and
# v2026.11.16.00 exist (`git ls-remote`) and are ignored.

summary = "mvfst: an implementation of the QUIC transport protocol in C++"

# LICENSE:1 "MIT License".
license = "MIT"

versions {
  github = "facebook/mvfst"
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
  url              = "https://github.com/facebook/mvfst/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1729779 bytes, `zpkb sourcepin`; an independent curl fetch hashed with
  # shasum gave the same digest (same GitHub generator: a check on the transfer).
  sha256 = {
    "2026.10.26.00" = "7b2f2a84a5df3689d29a2c3c482b508e1d26251d568e9faf0ced22fb113e6dcd"
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

      # mvfst's CMakeLists.txt has no FetchContent (it tests folly_SOURCE_DIR and
      # fizz_SOURCE_DIR, :54-59). Set for the whole stack: a miss is an error.
      "-DFETCHCONTENT_FULLY_DISCONNECTED=ON",

      # CMakeLists.txt:136 BUILD_TESTS (no option(): undefined means off; stated);
      # quic/CMakeLists.txt:175 BUILD_SAMPLES.
      "-DBUILD_TESTS=OFF",
      "-DBUILD_SAMPLES=OFF",
      "-DBUILD_SHARED_LIBS=OFF",

      # CMakeLists.txt:65-69: haberdashery is an option, default OFF; stated.
      "-DMVFST_USE_HABERDASHERY=OFF",
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
    "test -f {{prefix}}/lib/cmake/mvfst/mvfst-config.cmake",
    "test -f {{prefix}}/include/quic/QuicConstants.h",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                # :6 cmake 3.14; :19 C++20; :51-93 Boost headers, fmt, folly, Fizz, Glog, Threads, OpenSSL, haberdashery, gflags; :136 BUILD_TESTS; :141 quic/; :181-200 install
    "cmake/mvfst-config.cmake.in",   # :20-24 what a consumer finds again: folly, Fizz, Threads (haberdashery only if built in)
    "LICENSE",                       # :1 MIT
  ]

  consulted = []

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt. The names of the installed config file
and header in the test block were derived from :36 (CMAKE_INSTALL_MODULE_DIR =
lib/cmake/mvfst) and the source tree (quic/QuicConstants.h exists); they have
not been checked on an install.

Boost is used for headers only (CMakeLists.txt:50). The
`find_package(Fizz)` at :58 uses a capitalised name; CMake's config-file search
reads fizz-config.cmake for it, which fizz installs.
EOT
}
