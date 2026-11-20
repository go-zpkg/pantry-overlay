# x.org/xrender — libXrender, the client library of the X Render extension.
# libXft requires it (libXft configure.ac:67 `xrender >= 0.8.2`, xft.pc.in
# `Requires.private: xrender`), and libXft is what Tk's antialiased fonts link
# (Tk 8.6.18 unix/configure.in:457-533, Tk 9.0.4 unix/configure.ac:346-422).
# The project name is the one the pantry's recipe and this tree's consumers use.
#
# ⛔ WRITTEN FROM LIBXRENDER'S OWN FILES (go-zpkg/packages#431), at 0.9.13 — a
# 0.9 line, which is why no `^1` constraint can name it.

summary = "X.Org libXrender: client library of the X Render extension"

# COPYING:2-4 "Copyright © 2001,2003 Keith Packard. Permission to use, copy,
# modify, distribute, and sell this software and its documentation for any
# purpose is hereby granted without fee … the name of Keith Packard not be used
# in advertising" and :22-24 the same text for SuSE, Inc. (2000): both are
# HPND-sell-variant.
license = "HPND-sell-variant"

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/libXrender-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = ["/libXrender-/", "/\\.tar\\.xz/"]
}

dependencies = {
  # xrender.pc.in:10 `Requires: xproto renderproto >= @RENDER_VERSION@ x11`;
  # configure.ac:64 `x11 >= 1.6` and renderproto.
  "x.org/x11"      = "^1"
  "x.org/protocol" = "*"
}

distributable {
  # 316404 bytes, signature verified (see provenance.note) and confirmed by a
  # second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/lib/libXrender-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "0.9.13" = "3fe88c609df6782e1e7af2e4de36b2563d70cd70ff7dcb1cda561ad64912bb64"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  # configure:1480 `--enable-malloc0returnsnull` is the only switch the package
  # adds: the conservative assumption (default yes), not a probe; named so it
  # is visible. It has no doc or lint switch.
  env = {
    ARGS = [
      "--prefix={{prefix}}",
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
    "test -f \"{{prefix}}/include/X11/extensions/Xrender.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/xrender.pc\"",
    "grep -q '^Requires:.*renderproto' \"{{prefix}}/lib/pkgconfig/xrender.pc\"",
    "grep -q '^Requires:.*x11' \"{{prefix}}/lib/pkgconfig/xrender.pc\"",
    {
      run = <<EOT
set -eu
lib=""
for f in "{{prefix}}"/lib/libXrender.so "{{prefix}}"/lib/libXrender.dylib; do
  if test -e "$f"; then lib="$f"; break; fi
done
test -n "$lib" || { echo "no libXrender shared library" >&2; exit 1; }
real=$(readlink -f "$lib" 2>/dev/null || echo "$lib")
grep -aq 'XRenderQueryExtension' "$real" || { echo "libXrender lacks its entry points" >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",    # :64 PKG_CHECK_MODULES(RENDER, x11 >= 1.6 renderproto)
    "configure",       # :1480 --enable-malloc0returnsnull, the only package switch
    "xrender.pc.in",   # :10 Requires
    "COPYING",         # :2-24 the two Keith Packard / SuSE notices
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://github.com/alanc.gpg",               # the signer's key, from GitHub's account endpoint
  ]

  consulted = [
    # Read for facts only: the name x.org/xrender and the version listing.
    "pkgxdev/pantry projects/x.org/xrender/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, with a key from an account endpoint rather than a keyserver.

  signature   https://www.x.org/releases/individual/lib/libXrender-0.9.13.tar.xz.sig
  signer      Alan Coopersmith <alan.coopersmith@oracle.com>
  fingerprint 3AB285232C46AE43D8E192F4DAB0F78EA6E7E2D2
  key from    https://github.com/alanc.gpg (GitHub's account endpoint)

⚠ THE RUNG, STATED: GitHub's account page, a third party that is not X.Org.

zpkb v0.84.0 or later is needed (the key has lapsed: go-zpkg/zpkb#484).

⛔ NOT BUILT here as the factory would. A scratch build with these arguments was
done on darwin with xorgproto and libX11 on PKG_CONFIG_PATH.
EOT
}
