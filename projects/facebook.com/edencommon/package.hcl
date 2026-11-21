# facebook.com/edencommon — Eden's common C++ utilities (shared by EdenFS and
# Watchman).
#
# ⛔ WRITTEN FROM EDENCOMMON'S OWN FILES (go-zpkg/packages#440), at v2026.10.26.00.
# One date-like release is pinned across the stack (folly, fizz, wangle, mvfst,
# fbthrift, fb303, edencommon): 2026.10.26.00. v2026.11.09.00 and
# v2026.11.16.00 exist (`git ls-remote`) and are ignored.
#
# The repository is facebookexperimental/edencommon, not facebook/.

summary = "edencommon: common C++ utilities shared by EdenFS and Watchman"

# LICENSE:2 "MIT License".
license = "MIT"

versions {
  github = "facebookexperimental/edencommon"
  ignore = ["/^v2026\\.(1[12])\\./"]
}

dependencies = {
  "boost.org"                         = "<1.89"
  "facebook.com/fb303"                = "^2026"
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
  url              = "https://github.com/facebookexperimental/edencommon/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 415811 bytes, `zpkb sourcepin`; an independent curl fetch hashed with
  # shasum gave the same digest (same GitHub generator: a check on the transfer).
  sha256 = {
    "2026.10.26.00" = "08f5597c7ddbc79b6fca13bf97cf6f8ef4695a7ac6bc9d50c67cb8a435600d9a"
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
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_PREFIX_PATH={{deps.boost.org.prefix}};{{deps.facebook.com/fb303.prefix}};{{deps.facebook.com/fbthrift.prefix}};{{deps.facebook.com/folly.prefix}};{{deps.facebook.com/mvfst.prefix}};{{deps.facebook.com/wangle.prefix}};{{deps.facebook.com/zstd.prefix}};{{deps.fmt.dev.prefix}};{{deps.gflags.github.io.prefix}};{{deps.github.com/Cyan4973/xxHash.prefix}};{{deps.github.com/facebookincubator/fizz.prefix}};{{deps.github.com/fastfloat/fast_float.prefix}};{{deps.google.com/glog.prefix}};{{deps.google.github.io/snappy.prefix}};{{deps.libevent.org.prefix}};{{deps.libsodium.org.prefix}};{{deps.lz4.org.prefix}};{{deps.openssl.org.prefix}};{{deps.sourceware.org/bzip2.prefix}};{{deps.tukaani.org/xz.prefix}};{{deps.zlib.net.prefix}}",

      # edencommon's CMakeLists.txt has no FetchContent (it tests *_SOURCE_DIR,
      # :60-82). Set for the whole stack: a miss is an error, never a download.
      "-DFETCHCONTENT_FULLY_DISCONNECTED=ON",

      # :87-96 GMock is REQUIRED when BUILD_TESTS is set, and otherwise probed
      # with `find_package(GMock MODULE QUIET)`: the test harness is built
      # "whenever GMock is available". Tests are off and the probe is disabled,
      # so the host cannot add the harness.
      "-DBUILD_TESTS=OFF",
      "-DCMAKE_DISABLE_FIND_PACKAGE_GMock=ON", # :92
      "-DBUILD_SHARED_LIBS=OFF",

      # :81 find_package(FBThrift ... COMPONENTS cpp2 py) runs fbthrift's
      # FBThriftConfig.cmake, which resolves its own Find modules; the Python
      # interpreter is the python.org build dependency.
      "-DPython3_EXECUTABLE={{deps.python.org.prefix}}/bin/python3",
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
    "test -f {{prefix}}/lib/cmake/edencommon/edencommon-config.cmake",
    "test -f {{prefix}}/include/eden/common/utils/PathFuncs.h",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",   # :8 cmake 3.8; :14 C++20; :35 install dir; :53-83 Glog, Gflags, folly, Boost 1.69 filesystem, fb303, wangle, FBThrift cpp2 py; :87-96 GMock; :98-103 subdirectories; :113-128 install
    "LICENSE",          # :2 MIT
  ]

  consulted = [
    "the previous fragment in this tree (versions of dependencies only)",
  ]

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt. The test block only checks installed
files and has not been run.

THE FRAGMENT SAID facebook.com/mvfst was needed: nothing in edencommon's
CMakeLists.txt mentions it. It is declared here only because fbthrift's
FBThriftConfig.cmake.in calls find_package(mvfst CONFIG), which edencommon
reaches through find_package(FBThrift).

Python3_EXECUTABLE is passed to steer the lookup made in fbthrift's
FBPythonBinary.cmake:37-57, if the config reaches it; this was not verified.
Not read: the CMakeLists.txt of the eden/common subdirectories, so the
libraries they link are taken from the top-level find_package calls only, and
the lines 104-128 install block beyond the config file names.
EOT
}
