# x.org/protocol/xcb — xcb-proto, the XML descriptions of the X protocol and its
# extensions, plus the Python module (xcbgen) that turns them into C. libxcb
# generates its sources from it at build time. Fourth of the chain
# go-zpkg/recipes#167 orders. The name is the one this tree's consumers declare;
# the pantry's recipe for the same upstream project carries it.
#
# ⛔ WRITTEN FROM XCB-PROTO'S OWN FILES (go-zpkg/packages#431), at 1.17.0.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. Its Python is a BUILD input that leaks into the artifact: AM_PATH_PYTHON
#      (configure.ac:17) puts xcbgen in the interpreter's own site-packages
#      path for the Python it found, and xcb-proto.pc records that absolute
#      path as `pythondir` (xcb-proto.pc.in:6-7). libxcb reads it from there.
#      So python.org is declared at build, and the test imports xcbgen with the
#      interpreter the .pc names.
#   2. The one detection is xmllint (:11-15), which only gates the schema
#      validation of `make check`; nothing installed depends on it.
#
# The pantry's recipe also exports a runtime PYTHONPATH; this one does not,
# because the consumer finds the module through the .pc's pythondir.

summary = "X.Org xcb-proto: X protocol descriptions and the xcbgen generator module"

# COPYING:1-12 — "Copyright (C) 2001-2006 Bart Massey, Jamey Sharp, and Josh
# Triplett … Permission is hereby granted, free of charge … to deal in the
# Software without restriction": the MIT licence text.
license = "MIT"

versions {
  url   = "https://www.x.org/releases/individual/proto/"
  match = "/xcb-proto-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = ["/xcb-proto-/", "/\\.tar\\.xz/"]
}

distributable {
  # 151748 bytes, signature verified (see provenance.note) and confirmed by a
  # second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/proto/xcb-proto-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "1.17.0" = "2c1bacd2110f4799f74de6ebb714b94cf6f80fb112316b1219480fd22562148c"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    "python.org"   = "^3"
  }

  # configure.ac states no --enable/--with option; the Python is found by
  # AM_PATH_PYTHON on PATH, which the declared python.org provides.
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
  dependencies = {
    "python.org" = "^3"
  }

  script = [
    # Makefile.am:3-4 the .pc; configure.ac:19 the XML directory.
    "test -f \"{{prefix}}/share/pkgconfig/xcb-proto.pc\"",
    "test -f \"{{prefix}}/share/xcb/xproto.xml\"",
    "test -f \"{{prefix}}/share/xcb/xinput.xml\"",

    # ⛔ THE LEAK, read off the artifact: the pythondir the .pc records must
    # exist and hold xcbgen, and that module must import under the Python the
    # test has.
    {
      run = <<EOT
set -eu
pc="{{prefix}}/share/pkgconfig/xcb-proto.pc"
# xcb-proto.pc.in:6-7 writes pythondir as <sysroot><PYTHON_PREFIX>/lib/pythonX.Y/
# site-packages with the two variables left unexpanded, and PYTHON_PREFIX is
# the prefix itself; so what follows the variable is relative to the prefix.
rel=$(grep '^pythondir=' "$pc" | sed 's|.*{PYTHON_PREFIX}||')
case "$rel" in
  /lib/python*/site-packages) ;;
  *) echo "pythondir tail '$rel' is not lib/pythonX.Y/site-packages" >&2; exit 1 ;;
esac
dir="{{prefix}}$rel"
test -d "$dir/xcbgen"
PYTHONPATH="$dir" python3 -c "from xcbgen import xtypes, state"
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",      # :11-15 xmllint only gates make check; :17 AM_PATH_PYTHON; :19 the XML directory
    "Makefile.am",       # :1 the subdirectories; :3-4 the .pc
    "xcb-proto.pc.in",   # :5-7 xcbincludedir and the recorded pythondir
    "COPYING",           # :1-12 the MIT text
    "https://www.x.org/releases/individual/proto/", # the release listing and the .sig beside the archive
    "https://github.com/mattst88.gpg",              # the signer's key, from GitHub's account endpoint
    "https://keys.openpgp.org/vks/v1/by-fingerprint/16238A7D92448B02B7B10344B6B1CEAE5103DB07", # who owns that signing subkey — see note
  ]

  consulted = [
    # Read for facts only: the name x.org/protocol/xcb, the version listing, and
    # that it exports a runtime PYTHONPATH. Nothing copied.
    "pkgxdev/pantry projects/x.org/protocol/xcb/package.yml",
  ]

  note = <<EOT
⚠ THIS RELEASE IS NOT SIGNED BY ALAN COOPERSMITH.

  signature   https://www.x.org/releases/individual/proto/xcb-proto-1.17.0.tar.xz.sig
  signed at   2024-04-15, algorithm EdDSA, issuer fingerprint
              16238A7D92448B02B7B10344B6B1CEAE5103DB07 (a signing SUBKEY)
  primary     3BB639E56F861FA2E86505690FDD682D974CA72A
  identity    Matt Turner <mattst88@gmail.com> / <mattst88@freedesktop.org>
  key from    https://github.com/mattst88.gpg (GitHub's account endpoint),
              which holds that primary and that subkey

How the signer was found: sourcepin refused the signature against Alan's key
file ("no key in the file you passed has the id B6B1CEAE5103DB07"). `gpg
--list-packets` on the .sig gave the issuer fingerprint; the owner was read from
keys.openpgp.org by that fingerprint (identity only, not used as the key
source), and the key bytes then taken from the owner's GitHub account.

⚠ THE RUNG, STATED: the fingerprint of the SIGNING SUBKEY is read from the
signature itself, and the warrant that Matt Turner holds it is GitHub's account
page for mattst88 plus the openpgp.org record. No page the xcb project or X.Org
controls was found naming it: only GitHub's account endpoint and openpgp.org
were consulted, and xcb.freedesktop.org was NOT searched for a key page. The
libxcb 1.17.0 release carries the same issuer key.

zpkb v0.84.0 or later is needed to verify (go-zpkg/zpkb#484).

⛔ NOT BUILT here as the factory would; the recipe's own checks were confirmed by
hand against a scratch build.
EOT
}
