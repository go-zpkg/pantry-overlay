# x.org/xcb — libxcb, the X protocol C binding libX11 is built on. Sixth of the
# chain go-zpkg/recipes#167 orders. The project name is the one this tree's
# consumers already declare (x.org/xcb, not x.org/libxcb).
#
# ⛔ WRITTEN FROM LIBXCB'S OWN FILES (go-zpkg/packages#431), at 1.17.0.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. XDMCP SUPPORT IS CHOSEN BY DETECTION, with no switch. configure.ac:62-74
#      asks pkg-config for `xdmcp` and, only if found, adds `xdmcp` to NEEDED,
#      defines HASXDMAUTH and prints "XDM support: yes" (:307). A builder
#      without libXdmcp builds a libxcb that cannot do XDM-AUTHORIZATION-1, the
#      same package name behind two libraries. It is declared below, which makes
#      the detection deterministic, and the test reads it off xcb.pc.
#   2. Twenty-eight extensions are built by default and four are not. Each is a
#      `--enable-<name>` defaulting yes/no (m4/xcb.m4:49-53; the list is
#      configure.ac:222-249 and configure:1625-1652). DRI3 alone is `auto`
#      (:227, `$have_sendmsg`): decided by a socket probe, and `--enable-dri3`
#      turns a miss into a fatal "dependencies are not met" (m4/xcb.m4:60-63).
#   3. libpthread-stubs is required only OFF linux/darwin/solaris/BSDs
#      (configure.ac:56-59). The pantry's recipe declares it unconditionally and
#      libX11 asks for it itself, so it is NOT declared here: on the two
#      platforms this tree builds for, libxcb never reads it.
#   4. Python is a build input (AM_PATH_PYTHON([3.0]), :15) and xcb-proto's
#      module is found through xcb-proto.pc's `pythondir` (:88-92).
#   5. `check`, the unit-test library, is also detected (:40-41) and only gates
#      `make check`; nothing installed depends on it, and no switch disables it.

summary = "X.Org libxcb: the X protocol C binding"

# COPYING:1-… "Copyright (C) 2001-2006 Bart Massey, Jamey Sharp, and Josh
# Triplett. All Rights Reserved. Permission is hereby granted, free of charge,
# to any person obtaining a copy of this software … to deal in the Software
# without restriction": the MIT licence text. COPYING holds that one notice
# (grep for "Copyright" finds only :1).
license = "MIT"

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/libxcb-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = ["/libxcb-/", "/\\.tar\\.xz/"]
}

dependencies = {
  # configure.ac:55 `xau >= 0.99.2` is mandatory (PKG_CHECK_MODULES(NEEDED)).
  "x.org/xau"   = "^1"
  # configure.ac:62-74, see finding 1: optional by detection, declared so it is
  # always found.
  "x.org/xdmcp" = "^1"
}

distributable {
  # 455208 bytes, signature verified (see provenance.note) and confirmed by a
  # second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/lib/libxcb-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "1.17.0" = "599ebf9996710fea71622e6e184f3a8ad5b43d0e5fa8c4e407123c88a59a6d55"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
    "python.org"                 = "^3"
    # configure.ac:54 `xcb-proto >= 1.17.0`.
    "x.org/protocol/xcb"         = ">=1.17.0"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ DOCUMENTATION: configure:1623 `--enable-devel-docs` is the
      # developer documentation (XORG_ENABLE_DEVEL_DOCS, configure.ac:32) and
      # :1670 `--with-doxygen` defaults to auto (:33), which also probes `dot`
      # (:35-38). Both off.
      "--disable-devel-docs",
      "--without-doxygen",

      # ⛔ finding 2: the one extension decided by a probe, made fatal.
      "--enable-dri3",

      # configure:1673 `--with-serverside-support` is EXPERIMENTAL and default
      # no (configure.ac:251); stated so its default cannot change silently.
      "--without-serverside-support",
    ]
    # The other extension switches keep their stated defaults — yes for 24,
    # and off for GE, Xevie, Xprint and SELinux (configure.ac:228, :239, :245,
    # :246): Xprint and Xevie are extensions X.Org removed from the server, and
    # SELinux would need libselinux, which this tree does not carry. libX11 and
    # Tk use none of the four. The test below asserts exactly which .pc files
    # exist, so a changed default shows.
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

test {
  script = [
    "test -f \"{{prefix}}/include/xcb/xcb.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/xcb.pc\"",

    # ⛔ finding 1, read off the artifact: XDM support is in iff xcb.pc names
    # xdmcp in Requires.private (configure.ac:67).
    "grep -q '^Requires.private:.*xau' \"{{prefix}}/lib/pkgconfig/xcb.pc\"",
    "grep -q '^Requires.private:.*xdmcp' \"{{prefix}}/lib/pkgconfig/xcb.pc\"",

    # ⛔ finding 2: the extensions this recipe builds and the four it does not.
    {
      run = <<EOT
set -eu
pc="{{prefix}}/lib/pkgconfig"
for e in composite damage dbe dpms dri2 dri3 glx present randr record render res screensaver shape shm sync xf86dri xfixes xinerama xinput xkb xtest xv xvmc; do
  test -f "$pc/xcb-$e.pc" || { echo "xcb-$e.pc missing" >&2; exit 1; }
done
for e in ge xevie xprint xselinux; do
  if test -e "$pc/xcb-$e.pc"; then
    echo "xcb-$e.pc is installed, which this recipe leaves at its default of off" >&2
    exit 1
  fi
done
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",  # :15 python; :32-38 docs; :40-41 check; :54-60 xcb-proto and NEEDED; :62-74 xdmcp by detection; :88-92 pythondir; :156-162 queue size; :222-249 the extensions; :251 serverside
    "configure",     # :1623-1673 every switch and its default
    "m4/xcb.m4",     # :37-67 XCB_EXTENSION: --enable-<name>, the auto rule and the fatal on a miss
    "xcb.pc.in",     # Requires.private: @NEEDED@
    "COPYING",       # :1-… the one MIT notice
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://github.com/mattst88.gpg",            # the signer's key, from GitHub's account endpoint
  ]

  consulted = [
    # Read for facts only: the name x.org/xcb, the version listing, that it
    # enables dri3, ge, xevie, xprint and selinux, and that it declares xau and
    # xdmcp. Nothing copied. Its --enable-selinux is NOT carried: see above.
    "pkgxdev/pantry projects/x.org/xcb/package.yml",
  ]

  note = <<EOT
⚠ THIS RELEASE IS NOT SIGNED BY ALAN COOPERSMITH.

  signature   https://www.x.org/releases/individual/lib/libxcb-1.17.0.tar.xz.sig
  signer      Matt Turner <mattst88@gmail.com>, signing SUBKEY
              16238A7D92448B02B7B10344B6B1CEAE5103DB07 of primary
              3BB639E56F861FA2E86505690FDD682D974CA72A
  key from    https://github.com/mattst88.gpg (GitHub's account endpoint)

The same key as x.org/protocol/xcb (xcb-proto 1.17.0): see its note for how the
signer was identified and for the rung — GitHub's account page and the
openpgp.org record by fingerprint, and no page of X.Org's or xcb's own was found
(xcb.freedesktop.org was not searched).

zpkb v0.84.0 or later is needed (go-zpkg/zpkb#484).

⛔ NOT BUILT here as the factory would. A scratch build with these arguments
(configure, make, make install) was done on darwin with xorgproto, xcb-proto,
libXau and libXdmcp on PKG_CONFIG_PATH: it produced xcb.pc with
`Requires.private: xau >= 0.99.2 xdmcp` and 25 .pc files.
EOT
}
