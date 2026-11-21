# libfido2 — Yubico's library and command line tools for FIDO2 / CTAP2 devices.
#
# ⛔ WRITTEN FROM LIBFIDO2'S OWN FILES at 1.17.0 (go-zpkg/packages#440 step 1).
# It had been skipped because libcbor had no recipe; github.com/PJK/libcbor is
# now a whole recipe (written in the same change).

summary = "Library and tools for FIDO2 / CTAP2 authenticators"

# LICENSE is the BSD two-clause text: "Redistribution and use in source and
# binary forms, with or without modification" with the conditions at :9
# ("2. Redistributions in binary form …") and no endorsement clause.
license = "BSD-2-Clause"

versions {
  # Tags are plain `1.17.0`. The repository has no GitHub releases, but Yubico
  # publishes signed tarballs named after the same tags.
  github = "Yubico/libfido2"
}

distributable {
  # The SIGNED release tarball from Yubico's release page, not the generated
  # tag archive. It is the file the README (:41-43) points at.
  url              = "https://developers.yubico.com/libfido2/Releases/libfido2-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.17.0: 714675 bytes. `zpkb sourcepin --sig auto` verified the detached
  # signature libfido2-1.17.0.tar.gz.sig: signed by the primary key
  # 78D997D53E9C0A2A205392ED14A19784723C9988 (Ludvig Michaelsson
  # <ludvig.michaelsson@yubico.com>, signing subkey B37003FF…C4E0B673), who also
  # signed the git tag 1.17.0. The fingerprint comes from Yubico's own page
  # https://developers.yubico.com/Software_Projects/Software_Signing.html; the
  # key itself from yubico.com's Web Key Directory over HTTPS. NO keyserver was
  # asked. (The copy of the key on github.com/LDVG.gpg is stale: its signing
  # subkey expired 2025-09-16, before the release was signed.)
  sha256 = {
    "1.17.0" = "c1012c8871d71b65872fd5ff1a9d6b0838a55683a03e85ba97479ce57129c736"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
    "openssl.org"  = "^3"
    "zlib.net"     = "1"

    "github.com/PJK/libcbor" = "0"

    linux = {
      # CMakeLists.txt:248: pkg_search_module(UDEV libudev REQUIRED) on Linux.
      "systemd.io" = "*"
    }
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # src/CMakeLists.txt:141-154 install into ${CMAKE_INSTALL_LIBDIR}, which
      # GNUInstallDirs may make lib64; the .pc file (src/libfido2.pc.in:3) is
      # built from it too. Pinned to lib.
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:41-42: both default ON; stated.
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_STATIC_LIBS=ON",

      # CMakeLists.txt:38-40: regress tests and examples are not installed;
      # the man pages need a documentation toolchain (mandoc) this recipe does
      # not declare. All OFF. BUILD_TOOLS stays ON: fido2-token, fido2-cred
      # and fido2-assert are the programs people install this for
      # (tools/CMakeLists.txt:73-74).
      "-DBUILD_TESTS=OFF",
      "-DBUILD_EXAMPLES=OFF",
      "-DBUILD_MANPAGES=OFF",
      "-DBUILD_TOOLS=ON",

      # CMakeLists.txt:45: hidapi is OFF by default and is named off — the
      # native HID backends are used (hidraw on Linux, IOKit on macOS).
      "-DUSE_HIDAPI=OFF",

      # CMakeLists.txt:46 and :279: "experimental PCSC support"; on Linux it is
      # REQUIRED to find libpcsclite when ON. No pcsc-lite recipe is declared
      # here, so it is explicitly OFF rather than auto-detected.
      "-DUSE_PCSC=OFF",

      # CMakeLists.txt:48 and :289-291: NFC_LINUX only adds -DUSE_NFC (kernel
      # NFC sockets) and is forced OFF off Linux at :262; it needs only kernel
      # headers. Left ON, as upstream defaults it.
      "-DNFC_LINUX=ON",

      # CMakeLists.txt:47: Windows only (forced OFF at :298).
      "-DUSE_WINHELLO=OFF",

      # CMakeLists.txt:44: fuzzing instrumentation.
      "-DFUZZ=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# tools/CMakeLists.txt:73: the three programs installed. (tools/ also holds
# fido2-attach.sh and friends, which the CMake file does not install.)
provides = [
  "bin/fido2-assert",
  "bin/fido2-cred",
  "bin/fido2-token",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -x {{prefix}}/bin/fido2-cred",
    "test -x {{prefix}}/bin/fido2-assert",
    "test -x {{prefix}}/bin/fido2-token",
    # tools/fido2-token.c:103-104: -V prints "%d.%d.%d\n" to STDERR.
    "test \"$(fido2-token -V 2>&1)\" = {{version.raw}}",
    "test -f {{prefix}}/include/fido.h",
    "test -f {{prefix}}/lib/pkgconfig/libfido2.pc",
    "pkg-config --exists libfido2",
    "test \"$(pkg-config --modversion libfido2)\" = {{version.raw}}",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <fido.h>

int main(void) {
  fido_init(0);
  fido_dev_info_t *devlist = fido_dev_info_new(8);
  if (devlist == NULL) {
    puts("fido_dev_info_new failed");
    return 1;
  }
  size_t n = 0;
  /* No authenticator is plugged in on a builder: zero devices is a pass; what
     matters is that the library links and the call returns FIDO_OK. */
  int r = fido_dev_info_manifest(devlist, 8, &n);
  fido_dev_info_free(&devlist, 8);
  if (r != FIDO_OK) {
    printf("fido_dev_info_manifest: %d\n", r);
    return 1;
  }
  printf("libfido2 linked, %zu device(s)\n", n);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o manifest $(pkg-config --cflags --libs libfido2)"
    },
    "./manifest",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",          # :33-36 FIDO_VERSION 1.17.0; :38-48 the options; :226-248 libcbor/libcrypto/zlib/libudev; :279 pcsclite; :289 NFC_LINUX
    "tools/CMakeLists.txt",    # :73-74 the three installed programs
    "src/CMakeLists.txt",      # :140-162 library, headers and libfido2.pc
    "src/libfido2.pc.in",      # Name libfido2; Requires: libcrypto; Libs: -lfido2
    "README.adoc",             # :41-43 signed tarballs on Yubico's release page; the dependency list
    "LICENSE",                 # BSD two-clause
  ]

  consulted = [
    "https://developers.yubico.com/Software_Projects/Software_Signing.html",
  ]

  note = <<EOT
Written, not converted: the earlier fragment stated no versions, no source
and no build.

Signature (kept here because the schema has no field for it):
  https://developers.yubico.com/libfido2/Releases/libfido2-1.17.0.tar.gz.sig
verified with `zpkb sourcepin --sig auto` against the key
78D997D53E9C0A2A205392ED14A19784723C9988 fetched from yubico.com's Web Key
Directory. No keyserver was consulted.

⛔ NOT BUILT. The build and test blocks were not run in this session.

Every optional backend is named: hidapi off, PCSC off (it would require
pcsc-lite, which has no recipe here), WinHello off, fuzzing off.
EOT
}
