# nodejs.org — Node.js: the V8-based JavaScript runtime, with npm.
#
# ⛔ WRITTEN FROM NODE'S OWN `configure --help` AND RELEASE FILES
# (go-zpkg/packages#431, packages#440 step 1), at 26.13.1, replacing a recipe
# that was a bare dependency list from the pantry: it named no versions, no
# source and no build. Node bundles about thirty dependencies under deps/ and
# `configure` offers a `--shared-*` switch for most of them; the choice of
# which ones come from this tree and which from the tarball is therefore the
# recipe's, and is stated below instead of being left to the defaults.

summary = "Node.js: the JavaScript runtime built on V8, with the npm package manager"

# LICENSE at the root of the tarball: the MIT licence for Node itself, followed
# by the licences of everything under deps/ and tools/ that is bundled.
license = "MIT"

# The directory listing of the release site: one `vX.Y.Z/` entry per release.
# The pattern has no suffix after the third number, so `v27.0.0-alpha.0.1.1/`,
# the nightly and rc directories are not offered.
versions {
  url   = "https://nodejs.org/dist/"
  match = "/v\\d+\\.\\d+\\.\\d+\\//"
  strip = [
    "/^v/",
    "/\\/$/",
  ]
}

dependencies = {
  "openssl.org" = "^3"
  "unicode.org" = "^73"
  "zlib.net"    = "^1"
}

distributable {
  url              = "https://nodejs.org/dist/v{{version.raw}}/node-v{{version.raw}}.tar.xz"
  strip-components = 1

  # 63411840 bytes, recorded with `zpkb sourcepin --version 26.13.1`.
  #
  # ⭐ THE WITNESS IS A SIGNED CHECKSUM FILE. Node signs
  # https://nodejs.org/dist/v26.13.1/SHASUMS256.txt.asc, a clear-signed
  # message, not the tarball, so `zpkb sourcepin --sig` (a detached signature
  # of the served file) does not apply. The message was verified with gpg
  # against the key it names, EdDSA 5BE8A3F6C8A5C01D106C0AD820B1A390B168D356
  # (Antoine du Hamel, signed 2026-11-11), which is listed in the "Release
  # keys" section of the README of github.com/nodejs/node; the key file was
  # taken from github.com/nodejs/release-keys (keys/<fingerprint>.asc), not
  # from a keyserver. Line 24 of that message is the digest below, for
  # node-v26.13.1.tar.xz.
  sha256 = {
    "26.13.1" = "a7f6204ff63b6a2cd274d48903285abb86ed53a99070e532d4c2fd787457d9e6"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/make"               = "*"
    "python.org"                 = "^3"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # From this tree (each is a dependency above): OpenSSL (a CVE fix must
      # not wait for a Node release), zlib, and ICU for Intl.
      "--shared-openssl",
      "--shared-zlib",
      "--with-intl=system-icu",

      # Bundled and kept bundled: libuv, llhttp, nghttp2, nghttp3, ngtcp2,
      # cares, brotli, zstd, sqlite, libffi, simdjson, simdutf, ada, merve,
      # nbytes, uvwasi, highway, abseil, hdr_histogram, lief, perfetto, V8.
      # None is a dependency of this recipe, and none of the --shared-* switches
      # for them is given, so the host's copies are never picked up.

      # Features left at configure's default, ON: npm, the inspector, SQLite,
      # FFI, the V8 snapshot and code cache, amaro.
      # Left at the default, OFF: corepack, QUIC and DTLS (experimental),
      # LTO and PGO, debug builds, sanitizers, the shared library.
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

provides = [
  "bin/node",
  "bin/npm",
  "bin/npx",
]

test {
  script = [
    "node --version | grep -q \"v{{version.raw}}\"",
    "npm --version",
    "node -e 'if (process.versions.openssl.split(\".\")[0] !== \"3\") process.exit(1)'",
    "node -e 'require(\"zlib\").gunzipSync(require(\"zlib\").gzipSync(\"x\"))'",
    "node -e 'if (new Intl.NumberFormat(\"de-DE\").format(1234.5) !== \"1.234,5\") process.exit(1)'",
    "node -e 'require(\"node:sqlite\")'",
    "node -p '(2n ** 100n).toString()'",
  ]
}

provenance {
  read = [
    "configure --help",
    "README.md",     # "Release keys": the releasers' fingerprints
    "BUILDING.md",
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the switches are those of
./configure --help of the tarball (sha256 above), checked by reading, and
`zpkb lint` was run.

⚠ UNKNOWNS: (1) --shared-openssl was not exercised against the openssl.org
recipe of this tree; node's own build file expects OpenSSL 3 and a header
layout that --shared-openssl-includes may have to be given for. (2) The
version source is the release directory listing, so it also offers every
older major; the newest one is pinned. (3) configure needs a Python 3 and the
python.org recipe of this tree was not checked for it.

⚠ pkgxdev/pantry was read only as the former content of this very file.
EOT
}
