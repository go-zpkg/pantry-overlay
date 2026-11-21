# libogg — the Ogg bitstream container: the library every other Xiph codec
# library (vorbis, theora, speex, flac, opus) and libshout sits on.
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1), because libshout requires it and no recipe existed.

summary = "Ogg bitstream container library"

# COPYING: "Copyright (c) 2002, Xiph.org Foundation" followed by the
# three-clause BSD terms (redistribution with notice, binary reproduction with
# notice, no endorsement).
license = "BSD-3-Clause"

versions {
  url   = "https://downloads.xiph.org/releases/ogg/"
  match = "/libogg-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = [
    "/^libogg-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  # The release tarball, not a generated tag archive: it ships `configure`, so
  # no autoconf, automake or libtool is needed to build it.
  url              = "https://downloads.xiph.org/releases/ogg/libogg-{{version.raw}}.tar.xz"
  strip-components = 1

  # Fetched with `zpkb sourcepin` (439952 bytes) and equal to the line the
  # project publishes for this file in
  # https://downloads.xiph.org/releases/ogg/SHA256SUMS (line 45).
  #
  # ⛔ NO SIGNATURE: the path libogg-1.3.6.tar.xz.asc answers with a 261-byte
  # body that gpg reports as "no valid OpenPGP data", so the project signs
  # nothing here. The SHA256SUMS file lives on the same host as the tarball,
  # which makes it a transport check and not an independent authority.
  sha256 = {
    "1.3.6" = "5c8253428e181840cd20d41f3ca16557a9cc04bad4a3d04cce84808677fa1061"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env {
    # configure.ac:164-173 has one feature switch, --disable-crc (default: CRC
    # on), and :178-199 the developer options --enable-gcc-sanitizers and
    # --enable-valgrind-testing (both default off). All three are stated.
    ARGS = [
      "--prefix={{prefix}}",
      "--enable-crc",
      "--disable-gcc-sanitizers",
      "--disable-valgrind-testing",
      "--disable-dependency-tracking",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/ogg/ogg.h",
    "pkg-config --exists ogg",
    # A real page round trip through the library: pack one packet into a page,
    # feed the page to a sync state and take the packet back out.
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <ogg/ogg.h>

int main(void) {
  ogg_stream_state os, is;
  ogg_sync_state oy;
  ogg_page og;
  ogg_packet op, back;
  unsigned char data[] = "the quick brown fox";

  ogg_stream_init(&os, 42);
  memset(&op, 0, sizeof op);
  op.packet = data;
  op.bytes = (long)sizeof data;
  op.b_o_s = 1;
  op.e_o_s = 1;
  ogg_stream_packetin(&os, &op);
  if (ogg_stream_flush(&os, &og) == 0) {
    puts("no page produced");
    return 1;
  }

  ogg_sync_init(&oy);
  char *buf = ogg_sync_buffer(&oy, og.header_len + og.body_len);
  memcpy(buf, og.header, og.header_len);
  memcpy(buf + og.header_len, og.body, og.body_len);
  ogg_sync_wrote(&oy, og.header_len + og.body_len);

  ogg_page pg;
  if (ogg_sync_pageout(&oy, &pg) != 1) {
    puts("page did not come back (CRC?)");
    return 1;
  }
  ogg_stream_init(&is, ogg_page_serialno(&pg));
  ogg_stream_pagein(&is, &pg);
  if (ogg_stream_packetout(&is, &back) != 1 || back.bytes != (long)sizeof data ||
      memcmp(back.packet, data, sizeof data) != 0) {
    puts("packet differs");
    return 1;
  }
  puts("ogg page round-tripped");
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o roundtrip $(pkg-config --cflags --libs ogg)"
    },
    "./roundtrip",
  ]
}

provenance {
  read = [
    "configure.ac",  # :3 version; :164-173 --disable-crc; :178-199 sanitizer and valgrind switches
    "COPYING",       # Xiph.org Foundation BSD terms
    "README.md",     # build with ./configure && make
    "Makefile.am",   # installs include/ogg/*.h, libogg and ogg.pc
  ]

  consulted = [
    "https://downloads.xiph.org/releases/ogg/SHA256SUMS",
  ]

  note = <<EOT
NOT BUILT: written from the sources and the release index; not run on a
builder. The tarball ships configure, so the build is the plain autotools
sequence with every switch configure.ac defines stated. The CMake build the
project also ships (CMakeLists.txt) was not used.
EOT
}
