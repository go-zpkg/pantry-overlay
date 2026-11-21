# Protocol Buffers — Google's language-neutral serialisation format, with the
# protoc compiler and the C++ runtime (libprotobuf, libprotoc).
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1). It is a dependency of grpc.io, and no recipe existed.

summary = "Protocol Buffers: protoc compiler and C++ runtime"

# LICENSE: three-clause BSD ("Neither the name of Google Inc."), copyright
# Google Inc.
license = "BSD-3-Clause"

dependencies = {
  "abseil.io" = "*"
  "zlib.net"  = "^1"
}

versions {
  # Tags are v<major>.<minor> (v36.2); release candidates (v37.0-rc3) are
  # published as pre-releases, which the ignore below leaves out.
  github = "protocolbuffers/protobuf"
  ignore = ["/rc/"]
}

distributable {
  # THE STORED RELEASE ASSET protobuf-<version>.bazel.tar.gz, and that is a
  # choice: the release also stores protobuf-<version>.tar.gz, but only the
  # .bazel.tar.gz has an independent witness. Its file list was compared with
  # the plain tarball's and is identical at the top level (CMakeLists.txt and
  # cmake/ are in both).
  url              = "https://github.com/protocolbuffers/protobuf/releases/download/v{{version.raw}}/protobuf-{{version.raw}}.bazel.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin` (7349754 bytes). The project publishes no
  # detached signature and no checksum file. TWO WITNESSES, both agreeing:
  #   - the release's protobuf-36.2.bazel.tar.gz.intoto.jsonl (a Sigstore bundle
  #     holding a SLSA in-toto statement) names this file as its only subject
  #     with sha256 9ce44c3890ee93f8f403db2198ebd711fcf8beae3d13f18a36f5bc1458748f40;
  #   - the Bazel Central Registry records "sha256-nORMOJDuk/j0A9shmOvXEfz4vq49E/GKNvW8FFh0j0A="
  #     for the same URL in modules/protobuf/36.2/source.json, which decodes to
  #     the same hex.
  #
  # ⛔ WHAT THAT PROVES: the in-toto subject digest was READ from the statement;
  # the Sigstore signature and certificate chain over it were NOT verified, so
  # it is a statement the project published next to the file, not a verified
  # signature. The registry is a third party's record of the digest it saw.
  sha256 = {
    "36.2" = "9ce44c3890ee93f8f403db2198ebd711fcf8beae3d13f18a36f5bc1458748f40"
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

      # Abseil and zlib are found by find_package (cmake/abseil-cpp.cmake:16,
      # CMakeLists.txt:200), so their prefixes go on CMAKE_PREFIX_PATH.
      "-DCMAKE_PREFIX_PATH={{deps.abseil.io.prefix}};{{deps.zlib.net.prefix}}",

      # ⛔ NEVER DOWNLOAD. Without these, a missing Abseil makes cmake fall back
      # to a git clone of GitHub at configure time (cmake/abseil-cpp.cmake:19-36),
      # an unpinned fetch. LOCAL_DEPENDENCIES_ONLY (CMakeLists.txt:44) makes that
      # a configure error instead.
      "-Dprotobuf_LOCAL_DEPENDENCIES_ONLY=ON",
      "-Dprotobuf_FORCE_FETCH_DEPENDENCIES=OFF",

      # ⛔ STATIC, POSITION-INDEPENDENT, AND THAT IS A DECISION. The default is
      # static (CMakeLists.txt:48-53 follows BUILD_SHARED_LIBS, off); Abseil is
      # built the same way, and gRPC links this copy into its own libraries.
      "-DBUILD_SHARED_LIBS=OFF",
      "-Dprotobuf_BUILD_SHARED_LIBS=OFF",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
      "-DCMAKE_CXX_STANDARD=17",

      # CMakeLists.txt:31-38: install on; tests, conformance and examples off
      # (they need GoogleTest); protoc and libprotoc on, because gRPC's plugins
      # link libprotoc.
      "-Dprotobuf_INSTALL=ON",
      "-Dprotobuf_BUILD_TESTS=OFF",
      "-Dprotobuf_BUILD_CONFORMANCE=OFF",
      "-Dprotobuf_BUILD_EXAMPLES=OFF",
      "-Dprotobuf_BUILD_PROTOC_BINARIES=ON",
      "-Dprotobuf_BUILD_LIBPROTOC=ON",
      "-Dprotobuf_BUILD_LIBUPB=ON",
      "-Dprotobuf_DISABLE_RTTI=OFF",

      # :58 ON is the default. ⛔ find_package(ZLIB) at :200 is NOT REQUIRED, so a
      # zlib that is not found turns compression off silently instead of failing.
      "-Dprotobuf_WITH_ZLIB=ON",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{hw.concurrency}}",
    "cmake --install build",
  ]
}

# cmake/installed_bin_golden.txt lists what a build installs in bin/: protoc and
# the three protoc-gen-upb* plugins.
provides = [
  "bin/protoc",
  "bin/protoc-gen-upb",
  "bin/protoc-gen-upb_minitable",
  "bin/protoc-gen-upbdefs",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  env {
    PKG_CONFIG_PATH = "{{prefix}}/lib/pkgconfig:{{deps.abseil.io.prefix}}/lib/pkgconfig:{{deps.zlib.net.prefix}}/lib/pkgconfig"
  }

  script = [
    "test -f {{prefix}}/include/google/protobuf/message.h",
    "protoc --version",
    "pkg-config --exists protobuf",
    {
      # Compile a message definition to C++ with the installed protoc.
      fixture = {
        content  = <<EOT
syntax = "proto3";

package zpkgtest;

message Ping {
  string name = 1;
  int32 count = 2;
}
EOT
        extname = "proto"
      }
      run = "cp $FIXTURE ping.proto && protoc --cpp_out=. ping.proto && test -f ping.pb.h && test -f ping.pb.cc"
    },
    "protoc --version",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                  # :31-58 options; :94 version; :124 libprotoc; :199-218 zlib; :307 abseil
    "cmake/abseil-cpp.cmake",          # :13-41 find_package(absl) then a GitHub fetch fallback
    "cmake/installed_bin_golden.txt",  # protoc and the protoc-gen-upb plugins
    "cmake/installed_lib_static_golden.txt", # libprotobuf, libprotoc, libupb, pkgconfig files
    "LICENSE",                         # three-clause BSD
  ]

  consulted = [
    "https://github.com/protocolbuffers/protobuf/releases/download/v36.2/protobuf-36.2.bazel.tar.gz.intoto.jsonl",
    "https://raw.githubusercontent.com/bazelbuild/bazel-central-registry/main/modules/protobuf/36.2/source.json",
  ]

  note = <<EOT
NOT BUILT: written from the sources and the stored release asset; not run on a
builder. The Bazel build the project also ships was not used. The test compiles
a .proto with protoc but does not link libprotobuf.
EOT
}
