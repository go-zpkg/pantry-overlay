# x.org/xft — libXft, the X FreeType interface library: antialiased, subpixel
# text through Render, FreeType and fontconfig. It is what Tk links for
# antialiased fonts: Tk 8.6.18 unix/configure.in:457-533 and Tk 9.0.4
# unix/configure.ac:346-422 ask `xft-config` or `pkg-config --cflags/--libs xft
# fontconfig`, then compile against X11/Xft/Xft.h and link XftFontOpen and
# FcFontSort. The project name is the one the pantry's recipe uses.
#
# ⛔ WRITTEN FROM LIBXFT'S OWN FILES (go-zpkg/packages#431), at 2.3.9.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. The package states no switch of its own: configure.ac holds the standard
#      X.org macros and three PKG_CHECK_MODULES (:67, :70, :73), each FATAL when
#      missing. So nothing here is a detection, and the build cannot silently
#      lose Render, FreeType or fontconfig.
#   2. The pantry's recipe declares bzip2 and zlib, which libXft never names;
#      they reach it only through freetype2.pc. They are not declared here.
#   3. WHAT HAPPENS IF THIS ARTIFACT IS MISSING AT TK'S BUILD IS SILENT: Tk's own
#      probe only warns (Tk 8.6.18 configure.in:514-523) and falls back to core
#      X fonts. The Tk recipe is the place that has to assert HAVE_XFT.

summary = "X.Org libXft: the X FreeType interface library (antialiased X text)"

# COPYING:2-12 — "Copyright © 2001,2003 Keith Packard. Permission to use, copy,
# modify, distribute, and sell this software and its documentation for any
# purpose is hereby granted without fee … the name of Keith Packard not be used
# in advertising or publicity": HPND-sell-variant. COPYING is that one notice.
license = "HPND-sell-variant"

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/libXft-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = ["/libXft-/", "/\\.tar\\.xz/"]
}

dependencies = {
  # configure.ac:67 `xrender >= 0.8.2 x11 xproto >= 7.0.22`; xft.pc.in
  # `Requires: xproto`, `Requires.private: xrender, fontconfig, freetype2`.
  "x.org/xrender"            = "^0.9"
  "x.org/x11"                = "^1"
  "x.org/protocol"           = "*"
  # configure.ac:70 `freetype2 >= 2.1.6` and :73 `fontconfig >= 2.5.92`.
  "freetype.org"             = "^2"
  "freedesktop.org/fontconfig" = "^2"
}

distributable {
  # 313852 bytes, signature verified (see provenance.note) and confirmed by a
  # second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/lib/libXft-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "2.3.9" = "60a25b78945ed6932635b3bb1899a517d31df7456e69867ffba27f89ff3976f5"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  # No --enable/--with switch of the package's own exists (configure --help
  # lists only autoconf's and libtool's); see finding 1.
  env = {
    ARGS = [
      "--prefix={{prefix}}",
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
    "test -f \"{{prefix}}/include/X11/Xft/Xft.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/xft.pc\"",

    # finding 1, read off the artifact: the three libraries it cannot build
    # without are named by the .pc.
    "grep -q '^Requires.private:.*xrender' \"{{prefix}}/lib/pkgconfig/xft.pc\"",
    "grep -q '^Requires.private:.*fontconfig' \"{{prefix}}/lib/pkgconfig/xft.pc\"",
    "grep -q '^Requires.private:.*freetype2' \"{{prefix}}/lib/pkgconfig/xft.pc\"",

    # What Tk links it for (Tk's AC_CHECK_LIB(Xft, XftFontOpen), configure.in:496).
    {
      run = <<EOT
set -eu
lib=""
for f in "{{prefix}}"/lib/libXft.so "{{prefix}}"/lib/libXft.dylib; do
  if test -e "$f"; then lib="$f"; break; fi
done
test -n "$lib" || { echo "no libXft shared library" >&2; exit 1; }
real=$(readlink -f "$lib" 2>/dev/null || echo "$lib")
grep -aq 'XftFontOpen' "$real" || { echo "libXft lacks XftFontOpen, which Tk probes for" >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",  # :67 xrender, x11, xproto; :70 freetype2; :73 fontconfig; no AC_ARG of its own
    "configure",     # :1471-1501 the option list: autoconf and libtool switches only
    "xft.pc.in",     # :10-13 Requires, Requires.private
    "COPYING",       # :2-12 the one notice
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://invisible-island.net/public/public.html", # :48-50 the signer's fingerprint, and the href to the key file
    "https://invisible-island.net/public/dickey@invisible-island.net-rsa3072.asc", # the key bytes
    "https://sourceforge.net/projects/tcl/files/Tcl/", # Tk 8.6.18 and 9.0.4 sources: the consumer's probe
  ]

  consulted = [
    # Read for facts only: the name x.org/xft, the version listing and the
    # dependency list (bzip2 and zlib are NOT carried: finding 2).
    "pkgxdev/pantry projects/x.org/xft/package.yml",
  ]

  note = <<EOT
⚠ THIS RELEASE IS NOT SIGNED BY ALAN COOPERSMITH, AND THE SIGNER PUBLISHES HIS OWN
FINGERPRINT.

  signature   https://www.x.org/releases/individual/lib/libXft-2.3.9.tar.xz.sig
  signed at   2025-04-20, RSA, issuer fingerprint
              19882D92DDA4C400C22C0D56CC2AF4472167BE03
  identity    Thomas E. Dickey <dickey@invisible-island.net>
  key from    https://invisible-island.net/public/dickey@invisible-island.net-rsa3072.asc,
              the href behind the fingerprint on his own page
              https://invisible-island.net/public/public.html (line 48-50:
              "pub rsa3072/2167BE03 2021-07-30" and the fingerprint as the link text)

THE STRONGEST RUNG OF THIS CHAIN: the same fingerprint, key file and page that
the invisible-island.net/ncurses recipe in this tree already pins (its
provenance note describes the page's signature chain). The name behind the
fingerprint was taken from the key file's user id and from that recipe, not from
a statement of X.Org's that he maintains libXft. X.Org itself publishes no page
naming the signing keys of its release archives.

zpkb v0.89.0 or later is needed: the key was refreshed on 2026-01-18, after it
signed on 2025-04-20, and sourcepin judged it "at the key's newest
self-signature" (go-zpkg/zpkb#512, fixed in #513), which earlier versions do
not do. The key's user id reads "Thomas E. Dickey (self-signed w/o SHA1)".

⛔ NOT BUILT here as the factory would. A scratch build on darwin with
libXrender, libX11, the machine's own freetype and the fontconfig of the
previous pull request configured, built and installed, and produced an xft.pc
with `Requires.private: xrender, fontconfig, freetype2`.
EOT
}
