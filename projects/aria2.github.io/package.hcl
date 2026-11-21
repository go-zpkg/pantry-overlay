# aria2.github.io — aria2, the ultra-fast multi-protocol download utility (HTTP/HTTPS,
# FTP, SFTP, BitTorrent, Metalink). This tree carried only a dependency list for it
# (a fragment, go-zpkg/packages#440 step 1); this is the whole recipe.
#
# ⛔ WRITTEN FROM ARIA2'S OWN FILES, at 1.37.0.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#  1. EVERY LIBRARY IS A pkg-config PROBE THAT FALLS BACK TO "NOT COMPILED IN"
#     (configure.ac:211-286, :405-430, :487-526) — unless `--with-X` is given
#     EXPLICITLY, which sets with_X_requested and turns a miss into
#     ARIA2_DEP_NOT_MET (m4/aria2_arg.m4:1-16, :35-38). So every library wanted is
#     passed `--with-X`, every one not wanted `--without-X`.
#  2. pkg-config in this tree cannot find another package's .pc files (see
#     freedesktop.org/pkg-config's header). PKG_CHECK_MODULES skips the query when
#     both X_CFLAGS and X_LIBS are set, so those are given for the four libraries
#     used; the build then needs no pkg-config at all (built that way, below).
#  3. ON DARWIN THE DEFAULT TLS IS APPLE'S, NOT OPENSSL (configure.ac:326-342, README
#     :138-148): `have_ssl=yes` is set there, and `if with_openssl && have_ssl != yes`
#     (:406) then skips OpenSSL entirely. `--without-appletls` is therefore what
#     makes `--with-openssl` mean anything on a Mac.
#  4. BUT src/SimpleRandomizer.cc:44-46, :109-110 calls SecRandomCopyBytes under
#     __APPLE__ whatever the TLS library is, and the Security framework is linked
#     only by the appletls branch (configure.ac:330). Without it the link of
#     aria2c fails (`_SecRandomCopyBytes`, `_kSecRandomDefault` undefined), so the
#     frameworks are named by hand on darwin.

summary = "aria2: ultra-fast download utility (HTTP/HTTPS, FTP, SFTP, BitTorrent, Metalink)"

# COPYING is the GPL version 2 text; the README says "version 2 of the License, or
# (at your option) any later version" (printed by `aria2c --version`).
# LICENSE.OpenSSL grants the permission to link OpenSSL; no SPDX identifier names it,
# so it is stated here and not in the field.
license = "GPL-2.0-or-later"

versions {
  url = "https://github.com/aria2/aria2/releases/"

  # Release tags are release-X.Y.Z; the stored asset aria2-X.Y.Z.tar.xz is pinned
  # (a GitHub-generated archive/refs/tags tarball would lack configure).
  match = "/release-\\d+\\.\\d+\\.\\d+/"
  strip = ["/release-/"]
}

dependencies = {
  "libexpat.github.io" = "*"
  linux = {
    "gnu.org/gcc/libstdcxx" = 14
  }
  "libssh2.org" = "*"
  "openssl.org" = "^3"
  "zlib.net"    = "^1"
}

distributable {
  # 1705256 bytes. NO SIGNATURE: the release assets are the three tarballs and the
  # three binary zips, no .asc or .sig. The second witness is an independent fetch
  # from another host: NetBSD's pkgsrc distfiles mirror
  # (ftp.netbsd.org/pub/pkgsrc/distfiles/aria2-1.37.0.tar.xz) served the same bytes.
  url              = "https://github.com/aria2/aria2/releases/download/release-{{version.raw}}/aria2-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "1.37.0" = "60a420ad7085eb616cb6e2bdf0a7206d68ff3d37fb5a956dc44242eb2f79b66b"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ON, EXPLICITLY (a miss is then fatal, see the header).
      "--with-openssl",
      "--with-libz",
      "--with-libexpat",
      "--with-libssh2",

      # ⛔ OFF: Apple's own TLS (finding 3); gnutls and the three crypto libraries it
      # would otherwise fall back to (configure.ac:385-485 — only reached when OpenSSL
      # is not selected, named so a changed default shows here).
      "--without-appletls",
      "--without-gnutls",
      "--without-libnettle",
      "--without-libgmp",
      "--without-libgcrypt",

      # ⛔ OFF, no recipe in this tree: sqlite3 (configure.ac:271-286; it only reads
      # Firefox/Chrome cookie databases), c-ares (:504-526; asynchronous DNS, aria2
      # falls back to getaddrinfo), libxml2 (:251-259; expat is used instead).
      # libuv (:239-248) is off by default and named off.
      "--without-sqlite3",
      "--without-libcares",
      "--without-libxml2",
      "--without-libuv",

      # Default off (configure.ac:67-68, :76-77), named: allocators, the library
      # build, -Werror.
      "--without-tcmalloc",
      "--without-jemalloc",
      "--disable-libaria2",
      "--disable-werror",
    ]

    # pkg-config is not used (finding 2): each library's flags are given.
    OPENSSL_CFLAGS = "-I{{deps.openssl.org.prefix}}/include"
    OPENSSL_LIBS   = "-L{{deps.openssl.org.prefix}}/lib -lssl -lcrypto"
    ZLIB_CFLAGS    = "-I{{deps.zlib.net.prefix}}/include"
    ZLIB_LIBS      = "-L{{deps.zlib.net.prefix}}/lib -lz"
    EXPAT_CFLAGS   = "-I{{deps.libexpat.github.io.prefix}}/include"
    EXPAT_LIBS     = "-L{{deps.libexpat.github.io.prefix}}/lib -lexpat"
    LIBSSH2_CFLAGS = "-I{{deps.libssh2.org.prefix}}/include"
    LIBSSH2_LIBS   = "-L{{deps.libssh2.org.prefix}}/lib -lssh2"

    # finding 4
    darwin = {
      LDFLAGS = "-framework Security -framework CoreFoundation"
    }

    linux = {
      LDFLAGS = "-Wl,-rpath,{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.zlib.net.prefix}}/lib -Wl,-rpath,{{deps.libexpat.github.io.prefix}}/lib -Wl,-rpath,{{deps.libssh2.org.prefix}}/lib"
    }
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = [
  "bin/aria2c",
]

test {
  script = [
    {
      run = <<EOT
set -eu
"{{prefix}}/bin/aria2c" --version > version.txt 2>&1
grep -q '^aria2 version {{version.raw}}$' version.txt
# every library probe that falls back silently (finding 1) would drop its feature
# or its name from these two lines
grep -q 'Enabled Features:.*HTTPS' version.txt
grep -q 'Enabled Features:.*SFTP' version.txt
grep -q 'Enabled Features:.*XML-RPC' version.txt
grep -q 'Libraries:.*OpenSSL/3' version.txt
grep -q 'Libraries:.*expat/' version.txt
grep -q 'Libraries:.*libssh2/' version.txt
grep -q 'Libraries:.*zlib/' version.txt
# and the libraries named off must stay off
if grep -q 'SQLite\|c-ares\|libxml2\|GnuTLS' version.txt; then exit 1; fi
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",         # :54-77 the arguments, :211-286 zlib/libuv/xml/sqlite, :316-342 appletls, :405-430 openssl, :436-485 nettle/gmp/gcrypt, :487-526 libssh2/cares
    "m4/aria2_arg.m4",      # :1-38 WITH/WITHOUT/ENABLE/DISABLE and ARIA2_DEP_NOT_MET
    "src/SimpleRandomizer.cc", # :44-46, :109-110 SecRandomCopyBytes
    "README.rst",           # :115-160 which TLS/crypto library serves which feature, :138-148 OSX
    "COPYING",              # GNU GPL version 2
    "LICENSE.OpenSSL",      # the OpenSSL linking permission
  ]

  consulted = []

  note = <<EOT
NO SIGNATURE EXISTS; the pin is a SHA-256 computed by fetching the release asset from
GitHub and agreed by a second fetch from NetBSD's pkgsrc distfiles mirror
(60a420ad... both).

NO CA BUNDLE IS COMPILED IN: `--with-ca-bundle` (configure.ac:79-83) is not given, because
no recipe in this tree provides a CA bundle at a known path; aria2c's `--ca-certificate`
option names one at run time, and OpenSSL's own default locations apply otherwise.

BUILT AND TESTED ON A MACHINE, NOT BY THE FACTORY: configure, make and make install
of this source, darwin/arm64, with PATH holding only /usr/bin:/bin (no pkg-config),
Homebrew's openssl 3 and libssh2 by directory, and the macOS SDK's expat and zlib
exposed through a directory holding only their headers and libraries.
`aria2c --version` printed "Enabled Features: BitTorrent, GZip, HTTPS, Message
Digest, Metalink, XML-RPC, SFTP" and "Libraries: zlib/1.2.12 expat/2.7.4
OpenSSL/3.6.0e libssh2/1.11.1". The first attempt, without the darwin LDFLAGS,
failed to link (finding 4).

⛔ NOT BUILT BY THE FACTORY, NOT BUILT ON LINUX.
EOT
}
