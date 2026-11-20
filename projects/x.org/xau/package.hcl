# x.org/xau — libXau, the X authorization file library (the ~/.Xauthority
# reader). Fifth of the chain go-zpkg/recipes#167 orders; libxcb links it.
# The project name is the one this tree's consumers already declare.
#
# ⛔ WRITTEN FROM LIBXAU'S OWN FILES (go-zpkg/packages#431), at 1.0.12.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. The pantry's recipe declares util-macros at runtime. The release tarball
#      ships a generated configure, and util-macros is read only at AUTOCONF time
#      (configure.ac:38-41), so nothing here needs it.
#   2. Its requirement on xorgproto is REAL and two-sided: PKG_CHECK_MODULES(XAU,
#      xproto) at configure.ac:51 makes a missing xproto fatal at build, and
#      xau.pc.in says `Requires: xproto`, so every consumer's pkg-config walk
#      goes through x.org/protocol at their build too.
#   3. Thread support is probed (configure.ac:56-78): `--disable-xthreads` is the
#      only lever, and `gethostbyname_r` decides XUSE_MTSAFE_API. Stated below.

summary = "X.Org libXau: X authorization file management library"

# COPYING:1-21 — "Copyright 1988, 1993, 1994, 1998  The Open Group. Permission to
# use, copy, modify, distribute, and sell this software and its documentation for
# any purpose is hereby granted without fee … Except as contained in this notice,
# the name of The Open Group shall not be used in advertising": MIT-open-group.
license = "MIT-open-group"

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/libXau-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = ["/libXau-/", "/\\.tar\\.xz/"]
}

dependencies = {
  # xau.pc.in: `Requires: xproto`; headers include X11/Xfuncproto.h.
  "x.org/protocol" = "*"
}

distributable {
  # 282624 bytes, signature verified (see provenance.note) and confirmed by a
  # second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/lib/libXau-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "1.0.12" = "74d0e4dfa3d39ad8939e99bda37f5967aba528211076828464d2777d477fc0fb"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # configure.ac:56-59 default yes; named so a default change is visible.
      "--enable-xthreads",

      # configure:1503 "--enable-year2038 support timestamps after 2038": a
      # 32-bit time_t switch, named so it is on everywhere.
      "--enable-year2038",

      # configure:1502 `--enable-lint-library` default disabled, :1511
      # `--with-lint` default auto (XORG_WITH_LINT, configure.ac:81): a lint
      # checker found on the builder would otherwise be run.
      "--disable-lint-library",
      "--without-lint",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

test {
  script = [
    # Makefile.am:3 the library, :24 the header; xau.pc.in the module.
    "test -f \"{{prefix}}/include/X11/Xauth.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/xau.pc\"",
    "grep -q '^Requires: xproto' \"{{prefix}}/lib/pkgconfig/xau.pc\"",
    "grep -q -- '-lXau' \"{{prefix}}/lib/pkgconfig/xau.pc\"",
    {
      run = <<EOT
set -eu
n=0
for f in "{{prefix}}"/lib/libXau.so* "{{prefix}}"/lib/libXau.*dylib; do
  if test -e "$f"; then n=$((n+1)); fi
done
test "$n" -ge 1 || { echo "no shared libXau installed" >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",  # :38-42 xorg-macros at autoconf time only; :48 function probes; :51 xproto required; :56-78 xthreads; :81 lint
    "configure",     # :1500-1511 the option list and their defaults
    "xau.pc.in",     # Requires: xproto; Libs -lXau
    "Makefile.am",   # :3 libXau.la; :24 Xauth.h
    "COPYING",       # :1-21 the Open Group notice
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://github.com/alanc.gpg",               # the signer's key, from GitHub's account endpoint
  ]

  consulted = [
    # Read for facts only: the name x.org/xau, the version listing, and that it
    # declares util-macros and xorgproto. Nothing copied.
    "pkgxdev/pantry projects/x.org/xau/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, with a key from an account endpoint rather than a keyserver.

  signature   https://www.x.org/releases/individual/lib/libXau-1.0.12.tar.xz.sig
  signer      Alan Coopersmith <alan.coopersmith@oracle.com>
  fingerprint 4A193C06D35E7C670FA4EF0BA2FB9E081F2D130E
  key from    https://github.com/alanc.gpg (GitHub's account endpoint)

The second of the two keys in that file, not the 3AB28523… of
go-zpkg/recipes#167 (see x.org/xtrans). The rung is GitHub's account page, a
third party that is not X.Org.

zpkb v0.84.0 or later is needed (the key has lapsed: go-zpkg/zpkb#484).

⛔ NOT BUILT here as the factory would. A scratch build with these arguments
(configure, make, make install) was done on darwin with xorgproto's modules on
PKG_CONFIG_PATH.
EOT
}
