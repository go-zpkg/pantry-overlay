# x.org/xtrans — the X Transport library: not a library at all but C source
# files and an m4 macro that other X projects include and compile into
# themselves. Second of the chain go-zpkg/recipes#167 orders; libX11 needs it
# at AUTOCONF time as well as build time (libX11 configure.ac:88-97).
#
# ⛔ WRITTEN FROM XTRANS'S OWN FILES (go-zpkg/packages#431), at 1.6.0.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. "Because xtrans is included into other modules rather than being linked
#      with, these defines have to be added to the cflags line"
#      (configure.ac:42-43). fchown() is PROBED (:47) and the result is baked
#      into xtrans.pc as -DHAS_FCHOWN, so the artifact varies with the builder
#      unless the test reads it. It does below.
#   2. The only other detection is the documentation toolchain (:36-40).

summary = "X.Org xtrans: the X transport source files and macro other X libraries compile in"

# COPYING holds five notices (the line numbers are the notice headings):
#   :1   The Open Group — "Permission to use, copy, modify, distribute, and sell
#        … Except as contained in this notice, the name of The Open Group shall
#        not be used": MIT-open-group;
#   :27  NCR — "Permission to use, copy, modify, and distribute … without fee":
#        HPND;
#   :51  Oracle — "Permission is hereby granted, free of charge": MIT;
#   :74  Sebastien Marineau and Holger Veit — "Permission is hereby granted,
#        free of charge": MIT;
#   :103 Keith Packard — "Permission to use, copy, modify, distribute, and sell"
#        with the name-in-advertising clause: HPND-sell-variant.
license = "MIT AND MIT-open-group AND HPND AND HPND-sell-variant"

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/xtrans-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = ["/xtrans-/", "/\\.tar\\.xz/"]
}

distributable {
  # 177156 bytes, signature verified (see provenance.note) and confirmed by a
  # second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/lib/xtrans-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "1.6.0" = "faafea166bf2451a173d9d593352940ec6404145c5d1da5c213423ce4d359e92"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ configure:1514 "--enable-docs … (default: yes)" and :1519-1522
      # --with-xmlto / --with-fop / --with-xsltproc "default: auto". Each is
      # a detection of the builder's documentation tools; all four off.
      "--disable-docs",
      "--with-xmlto=no",
      "--with-fop=no",
      "--with-xsltproc=no",
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
    # Makefile.am:3-11 the seven files, :14 the macro, :17 the .pc
    "test -f \"{{prefix}}/include/X11/Xtrans/Xtrans.h\"",
    "test -f \"{{prefix}}/include/X11/Xtrans/Xtranssock.c\"",
    "test -f \"{{prefix}}/include/X11/Xtrans/transport.c\"",
    "test -f \"{{prefix}}/share/aclocal/xtrans.m4\"",
    "test -f \"{{prefix}}/share/pkgconfig/xtrans.pc\"",

    # ⛔ configure.ac:47 and :56: the defines are fixed into the .pc, and the
    # sticky-bit one is unconditional. fchown() exists on every platform this
    # tree builds for, so a missing -DHAS_FCHOWN is a probe that failed.
    "grep -q -- '-DHAS_STICKY_DIR_BIT' \"{{prefix}}/share/pkgconfig/xtrans.pc\"",
    "grep -q -- '-DHAS_FCHOWN' \"{{prefix}}/share/pkgconfig/xtrans.pc\"",

    # The macro libX11 reads at autoconf time (configure.ac:88-97 there).
    "grep -q 'XTRANS_CONNECTION_FLAGS' \"{{prefix}}/share/aclocal/xtrans.m4\"",
  ]
}

provenance {
  read = [
    "configure.ac", # :24 version; :36-40 doc probes; :42-49 fchown probed into the .pc; :56 sticky bit fixed
    "configure",    # :1514 --enable-docs default yes; :1519-1522 the three --with doc tools, default auto
    "Makefile.am",  # :3-11 the installed sources; :13-17 the macro and the .pc
    "COPYING",      # :1-103 the five notices cited in the licence comment
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://github.com/alanc.gpg",               # the signer's key, from GitHub's account endpoint
  ]

  consulted = [
    # Read for facts only: the name x.org/xtrans and the version listing.
    "pkgxdev/pantry projects/x.org/xtrans/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, with a key from an account endpoint rather than a keyserver.

  signature   https://www.x.org/releases/individual/lib/xtrans-1.6.0.tar.xz.sig
  signer      Alan Coopersmith <alan.coopersmith@oracle.com>
  fingerprint 4A193C06D35E7C670FA4EF0BA2FB9E081F2D130E
  key from    https://github.com/alanc.gpg (GitHub's account endpoint)

⚠ NOT THE FINGERPRINT go-zpkg/recipes#167 RECORDED. That file holds two keys,
and this release is signed by the other one (the recorded 3AB285232C46…, which
signed xorgproto 2026.1). Both carry Alan Coopersmith's identity in the same
account file; sourcepin said so itself when given the first ("signed by
4A193C06… (Alan Coopersmith …), not by the 3AB28523… you named — the signature
is VALID"). The rung is therefore GitHub's account page, a third party that is
not X.Org; x.org publishes no page naming the signing keys.

zpkb v0.84.0 or later is needed (the key has lapsed: go-zpkg/zpkb#484).

⛔ NOT BUILT. No session here can run the factory. What is established is the
inputs, each traced to a line in xtrans's own files.
EOT
}
