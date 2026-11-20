# x.org/libpthread-stubs — not a library: a pkg-config file, pthread-stubs.pc,
# that tells libxcb and libX11 whether -pthread is needed. Third of the chain
# go-zpkg/recipes#167 orders (libX11 configure.ac:238 adds `pthread-stubs` to its
# requirement list).
#
# ⛔ WRITTEN FROM ITS OWN FILES (go-zpkg/packages#431), at 0.5.
#
# ⭐ WHAT WRITING IT FOUND: the whole package is ONE detection with two outcomes.
# configure.ac:9-26 probes fifteen pthread functions in libc and :29-36 turn the
# answer into the .pc's flags — nothing needed when libc has them all (glibc
# since 2.34, macOS), `-pthread` otherwise (older glibc, musl split builds). So
# the artifact differs by the builder's libc, and the test below asserts the
# outcome is one of the two the source can produce.

summary = "X.Org libpthread-stubs: the pkg-config module stating whether -pthread is needed"

# COPYING:1-12 "Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software … to deal in the Software without
# restriction" — the MIT licence text.
license = "MIT"

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/libpthread-stubs-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = ["/libpthread-stubs-/", "/\\.tar\\.xz/"]
}

distributable {
  # 56980 bytes, signature verified (see provenance.note) and confirmed by a
  # second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/lib/libpthread-stubs-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "0.5" = "59da566decceba7c2a7970a4a03b48d9905f1262ff94410a649224e33d2442bc"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  # configure.ac states no --enable/--with option at all: the only switch is
  # the libc probe at :26, which has no flag to force either outcome.
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
    # Makefile.am:1-2 installs the .pc under $(libdir)/pkgconfig.
    "test -f \"{{prefix}}/lib/pkgconfig/pthread-stubs.pc\"",
    "grep -q '^Name: pthread stubs' \"{{prefix}}/lib/pkgconfig/pthread-stubs.pc\"",

    # ⛔ THE OUTCOME OF THE LIBC PROBE, read off the artifact: configure.ac:30-31
    # empty flags, or :34-35 `-pthread` for both. Anything else is a template
    # that was not filled in.
    {
      run = <<EOT
set -eu
pc="{{prefix}}/lib/pkgconfig/pthread-stubs.pc"
if grep -q '@PKG_CONFIG' "$pc"; then
  echo "pthread-stubs.pc carries an unsubstituted placeholder" >&2
  exit 1
fi
libs=$(grep '^Libs:' "$pc" | sed 's/^Libs: *//')
cflags=$(grep '^Cflags:' "$pc" | sed 's/^Cflags: *//')
if test "$libs" != "$cflags"; then
  echo "Libs ($libs) and Cflags ($cflags) differ, which neither outcome of the probe produces" >&2
  exit 1
fi
case "$libs" in
  "" | "-pthread") echo "libc probe outcome: '$libs'" ;;
  *) echo "unexpected flags '$libs'" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac", # :9-26 the fifteen-function libc probe; :29-36 the two outcomes; :41 the only output
    "Makefile.am",  # :1-2 the .pc is the only installed file
    "COPYING",      # :1-12 the MIT text
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://github.com/alanc.gpg",               # the signer's key, from GitHub's account endpoint
  ]

  consulted = [
    # Read for facts only: the name x.org/libpthread-stubs. Nothing copied.
    "pkgxdev/pantry projects/x.org/libpthread-stubs/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, with a key from an account endpoint rather than a keyserver.

  signature   https://www.x.org/releases/individual/lib/libpthread-stubs-0.5.tar.xz.sig
  signer      Alan Coopersmith <alan.coopersmith@oracle.com>
  fingerprint 4A193C06D35E7C670FA4EF0BA2FB9E081F2D130E
  key from    https://github.com/alanc.gpg (GitHub's account endpoint)

This is the second of the two keys in that file, not the 3AB28523… of
go-zpkg/recipes#167 (see x.org/xtrans for how sourcepin showed it). The rung is
GitHub's account page, a third party that is not X.Org.

zpkb v0.84.0 or later is needed (the key has lapsed: go-zpkg/zpkb#484).

⛔ NOT BUILT here as the factory would; the recipe's own checks were confirmed by
hand against a scratch build.
EOT
}
