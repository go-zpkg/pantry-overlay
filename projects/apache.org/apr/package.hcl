# apr — Apache Portable Runtime, the C library Apache httpd, Subversion and
# Serf are written against.
#
# ⛔ WRITTEN FROM APR'S OWN FILES at 1.7.6, continuing go-zpkg/packages#440
# step 1. Serf and Subversion both depend on "apache.org/apr" and no recipe for
# it existed in this tree.

summary = "Apache Portable Runtime: a portable C library for files, sockets, threads, memory pools and shared memory"

# LICENSE opens "Apache License" (:1) and carries the appendix text "Licensed
# under the Apache License, Version 2.0" (:191).
license = "Apache-2.0"

versions {
  # ⛔ archive.apache.org, NOT downloads.apache.org: the mirror host lists only
  # the current files (an index read on 2026-11-21 shows 1.7.6 and 1.6.5), the
  # archive keeps every release and its URLs outlive the next one.
  url   = "https://archive.apache.org/dist/apr/"
  match = "/apr-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^apr-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://archive.apache.org/dist/apr/apr-{{version.raw}}.tar.bz2"
  strip-components = 1

  # 899670 bytes. TWO WITNESSES, BOTH CHECKED WHEN THE DIGEST WAS RECORDED:
  #
  #   1. The release's own published checksum, apr-1.7.6.tar.bz2.sha256, reads
  #      the digest below and `shasum -a 256` of the bytes fetched here gives
  #      the same value.
  #
  #   2. The detached signature apr-1.7.6.tar.bz2.asc verifies with gpg against
  #      https://downloads.apache.org/apr/KEYS (Apache's published keys file,
  #      no keyserver asked): "Good signature", key
  #      CBA1525BAA7A47BE28FF23DDD3B13FCA2CE60BED, Graham Leggett
  #      <minfrin@redwax.eu>, signed 2025-05-04.
  #
  # ⛔ 1.7.6 IS THE NEWEST THE INDEX RESOLVES AMONG 1.7.x; 1.6.5 is the other
  # file on the mirror and older. No `sha` field: Apache publishes the digest
  # beside the file but `sha` is not used for a pinned version here.
  sha256 = {
    "1.7.6" = "49030d92d2575da735791b496dc322f3ce5cff9494779ba8cc28c7f46c5deb32"
  }
}

# configure.in names no required library: every AC_ARG_WITH it defines
# (:130 apr-iconv, :1022 efence, :1037 valgrind, :1621 sendfile, :2790 egd,
# :2814 devrandom) is an optional or a debugging aid, and the platform libraries
# it probes for (pthread, dl, rt) come with the toolchain.
dependencies = {}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",
    ]
  }

  script = <<EOT
./configure $ARGS
make -j {{ hw.concurrency }}
make install
EOT
}

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test \"$(apr-1-config --version)\" = \"{{version.raw}}\"",
    "test \"$(pkg-config --modversion apr-1)\" = \"{{version.raw}}\"",
    "test -f {{prefix}}/include/apr-1/apr.h",
    "test -f {{prefix}}/lib/libapr-1.a",

    # THROUGH THE LIBRARY, which is what serf and subversion link: the macros
    # of apr_version.h (:52-) say what the header is, apr_version() says what
    # the compiled library is, and a disagreement is how a build picks up
    # another APR.
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <apr_general.h>
#include <apr_version.h>

int main(void) {
  apr_version_t v;
  apr_initialize();
  apr_version(&v);
  if (v.major != APR_MAJOR_VERSION || v.minor != APR_MINOR_VERSION ||
      v.patch != APR_PATCH_VERSION) {
    printf("header %s but library %d.%d.%d\n", APR_VERSION_STRING, v.major,
           v.minor, v.patch);
    return 1;
  }
  printf("libapr %d.%d.%d\n", v.major, v.minor, v.patch);
  apr_terminate();
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o libcheck $(apr-1-config --cflags --cppflags --includes --link-ld)"
    },
    "./libcheck",
  ]
}

provenance {
  read = [
    "configure.in",      # :130 --with-apr-iconv, :1022 efence, :1037 valgrind, :1621 sendfile, :2790 egd, :2814 devrandom: all optional aids, none a required library
    "include/apr_version.h", # :52 APR_MAJOR_VERSION; :108 APR_VERSION_STRING
    "apr.pc.in",         # the apr-1 pkg-config name and its version
    "LICENSE",           # Apache License 2.0, :1 and :191
    "NOTICE",
  ]

  consulted = [
    "https://downloads.apache.org/apr/",
    "https://downloads.apache.org/apr/KEYS",
    "https://downloads.apache.org/apr/apr-1.7.6.tar.bz2.asc",
    "https://downloads.apache.org/apr/apr-1.7.6.tar.bz2.sha256",
    "https://archive.apache.org/dist/apr/",
  ]

  note = <<EOT
Autoconf build (./configure, make, make install), written from configure.in.
Nothing was converted and no third-party recipe was used.

Signature, for the record:

  https://downloads.apache.org/apr/apr-1.7.6.tar.bz2.asc
  key         https://downloads.apache.org/apr/KEYS (Apache's published keys)
  identity    Graham Leggett <minfrin@redwax.eu>
  fingerprint CBA1525BAA7A47BE28FF23DDD3B13FCA2CE60BED
  checked     when the digest was recorded, not at every build

The fingerprint was read from the signature packet's issuer-fpr subpacket and
`gpg --verify` printed "Good signature" against a keyring imported from KEYS.

⛔ NOT RUN: the build script is read-checked, not executed.
EOT
}
