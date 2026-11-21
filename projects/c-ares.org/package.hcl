# c-ares — asynchronous DNS resolver library (the resolver gRPC uses).
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1). It is a dependency of grpc.io, and no recipe existed.

summary = "Asynchronous DNS resolver library"

# LICENSE.md opens "MIT License".
license = "MIT"

versions {
  github = "c-ares/c-ares"
  ignore = ["/beta|alpha|rc/"]
}

distributable {
  # THE STORED RELEASE ASSET, not the generated tag archive: the release
  # uploads c-ares-<version>.tar.gz and its detached signature
  # c-ares-<version>.tar.gz.asc. The tarball ships `configure`, so no autotools
  # are needed.
  url              = "https://github.com/c-ares/c-ares/releases/download/v{{version.raw}}/c-ares-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin --sig auto` (1083895 bytes). The signature is
  # VALID and made by DA7D64E4C82C6294CB73A20E22E3D13B5411B7CA (Brad House
  # <brad@brad-house.com>; the .asc names the signing subkey
  # 75EB6CA0E63E90C4FF2C868FC1D15611B2E4720B, which belongs to that primary).
  # The key is https://github.com/bradh352.gpg, the maintainer's GitHub key
  # list, fetched from there and not from a keyserver. The signature URL is
  # https://github.com/c-ares/c-ares/releases/download/v1.34.9/c-ares-1.34.9.tar.gz.asc
  #
  # ⛔ WHERE THE FINGERPRINT CAME FROM: the identity is Brad House's GitHub
  # account page, not a document published by the c-ares project. The release
  # also carries c-ares-1.34.9.intoto.jsonl (SLSA provenance), which was not
  # checked.
  sha256 = {
    "1.34.9" = "9364b70a12eb59a06830fb488d9357f90100dff0d98b23ea3593a183d43e6f2f"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
  }

  env {
    # ⛔ THE PROJECT'S CMAKE BUILD, NOT AUTOTOOLS: only CMakeLists.txt:793-804
    # installs c-ares-config.cmake, c-ares-config-version.cmake and the
    # c-ares::cares targets, and gRPC's `find_package(c-ares 1.13.0 REQUIRED)`
    # (cmake/cares.cmake:38) is a config-mode search that the autotools build
    # cannot satisfy. libcares.pc is installed too (:814-815).
    #
    # Options (CMakeLists.txt:36-47):
    #   CARES_STATIC=ON / CARES_SHARED=ON   both, as the autotools recipe built
    #   CARES_STATIC_PIC=ON                 :39 default OFF; the static copy is
    #                                       linked into shared objects
    #   CARES_SYMBOL_HIDING=ON              :43 default OFF
    #   CARES_THREADS=ON                    :44 thread safety, the default
    #   CARES_BUILD_TESTS=OFF               :40 the GoogleTest suite
    #   CARES_BUILD_TOOLS=OFF               :42 default ON; the autotools build
    #                                       kept ahost and adig out of the
    #                                       install (src/tools/Makefile.am:8)
    #   CARES_WERROR=OFF                    :46 warnings never fail the build
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCARES_STATIC=ON",
      "-DCARES_SHARED=ON",
      "-DCARES_STATIC_PIC=ON",
      "-DCARES_SYMBOL_HIDING=ON",
      "-DCARES_THREADS=ON",
      "-DCARES_BUILD_TESTS=OFF",
      "-DCARES_BUILD_TOOLS=OFF",
      "-DCARES_WERROR=OFF",
      "-DCARES_RANDOM_FILE=/dev/urandom",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{hw.concurrency}}",
    "cmake --install build",
  ]
}

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/ares.h",
    "test -f {{prefix}}/lib/cmake/c-ares/c-ares-config.cmake",
    "pkg-config --exists libcares",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <ares.h>

int main(void) {
  ares_channel_t *channel = NULL;
  if (ares_library_init(ARES_LIB_INIT_ALL) != ARES_SUCCESS) {
    puts("ares_library_init failed");
    return 1;
  }
  if (ares_init(&channel) != ARES_SUCCESS) {
    puts("ares_init failed");
    return 1;
  }
  printf("c-ares %s\n", ares_version(NULL));
  ares_destroy(channel);
  ares_library_cleanup();
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o version $(pkg-config --cflags --libs libcares)"
    },
    "./version",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",       # :36-47 options; :793-816 config files, targets and libcares.pc installed
    "LICENSE.md",           # "MIT License"
    "src/tools/Makefile.am", # :4-8 ahost and adig are noinst_PROGRAMS (the autotools install)
  ]

  consulted = [
    "https://github.com/bradh352.gpg",
  ]

  note = <<EOT
NOT BUILT: written from the sources and the signed release; not run on a
builder. Switched from the autotools build to the project's CMake build so
that c-ares-config.cmake is installed (gRPC needs it); same version and pins.
The tarball still ships `configure`, but it is no longer used.
EOT
}
