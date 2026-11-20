# x.org/xext — libXext, the library of common X extensions (MIT-SHM, SHAPE,
# SYNC, DPMS, XTEST ext1, …). Tk links it when it links XScreenSaver
# (Tk 8.6.18 unix/configure.in:617-631, Tk 9.0.4 unix/configure.ac:501-514).
#
# This is libXext ALONE, under its own name. `x.org/exts` is deliberately NOT
# written (go-zpkg/recipes#167 says it cannot be written as a bundle): see the
# provenance note for what the pantry's recipe of that name actually is.
#
# ⛔ WRITTEN FROM LIBXEXT'S OWN FILES (go-zpkg/packages#431), at 1.3.7.

summary = "X.Org libXext: the library of common X extensions"

# COPYING holds notices of five kinds (headings read from it):
#   :1,:3     The Open Group — "Permission to use, copy, modify, distribute, and
#             sell … Except as contained in this notice, the name of The Open
#             Group shall not be used": MIT-open-group;
#   :23,:25   Digital, :127 HP, :163 Oracle and Peter Hutterer — "Permission is
#             hereby granted, free of charge": MIT;
#   :47-:110  SGI, NCD, Digital/Olivetti, HP — "Permission to use, copy, modify,
#             and distribute … without fee": HPND, and with "and sell"
#             HPND-sell-variant (NCD :68-70);
#   :190      the X Consortium documentation grant: HPND;
#   :199-201  Otto Moerbeek (reallocarray) — "for any purpose with or without
#             fee": ISC.
license = "MIT AND MIT-open-group AND HPND AND HPND-sell-variant AND ISC"

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/libXext-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = ["/libXext-/", "/\\.tar\\.xz/"]
}

dependencies = {
  # configure.ac:45 `x11 >= 1.6`, xext.pc.in `Requires.private: x11`.
  "x.org/x11"      = "^1"
  # configure.ac:45 xproto >= 7.0.13, xextproto >= 7.1.99; xext.pc.in
  # `Requires: xextproto`.
  "x.org/protocol" = "*"
}

distributable {
  # 347068 bytes, signature verified (see provenance.note) and confirmed by a
  # second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/lib/libXext-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "1.3.7" = "6c643c7035cdacf67afd68f25d01b90ef889d546c9fcd7c0adf7c2cf91e3a32d"
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

      # ⛔ configure:1585 `--enable-specs` default yes; :1596-1599 xmlto and
      # xsltproc and fop "default: auto"; :1601 lint auto; :1588 lint library
      # default disabled. All off.
      "--disable-specs",
      "--with-xmlto=no",
      "--with-fop=no",
      "--with-xsltproc=no",
      "--without-lint",
      "--disable-lint-library",

      # configure:1586-1587 "assume malloc(0) can return NULL (default: yes)":
      # the conservative assumption and not a probe; named so it is visible.
      "--enable-malloc0returnsnull",
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
    "test -f \"{{prefix}}/include/X11/extensions/shape.h\"",
    "test -f \"{{prefix}}/include/X11/extensions/XShm.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/xext.pc\"",
    "grep -q '^Requires: xextproto' \"{{prefix}}/lib/pkgconfig/xext.pc\"",
    "grep -q '^Requires.private: x11' \"{{prefix}}/lib/pkgconfig/xext.pc\"",

    # What Tk links it for: the library carries SHAPE and MIT-SHM entry points.
    {
      run = <<EOT
set -eu
lib=""
for f in "{{prefix}}"/lib/libXext.so "{{prefix}}"/lib/libXext.dylib; do
  if test -e "$f"; then lib="$f"; break; fi
done
test -n "$lib" || { echo "no libXext shared library" >&2; exit 1; }
real=$(readlink -f "$lib" 2>/dev/null || echo "$lib")
grep -aq 'XShapeQueryExtension' "$real" || { echo "libXext lacks SHAPE" >&2; exit 1; }
grep -aq 'XShmQueryExtension' "$real" || { echo "libXext lacks MIT-SHM" >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",  # :26-31 doc tools and malloc0; :45 the three modules required; :47-48 reallocarray; :51-52 lint
    "configure",     # :1585-1601 every switch and its default
    "xext.pc.in",    # Requires: xextproto; Requires.private: x11
    "COPYING",       # :1-201 the notices cited in the licence comment
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://github.com/alanc.gpg",               # the signer's key, from GitHub's account endpoint
    "https://sourceforge.net/projects/tcl/files/Tcl/", # Tk 8.6.18 and 9.0.4 sources, read for the consumer's needs
  ]

  consulted = [
    # Read for facts only: that the pantry's recipe named x.org/exts distributes
    # libXext alone. Nothing copied.
    "pkgxdev/pantry projects/x.org/exts/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, with a key from an account endpoint rather than a keyserver.

  signature   https://www.x.org/releases/individual/lib/libXext-1.3.7.tar.xz.sig
  signer      Alan Coopersmith <alan.coopersmith@oracle.com>
  fingerprint 3AB285232C46AE43D8E192F4DAB0F78EA6E7E2D2 (the first of the two keys
              in the file, as recorded in go-zpkg/recipes#167)
  key from    https://github.com/alanc.gpg (GitHub's account endpoint)

⚠ THE RUNG, STATED: GitHub's account page, a third party that is not X.Org.

zpkb v0.84.0 or later is needed (the key has lapsed: go-zpkg/zpkb#484).

⚠ WHAT x.org/exts IS, for whoever decides its fate. go-zpkg/recipes#167 calls it
an invented bundle. The pantry's recipe of that name distributes ONE tarball,
libXext-<version>.tar.gz, with versions matched as libXext's own (1.3.x), so its
consumers (tcl-lang.org `^1`, the pantry's x.org/xscrnsaver) ask for libXext
alone and `^1` is satisfied by 1.3.7. It was NOT written here, as instructed;
those consumers still resolve it from the pantry until they name x.org/xext or
an x.org/exts recipe is written as this same libXext.

⛔ NOT BUILT here as the factory would. A scratch build with these arguments was
done on darwin with xorgproto and libX11 on PKG_CONFIG_PATH.
EOT
}
