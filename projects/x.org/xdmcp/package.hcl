# x.org/xdmcp — libXdmcp, the X Display Manager Control Protocol library.
# Fifth of the chain go-zpkg/recipes#167 orders (with x.org/xau); libxcb links it.
# The project name is the one this tree's consumers already declare.
#
# ⛔ WRITTEN FROM LIBXDMCP'S OWN FILES (go-zpkg/packages#431), at 1.1.5.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. A random-number source chosen by DETECTION, with an optional external
#      library in the chain: configure.ac:73-79 links arc4random_buf, and when
#      the libc has none (glibc before 2.36) looks for `libbsd-overlay` through
#      pkg-config, `[:]` on a miss — so the artifact links libbsd on a builder
#      that has it and falls back to getentropy (:82) on one that does not. No
#      flag forces either. This recipe declares no libbsd, so the test refuses a
#      library that links one.
#   2. `--enable-unit-tests` defaults to YES (configure:1585): the build compiles
#      a test suite nobody installs. Named off.
#   3. Wraphelp.c, the DES code behind XDM-AUTHORIZATION-1, states no licence in
#      its header (:8-62 are a derivation note and an export notice) — see the
#      licence comment.

summary = "X.Org libXdmcp: X Display Manager Control Protocol library"

# COPYING:1-23 — "Copyright 1989, 1998  The Open Group … Permission to use, copy,
# modify, distribute, and sell … Except as contained in this notice, the name of
# The Open Group shall not be used": MIT-open-group, authored by Keith Packard
# (:23).
#
# ⚠ NOT COVERED BY THAT TEXT: Wraphelp.c:8-18 is a DES implementation by Eric
# Young (1991) "derived from OpenBSD Revision 1.3", and its header carries only
# export and import notices (:20-62) and no grant of its own. Its terms are not
# stated in the file, so no SPDX identifier is claimed for it here.
license = "MIT-open-group"

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/libXdmcp-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = ["/libXdmcp-/", "/\\.tar\\.xz/"]
}

dependencies = {
  # xdmcp.pc.in: `Requires: xproto`; configure.ac:85 PKG_CHECK_MODULES(XDMCP, xproto).
  "x.org/protocol" = "*"
}

distributable {
  # 297596 bytes, signature verified (see provenance.note) and confirmed by a
  # second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/lib/libXdmcp-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "1.1.5" = "d8a5222828c3adab70adf69a5583f1d32eb5ece04304f7f8392b6a353aa2228c"
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

      # configure:1583-1585 `--enable-docs` default yes, `--enable-unit-tests`
      # default yes; :1598-1601 the three --with doc tools default auto.
      "--disable-docs",
      "--disable-unit-tests",
      "--with-xmlto=no",
      "--with-fop=no",
      "--with-xsltproc=no",

      # configure:1584 / :1603: lint library off, lint checker auto.
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
    # Makefile.am:3 the library, :29 the headers; xdmcp.pc.in the module.
    "test -f \"{{prefix}}/include/X11/Xdmcp.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/xdmcp.pc\"",
    "grep -q '^Requires: xproto' \"{{prefix}}/lib/pkgconfig/xdmcp.pc\"",

    # ⛔ THE LIBBSD DETECTION, read off the artifact: the installed library must
    # not name libbsd, which this recipe does not declare (configure.ac:73-79).
    {
      run = <<EOT
set -eu
n=0
for f in "{{prefix}}"/lib/libXdmcp.so* "{{prefix}}"/lib/libXdmcp.*dylib; do
  test -e "$f" || continue
  n=$((n+1))
  if grep -aq 'libbsd' "$f"; then
    echo "$f links libbsd, which this recipe does not declare" >&2
    exit 1
  fi
done
test "$n" -ge 1 || { echo "no shared libXdmcp installed" >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",  # :42-51 xorg-macros and doc probes; :60 recvfrom; :73-82 arc4random_buf, libbsd-overlay, getentropy; :85 xproto; :87-92 Wraphelp.c; :101 unit tests
    "configure",     # :1583-1603 the option list and its defaults
    "xdmcp.pc.in",   # Requires: xproto
    "Makefile.am",   # :3 libXdmcp.la; :29 the headers
    "COPYING",       # :1-23 the Open Group notice
    "Wraphelp.c",    # :1-62 the DES derivation and export notices; no licence grant
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://github.com/alanc.gpg",               # the signer's key, from GitHub's account endpoint
  ]

  consulted = [
    # Read for facts only: the name x.org/xdmcp and the version listing.
    "pkgxdev/pantry projects/x.org/xdmcp/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, with a key from an account endpoint rather than a keyserver.

  signature   https://www.x.org/releases/individual/lib/libXdmcp-1.1.5.tar.xz.sig
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
