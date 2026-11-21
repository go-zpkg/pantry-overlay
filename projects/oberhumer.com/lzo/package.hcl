# LZO — Markus Oberhumer's real-time data compression library.
#
# ⛔ WRITTEN FROM LZO'S OWN FILES at 2.10 (go-zpkg/packages#440 step 1).
# openvpn.net names `oberhumer.com/lzo` as a dependency and no recipe existed.

summary = "LZO real-time data compression library"

# include/lzo/lzoconf.h:8-11 "under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version"; COPYING is the GPL v2 text.
license = "GPL-2.0-or-later"

versions {
  # The author's download directory (an Apache index): one `lzo-X.Y.tar.gz`
  # per release, and the `minilzo-` subset beside it, which the match excludes
  # by requiring the `href="lzo-` prefix.
  url   = "https://www.oberhumer.com/opensource/lzo/download/"
  match = "/href=\"lzo-\\d+\\.\\d+\\.tar\\.gz\"/"
  strip = [
    "/^href=\"lzo-/",
    "/\\.tar\\.gz\"$/",
  ]
}

distributable {
  url              = "https://www.oberhumer.com/opensource/lzo/download/lzo-{{version.raw}}.tar.gz"
  strip-components = 1

  # 2.10: 600622 bytes, listed 2017-03-01. The author publishes NO signature
  # and no checksum file: lzo-2.10.tar.gz.asc answers a 200 HTML page, not a
  # signature, which was read rather than assumed. The newest release is nine
  # years old, so the pin is a fixed point, not a moving target.
  #
  # Second witness, from a party that is not the author's server: Homebrew's
  # formula `lzo` (formulae.brew.sh API, stable 2.10) records the checksum
  #   c0f892943208266f9b6543b3ae308fab6284c5c90e627931446fb49b4221a072
  # which is the digest below. That is weaker than a verified signature and is
  # said so rather than dressed up.
  sha256 = {
    "2.10" = "c0f892943208266f9b6543b3ae308fab6284c5c90e627931446fb49b4221a072"
  }
}

build {
  # configure.ac:80 is LT_INIT with no disable-shared, so both the shared and
  # the static library are built; :124 `--disable-asm` is the only project
  # option and is left at its default. Makefile.am:75 installs src/liblzo2.la,
  # :17 installs lzo2.pc.
  script = [
    "./configure --prefix={{prefix}}",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: Makefile.am installs a library, headers and lzo2.pc; the
# `lzotest` and `examples` programs are not installed.

test {
  script = [
    "test -f {{prefix}}/include/lzo/lzo1x.h",
    "pkg-config --exists lzo2",
    "test \"$(pkg-config --modversion lzo2)\" = {{version.raw}}",
    "ls {{prefix}}/lib/liblzo2.* > /dev/null",
  ]
}

provenance {
  read = [
    "configure.ac",                // :40 AC_INIT([LZO],[2.10]); :80 LT_INIT; :124 --disable-asm; :188 lzo2.pc
    "Makefile.am",                 // :15-17 lib_LTLIBRARIES, pkgconfig_DATA = lzo2.pc; :75 src/liblzo2.la
    "include/lzo/lzoconf.h",       // :8-11 GPL v2 or later; :32 LZO_VERSION 0x20a0
    "COPYING",                     // :1-2 GNU GPL Version 2
    "lzo2.pc.in",                  // the pkg-config module is lzo2
  ]

  consulted = [
    "https://www.oberhumer.com/opensource/lzo/download/",
    "https://formulae.brew.sh/api/formula/lzo.json",
  ]

  note = <<EOT
Written, not converted: no recipe existed.

NO SIGNATURE EXISTS to check: the author publishes the tarball alone. The pin
rests on one independent record of the same digest (Homebrew's formula), which
is weaker than a verified signature and is said so here.

⛔ THE BUILD AND THE TEST BLOCK WERE NOT RUN IN THIS SESSION. Stated rather
than implied.
EOT
}
