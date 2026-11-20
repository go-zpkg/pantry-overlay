# x.org/protocol — xorgproto, the X Window System protocol headers and the
# pkg-config modules (xproto, xextproto, kbproto, inputproto, renderproto,
# xf86bigfontproto, scrnsaverproto, …) that every X library asks for by name.
# The project name is the one this tree's consumers already declare
# (x.org/protocol, not x.org/xorgproto): the pantry's recipe for the same
# upstream project carries that name, so ours replaces it in a closure.
#
# ⛔ WRITTEN FROM XORGPROTO'S OWN FILES (go-zpkg/packages#431), at 2026.1, as the
# first of the chain go-zpkg/recipes#167 fixes the order of.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. It needs NO util-macros at build time, which the pantry's recipe declares.
#      The tarball ships a generated `configure`; the one place it reads
#      xorg-macros is configure:11820, `pkg-config --variable=pkgdatadir
#      xorg-macros`, which only fills INSTALL_CMD (the `make dist` copy of
#      INSTALL, :11821-11825) and falls back to an empty file. Nothing installed
#      depends on it.
#   2. `--enable-legacy` (configure.ac:46-50, default false) is what separates
#      the headers libX11 and Tk need from a set of dead extensions (Makefile.am
#      :142-144, :211-213, :360-451: xcalibrate, evie, fontcache, lg3d, Print,
#      xtrap, windowswm, xf86misc, xf86rush, XKBgeom.h, vldXvMC.h…). Default kept:
#      libX11 1.8.14 carries its own include/X11/extensions/XKBgeom.h
#      (include/Makefile.am), and the test below asserts what is NOT installed so
#      that flipping it is visible.
#   3. Documentation is the only thing configure detects here: xmlto, fop,
#      xsltproc and the sgml doctools — each is named below.

summary = "X.Org xorgproto: X Window System protocol headers and pkg-config modules"

# COPYING-* is one file PER PROTOCOL (EXTRA_DIST, Makefile.am:455-492: 37 of
# them), each a stack of notices. Read in full: COPYING-x11proto (Oracle MIT
# text, The Open Group permission notice, Digital, Apollo/HP and XFree86
# notices), COPYING-xextproto (the same plus SGI, NCD, HP, Digital/Olivetti and
# Peter Hutterer's MIT text) and COPYING-fontsproto, COPYING-kbproto (SGI).
#   - "Permission is hereby granted, free of charge … (including the next
#     paragraph)": MIT;
#   - "Permission to use, copy, modify, distribute, and sell … for any purpose
#     is hereby granted without fee … Except as contained in this notice, the
#     name of The Open Group shall not be used": MIT-open-group;
#   - "Permission to use, copy, modify, and distribute … without fee …
#     that the name of Digital not be used in advertising": HPND, and with
#     "and sell" HPND-sell-variant (NCD, Network Computing Devices).
# The other 33 COPYING-* files were NOT each read: this expression is what the
# four read ones state, and meson.build:22 says `license : 'MIT'` for the whole.
license = "MIT AND MIT-open-group AND HPND AND HPND-sell-variant"

versions {
  url   = "https://www.x.org/releases/individual/proto/"
  match = "/xorgproto-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = ["/xorgproto-/", "/\\.tar\\.xz/"]
}

distributable {
  # The .sig sits beside it. 771720 bytes; recorded with `zpkb sourcepin --sig`
  # (signature verified, see provenance.note) and confirmed by a second,
  # independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/proto/xorgproto-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "2026.1" = "f9bfe4a9ed8c8ab9d2a3b0d49797f046052dadd06b7a8b45dbffaffb137e8290"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ DOCUMENTATION: configure:11963-11970 builds the specs by default
      # ("--enable-specs … (default: yes)", :1517), and the generators
      # --with-xmlto, --with-fop and --with-xsltproc (:1523-1526) are each
      # "default: auto". The only effect of a missing generator is a quieter
      # build, so the artifact would differ between builders. All four off.
      "--disable-specs",
      "--with-xmlto=no",
      "--with-fop=no",
      "--with-xsltproc=no",

      # configure.ac:46-50, default false. Stated so a future default change is
      # visible here — see header, finding 2.
      "--disable-legacy",
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
    # The pkg-config modules libX11's configure.ac:81 and :318 and libXau ask
    # for. Makefile.am: xproto.pc :252, xextproto.pc :302, kbproto.pc :147,
    # inputproto.pc :134, xf86bigfontproto.pc :311, renderproto.pc :184,
    # scrnsaverproto.pc :203, xcmiscproto.pc :260, bigreqsproto.pc :38.
    "test -f \"{{prefix}}/share/pkgconfig/xproto.pc\"",
    "test -f \"{{prefix}}/share/pkgconfig/xextproto.pc\"",
    "test -f \"{{prefix}}/share/pkgconfig/kbproto.pc\"",
    "test -f \"{{prefix}}/share/pkgconfig/inputproto.pc\"",
    "test -f \"{{prefix}}/share/pkgconfig/xf86bigfontproto.pc\"",
    "test -f \"{{prefix}}/share/pkgconfig/renderproto.pc\"",
    "test -f \"{{prefix}}/share/pkgconfig/scrnsaverproto.pc\"",
    "test -f \"{{prefix}}/share/pkgconfig/xcmiscproto.pc\"",
    "test -f \"{{prefix}}/share/pkgconfig/bigreqsproto.pc\"",
    "test -f \"{{prefix}}/include/X11/Xproto.h\"",
    "test -f \"{{prefix}}/include/X11/extensions/shapeproto.h\"",

    # ⛔ configure:106-110 substitutes @USE_FDS_BITS@ into Xpoll.h (the fd_set
    # member: fds_bits or __fds_bits), and a miss is an error (:105-108); an
    # unsubstituted placeholder would be a header that compiles on no platform.
    {
      run = <<EOT
set -eu
if grep -q '@USE_FDS_BITS@' "{{prefix}}/include/X11/Xpoll.h"; then
  echo "Xpoll.h still carries @USE_FDS_BITS@" >&2
  exit 1
fi
grep -q 'fds_bits' "{{prefix}}/include/X11/Xpoll.h"
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR --disable-legacy, read off the artifact: the
    # legacy-only headers (Makefile.am:143, :212, :363, :388, :405, :430) must be
    # absent, and the non-legacy ones beside them present.
    {
      run = <<EOT
set -eu
for h in XKBgeom.h vldXvMC.h xcalibrateproto.h Print.h windowswm.h; do
  if test -e "{{prefix}}/include/X11/extensions/$h"; then
    echo "legacy header $h is installed, which this recipe pinned away" >&2
    exit 1
  fi
done
test -f "{{prefix}}/include/X11/extensions/XKB.h"
test -f "{{prefix}}/include/X11/extensions/Xvproto.h"
EOT
    },

    # And the headers compile: a translation unit including the two the whole
    # chain starts from.
    {
      run = <<EOT
set -eu
printf '#include <X11/X.h>\n#include <X11/Xproto.h>\nint main(void){return sizeof(xReq)==4?0:1;}\n' > hdr.c
cc hdr.c -I"{{prefix}}/include" -o hdr
./hdr
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",    # :26 version; :34-39 XORG_DEFAULT_OPTIONS and the doc probes; :41-42 python optional; :46-50 --enable-legacy; :52-110 the fds_bits probe
    "configure",       # :1502-1531 every option; :11820 pkg-config xorg-macros, :11963-11970 specs default
    "Makefile.am",     # :22-451 every installed header and .pc and what LEGACY gates; :455-492 the COPYING list; :512-518 the python test is `make check` only
    "meson.build",     # :22 license MIT; :26-56 the 29 modules the meson build installs
    "meson_options.txt", # :1 `legacy`, default false
    "COPYING-x11proto",
    "COPYING-xextproto",
    "COPYING-fontsproto",
    "COPYING-kbproto",
    "https://www.x.org/releases/individual/proto/", # the release listing and the .sig beside the archive
    "https://github.com/alanc.gpg",                 # the signer's key, from GitHub's account endpoint
  ]

  consulted = [
    # Read for facts only: the name x.org/protocol, the version listing, and
    # that it declares util-macros. Nothing copied.
    "pkgxdev/pantry projects/x.org/protocol/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, with a key from an account endpoint rather than a keyserver.

  signature  https://www.x.org/releases/individual/proto/xorgproto-2026.1.tar.xz.sig
  signer     Alan Coopersmith <alan.coopersmith@oracle.com>
  signed at  2026-10-03T17:53:01Z
  key from   https://github.com/alanc.gpg (GitHub's account endpoint, which binds
             the key to the account; not a keyserver)
  fingerprint 3AB285232C46AE43D8E192F4DAB0F78EA6E7E2D2, as recorded in
             go-zpkg/recipes#167. The file holds two keys, so the fingerprint is
             passed to sourcepin and is not optional.

⚠ THE RUNG, STATED: the fingerprint comes from GitHub's account page for the
signer, a third party that is not X.Org. x.org itself publishes no page naming
the signing key of the release archives.

zpkb v0.84.0 or later is needed to verify this at all: Alan's key has lapsed
and earlier sourcepin judged expiry at the time of the check (go-zpkg/zpkb#484,
fixed in #506).

⛔ NOT BUILT. No session here can run the factory. What is established is the
inputs, each traced to a line in xorgproto's own files.
EOT
}
