# facebook.com/fb303 — Facebook's base Thrift service and counters library.
#
# ⛔ WRITTEN FROM FB303'S OWN FILES (go-zpkg/packages#440), at v2026.10.26.00.
# One date-like release is pinned across the stack (folly, fizz, wangle, mvfst,
# fbthrift, fb303, edencommon): 2026.10.26.00. v2026.11.09.00 and
# v2026.11.16.00 exist (`git ls-remote`) and are ignored.

summary = "fb303: Facebook's base Thrift service and runtime counters library"

# LICENSE:2-3 "Apache License / Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "facebook/fb303"
  ignore = ["/^v2026\\.(1[12])\\./"]
}

dependencies = {
  "boost.org"                         = "<1.89"
  "facebook.com/fbthrift"             = "^2026"
  "facebook.com/folly"                = "^2026"
  "facebook.com/mvfst"                = "^2026"
  "facebook.com/wangle"               = "^2026"
  "facebook.com/zstd"                 = "^1"
  "fmt.dev"                           = "^12"
  "gflags.github.io"                  = "^2.2"
  "github.com/Cyan4973/xxHash"        = "^0.8"
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
  url              = "https://github.com/facebook/fb303/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 363073 bytes, `zpkb sourcepin`; an independent curl fetch hashed with
  # shasum gave the same digest (same GitHub generator: a check on the transfer).
  sha256 = {
    "2026.10.26.00" = "1cd7202240e7cca34db5c57d20d8a3fffc13c99452b475fbf1d72bf5274dbaf9"
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
      "-DCMAKE_PREFIX_PATH={{deps.boost.org.prefix}};{{deps.facebook.com/fbthrift.prefix}};{{deps.facebook.com/folly.prefix}};{{deps.facebook.com/mvfst.prefix}};{{deps.facebook.com/wangle.prefix}};{{deps.facebook.com/zstd.prefix}};{{deps.fmt.dev.prefix}};{{deps.gflags.github.io.prefix}};{{deps.github.com/Cyan4973/xxHash.prefix}};{{deps.github.com/facebookincubator/fizz.prefix}};{{deps.github.com/fastfloat/fast_float.prefix}};{{deps.google.com/glog.prefix}};{{deps.google.github.io/snappy.prefix}};{{deps.libevent.org.prefix}};{{deps.libsodium.org.prefix}};{{deps.lz4.org.prefix}};{{deps.openssl.org.prefix}};{{deps.sourceware.org/bzip2.prefix}};{{deps.tukaani.org/xz.prefix}};{{deps.zlib.net.prefix}}",

      # fb303's CMakeLists.txt has no FetchContent (it tests *_SOURCE_DIR,
      # :62-80). Set for the whole stack: a miss is an error, never a download.
      "-DFETCHCONTENT_FULLY_DISCONNECTED=ON",

      # :27-30 PYTHON_EXTENSIONS is ON by default; fb303/thrift/CMakeLists.txt:15
      # and :56 gate the Python bindings on it.
      "-DPYTHON_EXTENSIONS=OFF",
      "-DBUILD_SHARED_LIBS=OFF",
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
    "test -f {{prefix}}/lib/cmake/fb303/fb303-config.cmake",
    "test -f {{prefix}}/include/fb303/ExportType.h",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                 # :15 cmake 3.14; :27-30 PYTHON_EXTENSIONS; :33 C++20; :49 install dir; :57-84 Gflags, Glog, folly, Threads, fmt, FBThrift, fizz, wangle; :89-140 install
    "fb303/thrift/CMakeLists.txt",    # :15 and :56 the Python-bindings branches (the rest not read)
    "LICENSE",                        # :2-3 Apache 2.0
  ]

  consulted = [
    "the previous fragment in this tree (versions of dependencies only)",
  ]

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt. The test block only checks installed
files and has not been run.

fb303 never calls find_package(mvfst) itself; mvfst is declared because
FBThriftConfig.cmake.in (fbthrift) calls find_package(mvfst CONFIG) and the
exported thrift targets may link it. fizz and wangle are REQUIRED at :75-80.
xxHash is declared because FBThriftConfig.cmake.in resolves Xxhash, Gflags, Glog
and Zstd in MODULE mode for every consumer. No optional find_package is present
in the file. Not read: fb303/thrift/CMakeLists.txt beyond the two Python
branches, nor fb303/CMake/fb303-config.cmake.in (find_dependency lines: none
found by grep).
EOT
}
