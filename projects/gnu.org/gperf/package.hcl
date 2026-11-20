# gnu.org/gperf — GNU gperf, the perfect hash function generator. fontconfig
# runs it at configure time (configure.ac:216-234) and at build time to generate
# fcobjshash.h, so fontconfig, which libXft needs for Tk's antialiased fonts,
# cannot be built without it. This tree carried no recipe for it at all.
#
# ⛔ WRITTEN FROM GPERF'S OWN FILES (go-zpkg/packages#431), at 3.3.
#
# ⭐ WHAT WRITING IT FOUND: nothing to choose. gperf's configure states no
# --enable or --with switch of its own (the help lists only autoconf's and
# libtool's standard ones), the documentation ships prebuilt in the tarball
# (doc/gperf.info, gperf.html, gperf.1…), and it is a C++ program, so the only
# build input beyond make is a C++ compiler, as for the other GNU recipes here.

summary = "GNU gperf: perfect hash function generator"

# src/main.cc:8-11 — "either version 3 of the License, or (at your option) any
# later version" of the GNU GPL; the same notice heads the other sources read.
# NOT READ: the gnulib files under lib/ (each carries its own notice) and the
# manual's licence (doc/gpl-3.0.texi is the GPL's text; gperf.texi was not read).
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/gperf/"
  match = "/gperf-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = ["/gperf-/", "/\\.tar\\.gz/"]
}

distributable {
  # 1831294 bytes. Recorded with `zpkb sourcepin --sig` (signature verified, see
  # provenance.note) and confirmed by a second, independent fetch-and-hash
  # (curl + shasum).
  url              = "https://ftp.gnu.org/gnu/gperf/gperf-{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "3.3" = "fd87e0aba7e43ae054837afd6cd4db03a3f2693deb3619085e6ed9d8d9604ad8"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

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

provides = [
  "bin/gperf",
]

test {
  fixture = <<EOT
foo
bar
EOT

  script = [
    "gperf --version | grep -q '^GNU gperf {{version.raw}}'",

    # The way fontconfig uses it (configure.ac:218): `gperf -L ANSI-C` on a
    # keyword list must produce a C lookup function.
    {
      run = <<EOT2
set -eu
gperf -L ANSI-C "$FIXTURE" > words.c
grep -q 'in_word_set' words.c
EOT2
    },
  ]
}

provenance {
  read = [
    "configure.ac",       # the standard autoconf/libtool switches only
    "configure",          # the option list: no --enable/--with of gperf's own
    "src/main.cc",        # :1-16 the GPLv3-or-later notice
    "doc/",               # the prebuilt manual shipped in the tarball
    "https://ftp.gnu.org/gnu/gperf/",         # the release listing and the .sig beside the archive
    "https://ftp.gnu.org/gnu/gnu-keyring.gpg", # the signer's key
  ]

  consulted = [
    # Read for facts only: that fontconfig lists gperf as a build dependency.
    # Nothing copied.
    "pkgxdev/pantry projects/freedesktop.org/fontconfig/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, against a key from GNU's maintainer keyring.

  signature   https://ftp.gnu.org/gnu/gperf/gperf-3.3.tar.gz.sig
  signed at   2025-04-20T12:12:27Z, EdDSA
  signer      Bruno Haible (Free Software Development) <bruno@clisp.org>
  fingerprint E0FFBD975397F77A32AB76ECB6301D9E1BBEAC08 (a primary key, created
              2025-01-28)
  key from    https://ftp.gnu.org/gnu/gnu-keyring.gpg, found after walking 596
              primary keys

⚠ THE RUNG, STATED: the fingerprint was read from the signature's own issuer
field (`gpg --list-packets`) and found in GNU's keyring, so the warrant is GNU's
curation of that keyring — on the same host as the tarball, which is continuity
and not independence (the same limit gnu.org/libidn2 records). No page of the
gperf project naming the fingerprint was searched for. Bruno Haible is named as
an author in src/main.cc:3-4.

zpkb v0.89.0 or later verified it (the keyring walk, go-zpkg/zpkb#511).

⛔ NOT BUILT here as the factory would. A scratch build with these arguments
(configure, make, make install) was done on darwin; `gperf -L ANSI-C` on a one-word
list produced a lookup function taking `size_t`.
EOT
}
