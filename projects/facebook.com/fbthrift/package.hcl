# facebook.com/fbthrift — Facebook's branch of Apache Thrift (compiler and C++
# runtime).
#
# ⛔ WRITTEN FROM FBTHRIFT'S OWN FILES (go-zpkg/packages#440), at v2026.10.26.00.
# One date-like release is pinned across the stack (folly, fizz, wangle, mvfst,
# fbthrift, fb303, edencommon): 2026.10.26.00. v2026.11.09.00 and
# v2026.11.16.00 exist (`git ls-remote`) and are ignored.

summary = "fbthrift: Facebook's branch of Apache Thrift, with a C++ RPC framework"

# LICENSE:1-2 "Apache License / Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "facebook/fbthrift"
  ignore = ["/^v2026\\.(1[12])\\./"]
}

dependencies = {
  "boost.org"                         = "<1.89"
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
  url              = "https://github.com/facebook/fbthrift/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 19614995 bytes, `zpkb sourcepin`; an independent curl fetch hashed with
  # shasum gave the same digest (same GitHub generator: a check on the transfer).
  sha256 = {
    "2026.10.26.00" = "6ad18cfc24297120a536a0ef9c5a84f409c9aa4376057328e8dca9d45587d5a1"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
    "python.org"   = "~3.11"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_PREFIX_PATH={{deps.boost.org.prefix}};{{deps.facebook.com/folly.prefix}};{{deps.facebook.com/mvfst.prefix}};{{deps.facebook.com/wangle.prefix}};{{deps.facebook.com/zstd.prefix}};{{deps.fmt.dev.prefix}};{{deps.gflags.github.io.prefix}};{{deps.github.com/Cyan4973/xxHash.prefix}};{{deps.github.com/facebookincubator/fizz.prefix}};{{deps.github.com/fastfloat/fast_float.prefix}};{{deps.google.com/glog.prefix}};{{deps.google.github.io/snappy.prefix}};{{deps.libevent.org.prefix}};{{deps.libsodium.org.prefix}};{{deps.lz4.org.prefix}};{{deps.openssl.org.prefix}};{{deps.sourceware.org/bzip2.prefix}};{{deps.tukaani.org/xz.prefix}};{{deps.zlib.net.prefix}}",

      # NETWORK. CMakeLists.txt:124-139 (thrift_fetch_github, for folly, fizz,
      # wangle, mvfst), :194-200 (xxhash) are FetchContent, and :258-269 builds
      # libsodium with ExternalProject. With this switch a FetchContent miss is
      # an error. ExternalProject is not covered by it, but is reached only when
      # fizz is not found (:293-299), and fizz is a declared dependency.
      "-DFETCHCONTENT_FULLY_DISCONNECTED=ON",

      # :143-148 on macOS, an unset OPENSSL_ROOT_DIR is filled from `brew
      # --prefix openssl`: the host's. Set it to ours.
      "-DOPENSSL_ROOT_DIR={{deps.openssl.org.prefix}}",

      # :82-85 THRIFT_RPC is ON by default and is kept: thrift-cpp, the target
      # fb303 links, exists only under it (thrift/lib/cpp/CMakeLists.txt:36-95).
      "-DTHRIFT_RPC=ON",
      # :86-89 tests and benchmarks.
      "-DTHRIFT_TESTS=OFF",
      "-DTHRIFT_BENCHMARKS=OFF",
      # :92-93 thrift-python needs Cython (thrift/lib/python/CMakeLists.txt:49).
      "-DTHRIFT_PYTHON=OFF",
      # :90-91 the deprecated thrift-py is pure Python and is kept: edencommon
      # asks for the `py` component (CMakeLists.txt:81), which
      # thrift/cmake/FBThriftConfig.cmake.in:102 reports from this switch.
      "-DTHRIFT_PY_DEPRECATED=ON",
      "-DPython3_EXECUTABLE={{deps.python.org.prefix}}/bin/python3",
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
    "test -f {{prefix}}/lib/cmake/fbthrift/FBThriftConfig.cmake",
    "test -f {{prefix}}/include/thrift/ThriftLibrary.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                           # :15 cmake 3.24; :82-93 options; :124-139 and :194-200 FetchContent; :143-148 brew; :150-165 folly and required packages; :222 Xxhash; :233-281 libsodium ExternalProject; :285-320 fizz, wangle, mvfst; :335 thrift/
    "thrift/CMakeLists.txt",                    # :22-62 FBThriftConfig, Find modules and ThriftLibrary.cmake installed
    "thrift/cmake/FBThriftConfig.cmake.in",     # :31-47 dependencies re-found by consumers; :98-103 components
    "thrift/lib/CMakeLists.txt",                # :16 Boost; :22-28 python and py subdirectories
    "thrift/lib/cpp/CMakeLists.txt",            # :36-95 thrift-cpp under THRIFT_RPC
    "thrift/lib/py/CMakeLists.txt",             # :15-65 pure Python libraries
    "build/fbcode_builder/CMake/FBPythonBinary.cmake",  # :37-57 Python3 interpreter lookup
    "LICENSE",                                  # :1-2 Apache 2.0
  ]

  consulted = [
    "the previous fragment in this tree (versions of dependencies only)",
  ]

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt and the files listed. The test block only
checks installed files and has not been run.

NOT DONE: that the pure-Python THRIFT_PY_DEPRECATED install works with the
python.org prefix (FBPythonBinary.cmake:37-57 looks the interpreter up with
find_package(Python3 ...), whose Development component this recipe does not
verify; Python3_EXECUTABLE is passed to steer it). Turning THRIFT_PY_DEPRECATED
off would drop the `py` component edencommon asks for.

The fragment's double-conversion, libstdcxx and libcxx entries were not
confirmed by any find_package read and are dropped. mvfst was ADDED: with
THRIFT_RPC=ON it is required, and without it fbthrift fetches it and installs
nothing (:99-106).

The compiler is built here and installed as FBThrift::thrift when the targets
export it; this was not checked on an install.
EOT
}
