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
    "gnu.org/make" = "*"
  }

  env {
    # Every switch configure.ac defines, stated (line numbers in configure.ac):
    #   :78       static libraries are enabled, and shared ones by default.
    #   :80-83    --disable-warnings: strict compiler warnings OFF, so a newer
    #             compiler cannot turn one into a build failure.
    #   :85-104   --enable-symbol-hiding: ON (it defaults to "maybe").
    #   :106-115  --disable-tests: the GoogleTest suite is OFF (it is otherwise
    #             built whenever GoogleTest is found).
    #   :117-120  --enable-cares-threads: thread safety ON.
    #   :122-127  --with-random=/dev/urandom, the stated default.
    #   :367-376  --disable-libgcc: do not add -lgcc.
    ARGS = [
      "--prefix={{prefix}}",
      "--enable-shared",
      "--enable-static",
      "--disable-warnings",
      "--enable-symbol-hiding",
      "--disable-tests",
      "--enable-cares-threads",
      "--with-random=/dev/urandom",
      "--disable-libgcc",
      "--disable-dependency-tracking",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

# The ahost and adig programs are `noinst_PROGRAMS` (src/tools/Makefile.am:8),
# so `make install` ships only the library, headers and libcares.pc.

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/ares.h",
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
    "configure.ac",         # :78 static; :80 warnings; :85 symbol hiding; :106 tests; :117 threads; :122 random; :367 libgcc
    "LICENSE.md",           # "MIT License"
    "Makefile.am",          # :49 SUBDIRS; :51-52 libcares.pc installed
    "src/tools/Makefile.am", # :4-8 ahost and adig are noinst_PROGRAMS
    "INSTALL.md",           # the autotools build
  ]

  consulted = [
    "https://github.com/bradh352.gpg",
  ]

  note = <<EOT
NOT BUILT: written from the sources and the signed release; not run on a
builder. The CMake build the project also ships was not used.
EOT
}
