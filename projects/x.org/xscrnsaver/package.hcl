# x.org/xscrnsaver — libXScrnSaver (libXss), the client library of the MIT
# Screen-Saver extension. Tk calls it for Tk_GetUserInactiveTime().
#
# ⛔ WRITTEN FROM LIBXSCRNSAVER'S OWN FILES (go-zpkg/packages#431), at 1.2.5.
#
# ⭐ WHAT TK DOES WITH IT, read from Tk's own configure (8.6.18
# unix/configure.in:588-639, 9.0.4 unix/configure.ac:474-519): `--enable-xss`
# defaults to YES and is a DETECTION — the header X11/extensions/scrnsaver.h and
# the symbol XScreenSaverQueryInfo must both be found, first in libc/libX11,
# then in libXext, then in libXss (linked with -lXext), and a miss quietly leaves
# HAVE_XSS undefined. So libXScrnSaver is declared in the Tk recipe for the
# build to find it, and `--enable-xss` is what makes Tk's intent visible.

summary = "X.Org libXScrnSaver: client library of the MIT Screen-Saver extension"

# COPYING:1-22 "Copyright (c) 1992  X Consortium … Permission is hereby granted,
# free of charge … Except as contained in this notice, the name of the X
# Consortium shall not be used": X11; and :25-48 the same text with "The
# XFree86 Project" in place of the X Consortium, which SPDX has no identifier
# of its own for and which is X11 in form.
license = "X11"

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/libXScrnSaver-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = ["/libXScrnSaver-/", "/\\.tar\\.xz/"]
}

dependencies = {
  # configure.ac:46 PKG_CHECK_MODULES(XSCRNSAVER, x11 xext xextproto
  # scrnsaverproto >= 1.2); xscrnsaver.pc.in `Requires.private: x11 xext`.
  "x.org/x11"      = "^1"
  "x.org/xext"     = "^1"
  "x.org/protocol" = "*"
}

distributable {
  # 271488 bytes, signature verified (see provenance.note) and confirmed by a
  # second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/lib/libXScrnSaver-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "1.2.5" = "5057365f847253e0e275871441e10ff7846c8322a5d88e1e187d326de1cd8d00"
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

      # configure:1499 `--enable-malloc0returnsnull`, the conservative default
      # (yes) and not a probe; :1501 lint library default disabled and :1509
      # `--with-lint` auto, off here.
      "--enable-malloc0returnsnull",
      "--without-lint",
      "--disable-lint-library",
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
    # Tk's header probe (unix/configure.in:613): the header must exist.
    "test -f \"{{prefix}}/include/X11/extensions/scrnsaver.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/xscrnsaver.pc\"",
    "grep -q '^Requires.private:.*xext' \"{{prefix}}/lib/pkgconfig/xscrnsaver.pc\"",
    "grep -q -- '-lXss' \"{{prefix}}/lib/pkgconfig/xscrnsaver.pc\"",

    # Tk's symbol probe (:616-632): XScreenSaverQueryInfo must be in libXss.
    {
      run = <<EOT
set -eu
lib=""
for f in "{{prefix}}"/lib/libXss.so "{{prefix}}"/lib/libXss.dylib; do
  if test -e "$f"; then lib="$f"; break; fi
done
test -n "$lib" || { echo "no libXss shared library" >&2; exit 1; }
real=$(readlink -f "$lib" 2>/dev/null || echo "$lib")
grep -aq 'XScreenSaverQueryInfo' "$real" || { echo "libXss lacks XScreenSaverQueryInfo, which Tk probes for" >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",       # :46 the modules required
    "configure",          # :1499-1509 the package's switches
    "xscrnsaver.pc.in",   # :10-13 Requires, Requires.private, Libs -lXss
    "COPYING",            # :1-48 the X Consortium and XFree86 notices
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://github.com/alanc.gpg",               # the signer's key, from GitHub's account endpoint
    "https://sourceforge.net/projects/tcl/files/Tcl/", # Tk 8.6.18 and 9.0.4 sources: the consumer's probe
  ]

  consulted = [
    # Read for facts only: the name x.org/xscrnsaver and that it declared the
    # x.org/exts bundle. Nothing copied.
    "pkgxdev/pantry projects/x.org/xscrnsaver/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, with a key from an account endpoint rather than a keyserver.

  signature   https://www.x.org/releases/individual/lib/libXScrnSaver-1.2.5.tar.xz.sig
  signer      Alan Coopersmith <alan.coopersmith@oracle.com>
  fingerprint 3AB285232C46AE43D8E192F4DAB0F78EA6E7E2D2
  key from    https://github.com/alanc.gpg (GitHub's account endpoint)

⚠ THE RUNG, STATED: GitHub's account page, a third party that is not X.Org.

zpkb v0.84.0 or later is needed (the key has lapsed: go-zpkg/zpkb#484).

The pantry's recipe depends on `x.org/exts`; this one depends on x.org/xext,
which is the same upstream project (libXext). `x.org/exts` was not written.

⛔ NOT BUILT here as the factory would. A scratch build with these arguments was
done on darwin with xorgproto, libX11 and libXext on PKG_CONFIG_PATH.
EOT
}
