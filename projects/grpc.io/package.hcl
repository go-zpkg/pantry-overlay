# gRPC — the RPC framework: the C core, the C++ library (grpc++) and the code
# generator plugins for protoc.
#
# ⛔ WRITTEN WHOLE FROM gRPC'S OWN FILES at 1.85.4 (go-zpkg/packages#440).
# It was a 28-line overlay whose one purpose was to move openssl off ^1.1.
# Its dependency set is KEPT, with the reasoning of its comments:
#
# ⛔ THE PINS TRACK THE PANTRY, AND MOVE TOGETHER. Upstream moved abseil to
# ^20260526 for grpc 1.85 (Mutex::lock, MutexLock(Mutex&)). Upstream's own
# comment: re2 and protobuf must be built against the same abseil LTS line,
# and protobuf 36.2.0 is the build against 20260526 — earlier artifacts use
# 20250512 or 20250127 and mangle differently. Bumping abseil alone would
# satisfy a check and break the invariant it exists to protect.
#
# protobuf.dev is now stated on every platform and not only on linux, because
# gRPC_PROTOBUF_PROVIDER=package below needs it everywhere.

summary = "RPC framework: C core, C++ library and protoc plugins"

# LICENSE is the Apache License 2.0 (the text opens "Apache License / Version
# 2.0, January 2004").
license = "Apache-2.0"

versions {
  # v1.86.0-pre1 is a prerelease tag.
  github = "grpc/grpc"
  strip  = "/^v/"
  ignore = ["/pre|rc|alpha|beta/"]
}

dependencies = {
  "abseil.io"             = "^20260526"
  "c-ares.org"            = "*"
  "github.com/google/re2" = "*"
  linux = {
    "gnu.org/gcc/libstdcxx" = 14
  }
  "openssl.org"  = "^3"
  "protobuf.dev" = "36.2.0"
  "zlib.net"     = "*"
}

distributable {
  # ⛔ A GENERATED ARCHIVE, AND IT IS FRAGILE. gRPC's GitHub releases store NO
  # assets (checked at v1.85.4: the release lists only the two source archives
  # GitHub generates), so the tag archive is the only tarball. GitHub does not
  # promise those bytes stay the same across a change of its archiver; the pin
  # below is what refuses a silent change.
  url              = "https://github.com/grpc/grpc/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 16352601 bytes, fetched twice with `zpkb sourcepin`; both fetches gave the
  # same digest, but BOTH were from github.com: there is no second host and no
  # signature. The tag archive does not contain the submodules' contents
  # (third_party/envoy-api, googleapis and xds are empty directories in it).
  sha256 = {
    "1.85.4" = "e2382869a2837e2e4f9d5ad291ae8e4b256d44def4d6839c2930a9f7b433249a"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
  }

  env {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCMAKE_CXX_STANDARD=17",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",

      # ⛔ EVERY THIRD-PARTY LIBRARY FROM THE PANTRY. CMakeLists.txt:66-89 sets
      # each gRPC_*_PROVIDER to "module" by default, which builds from a
      # submodule directory that the tag archive leaves EMPTY. "package" makes
      # cmake/zlib.cmake:48, cares.cmake:38, re2.cmake:44, ssl.cmake:64,
      # abseil-cpp.cmake:35 and protobuf.cmake:54 call find_package.
      "-DgRPC_ZLIB_PROVIDER=package",
      "-DgRPC_CARES_PROVIDER=package",
      "-DgRPC_RE2_PROVIDER=package",
      "-DgRPC_SSL_PROVIDER=package",
      "-DgRPC_PROTOBUF_PROVIDER=package",
      "-DgRPC_ABSL_PROVIDER=package",
      "-DCMAKE_PREFIX_PATH={{deps.abseil.io.prefix}};{{deps.c-ares.org.prefix}};{{deps.github.com/google/re2.prefix}};{{deps.openssl.org.prefix}};{{deps.protobuf.dev.prefix}};{{deps.zlib.net.prefix}}",

      # ⛔ NEVER DOWNLOAD. CMakeLists.txt:52 gRPC_DOWNLOAD_ARCHIVES defaults ON
      # and, for each EMPTY third_party directory (:408-483: autosharding,
      # cel-spec, envoy-api, googleapis, grpc-proto, protoc-gen-validate, xds),
      # fetches an archive over HTTP at configure time.
      "-DgRPC_DOWNLOAD_ARCHIVES=OFF",

      # :50 tests off (the default); :45-59 install on.
      "-DgRPC_BUILD_TESTS=OFF",
      "-DgRPC_INSTALL=ON",
      "-DBUILD_SHARED_LIBS=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{hw.concurrency}}",
    "cmake --install build",
  ]
}

# The plugin executables CMakeLists.txt:639-663 builds by default and
# :20449-20760 installs to bin/.
provides = [
  "bin/grpc_cpp_plugin",
  "bin/grpc_csharp_plugin",
  "bin/grpc_node_plugin",
  "bin/grpc_objective_c_plugin",
  "bin/grpc_php_plugin",
  "bin/grpc_python_plugin",
  "bin/grpc_ruby_plugin",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/grpcpp/grpcpp.h",
    "test -f {{prefix}}/lib/cmake/grpc/gRPCConfig.cmake",
    "pkg-config --exists grpc++",
    "test -x {{prefix}}/bin/grpc_cpp_plugin",
  ]
}

provenance {
  read = [
    "CMakeLists.txt", # :45-59 options; :62-89 providers; :408-483 download of empty third_party dirs; :639-663 plugins; :57482-57543 install
    "cmake/re2.cmake", # :44 find_package(re2 REQUIRED), config mode
    "cmake/cares.cmake", # :38 find_package(c-ares 1.13.0 REQUIRED)
    "cmake/zlib.cmake", # :48
    "cmake/ssl.cmake", # :64
    "cmake/abseil-cpp.cmake", # :35 find_package(absl REQUIRED CONFIG)
    "cmake/protobuf.cmake", # :54 find_package(Protobuf REQUIRED CONFIG)
    "LICENSE", # Apache 2.0
  ]

  consulted = [
    "https://github.com/grpc/grpc/releases/tag/v1.85.4 (lists no stored assets: only the generated source archives)",
  ]

  note = <<EOT
NOT BUILT. Written from the project's files and linted; no build or test of
this recipe was run.

The source is the GENERATED tag archive, pinned by sha256 from two fetches of
the same host: gRPC stores no release assets and signs nothing.

Depends on the re2 and c-ares recipes installing their CMake package configs
(re2Config.cmake, c-ares-config.cmake), which they now do (go-zpkg/recipes#319).
Unverified: the install paths of gRPCConfig.cmake and the pkg-config file names
used in the test (grpc++), read from CMakeLists.txt:57482-57543 only.
EOT
}
