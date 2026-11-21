# qpdf.sourceforge.io — qpdf, the command-line tool and C++ library for structural,
# content-preserving transformation of PDF files (encrypt, decrypt, linearize, merge,
# split, repair), with fix-qdf and zlib-flate. This tree carried only a dependency
# list for it (a fragment, go-zpkg/packages#440 step 1); this is the whole recipe.
#
# ⛔ WRITTEN FROM QPDF'S OWN FILES, at 12.4.2.
#
# ⭐⭐ WHAT WRITING IT FOUND: qpdf's crypto provider is chosen by a DEFAULT THAT
# PROBES, and the fragment named a library nobody here provides.
#   CMakeLists.txt:87     USE_IMPLICIT_CRYPTO defaults ON: "any available external
#                         crypto provider". libqpdf/CMakeLists.txt:242-303 then
#                         takes OpenSSL AND GnuTLS when each is found, native only
#                         when neither is, and :308-314 makes GnuTLS the DEFAULT
#                         provider whenever it is present.
# gnutls.org has no recipe in this tree, so the fragment's `gnutls.org` dependency
# could never be satisfied. This recipe turns implicit selection OFF and asks for
# OpenSSL by name (REQUIRE_CRYPTO_OPENSSL, :242, :268-270: a miss is an error, not a
# silent fallback), GnuTLS off (REQUIRE_CRYPTO_GNUTLS stays OFF, :275), and the
# native provider ON as the documented always-available alternative
# (REQUIRE_CRYPTO_NATIVE, CMakeLists.txt:91-93, :295-297) so QPDF_CRYPTO_PROVIDER
# (libqpdf/QPDFCryptoProvider.cc:58) can still select it. DEFAULT_CRYPTO=openssl
# (:305) states the default instead of leaving it to the order at :308-314.
# The other probes, each named below:
#   zlib    libqpdf/CMakeLists.txt:154-172  pkg-config, then find_path/find_library;
#           a miss is an error (:168).
#   libjpeg libqpdf/CMakeLists.txt:174-214  likewise; a miss is an error (:210).
#   zopfli  :216-226  off by default; named off.
#   STATIC_JPEG, STATIC_OPENSSL (CMakeLists.txt:100-101) off; BUILD_STATIC_LIBS
#           (:76) off, only the shared library is installed.

summary = "qpdf: command-line tool and library for structural, content-preserving PDF transformation"

# NOTICE.md:3 "Licensed under the Apache License, Version 2.0"; :9 says versions
# before 7 were Artistic-2.0, which this version does not use. NOTICE.md:13-14 add
# a public-domain Rijndael and :17 sphlib's sha2 (MIT-style), both only in the
# native provider.
license = "Apache-2.0"

versions {
  github = "qpdf/qpdf"
  strip  = "/^v/"
}

dependencies = {
  "libjpeg-turbo.org" = "*"
  linux = {
    "gnu.org/gcc/libstdcxx" = "^14"
  }
  "openssl.org" = "^3"
  "zlib.net"    = "^1"
}

distributable {
  # 19724355 bytes: the release asset qpdf-12.4.2.tar.gz, not GitHub's archive of the
  # tag. NO SIGNATURE WAS VERIFIED: the release carries qpdf-12.4.2.tar.gz.asc and a
  # clear-signed qpdf-12.4.2.sha256, but the signing key was not fetched (it is not
  # obtainable without a keyserver and none is asked). Three agreeing witnesses of
  # the same digest instead: the project's own qpdf-12.4.2.sha256 asset, the
  # SHA-256 computed on a fetch from GitHub, and the SHA-256 computed on a fetch from
  # NetBSD's pkgsrc distfiles mirror
  # (ftp.netbsd.org/pub/pkgsrc/distfiles/qpdf-12.4.2.tar.gz, an independent host).
  url              = "https://github.com/qpdf/qpdf/releases/download/v{{version.raw}}/qpdf-{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "12.4.2" = "8a58af5b6141319287c1883bec8bd1bd545b7567b7fc5e6ce5d25a1c85f36397"
  }
}

build {
  dependencies = {
    "cmake.org"                  = "^3"
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # The library goes to {{prefix}}/lib on every platform (GNUInstallDirs would pick
      # lib64 on some), and the programs find it there: cmake strips the build rpath
      # on install, and without this `qpdf` failed with "no LC_RPATH's found".
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCMAKE_INSTALL_RPATH={{prefix}}/lib",
      "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON",

      # The three libraries by directory, behind the pkg-config path exported below.
      "-DCMAKE_PREFIX_PATH={{deps.openssl.org.prefix}};{{deps.libjpeg-turbo.org.prefix}};{{deps.zlib.net.prefix}}",

      # ⛔ CRYPTO (see the header): OpenSSL required and the default, native kept,
      # GnuTLS never probed.
      "-DUSE_IMPLICIT_CRYPTO=OFF",
      "-DREQUIRE_CRYPTO_OPENSSL=ON",
      "-DREQUIRE_CRYPTO_GNUTLS=OFF",
      "-DREQUIRE_CRYPTO_NATIVE=ON",
      "-DDEFAULT_CRYPTO=openssl",
      "-DSTATIC_OPENSSL=OFF",
      "-DSTATIC_JPEG=OFF",
      "-DZOPFLI=OFF",

      # Shared library only; no documentation (CMakeLists.txt:55-60 builds it only in
      # maintainer mode), no examples (:114).
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_STATIC_LIBS=OFF",
      "-DBUILD_DOC=OFF",
      "-DINSTALL_EXAMPLES=OFF",
    ]
  }

  script = [
    # libqpdf/CMakeLists.txt:155, :175, :247 ask pkg-config first; it only sees a
    # package whose directory is on this path.
    "export PKG_CONFIG_PATH=\"{{deps.openssl.org.prefix}}/lib/pkgconfig:{{deps.openssl.org.prefix}}/lib64/pkgconfig:{{deps.libjpeg-turbo.org.prefix}}/lib/pkgconfig:{{deps.libjpeg-turbo.org.prefix}}/lib64/pkgconfig:{{deps.zlib.net.prefix}}/lib/pkgconfig\" && cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# CMakeLists.txt:394 zlib-flate; qpdf/CMakeLists.txt installs qpdf and fix-qdf.
provides = [
  "bin/fix-qdf",
  "bin/qpdf",
  "bin/zlib-flate",
]

test {
  script = [
    {
      run = <<EOT
set -eu
"{{prefix}}/bin/qpdf" --version > version.txt 2>&1
grep -q 'qpdf version {{version.raw}}' version.txt
# --show-crypto lists the providers this build has; the first is the default
"{{prefix}}/bin/qpdf" --show-crypto > crypto.txt 2>&1
test "$(head -n 1 crypto.txt)" = "openssl"
grep -q '^native$' crypto.txt
if grep -q gnutls crypto.txt; then echo "gnutls provider present" >&2; exit 1; fi
# a real AES-256 round trip through the OpenSSL provider
printf 'u\n' > pf.txt
"{{prefix}}/bin/qpdf" --empty --encrypt u o 256 -- enc.pdf
"{{prefix}}/bin/qpdf" --show-encryption --password-file=pf.txt enc.pdf > enc.txt 2>&1
grep -q 'stream encryption method: AESv3' enc.txt
"{{prefix}}/bin/qpdf" --password-file=pf.txt --decrypt enc.pdf dec.pdf
"{{prefix}}/bin/qpdf" --show-encryption dec.pdf > dec.txt 2>&1
grep -q 'File is not encrypted' dec.txt
# zlib
printf 'hello hello hello\n' > in.txt
"{{prefix}}/bin/zlib-flate" -compress < in.txt > in.z
"{{prefix}}/bin/zlib-flate" -uncompress < in.z > out.txt
cmp in.txt out.txt
EOT
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",          # :33-60 the options, :74-117 BUILD_SHARED_LIBS, crypto and static options, :394 zlib-flate
    "libqpdf/CMakeLists.txt",  # :154-172 zlib, :174-214 libjpeg, :216-226 zopfli, :231-322 crypto selection, :329 default, :357-365 the providers' sources
    "libqpdf/QPDFCryptoProvider.cc",  # :58 QPDF_CRYPTO_PROVIDER
    "NOTICE.md",               # :3 Apache-2.0, :9 prior Artistic-2.0, :13-17 the bundled public-domain and sha2 code
    "job.yml",                 # :86 --show-crypto
  ]

  consulted = []

  note = <<EOT
NO SIGNATURE WAS VERIFIED: qpdf-12.4.2.tar.gz.asc and the clear-signed
qpdf-12.4.2.sha256 are published, but the signing key was not fetched (not
obtainable without a keyserver, and none is asked). The pin 8a58af5b... is the digest listed in the project's own
qpdf-12.4.2.sha256 asset, computed on a fetch from GitHub, and computed again on a
fetch from NetBSD's pkgsrc distfiles mirror: all three agree.

BUILT AND TESTED ON A MACHINE, NOT BY THE FACTORY: cmake configure, build and
install of this source, darwin/arm64, with Homebrew's openssl 3 and libjpeg-turbo by
directory (PKG_CONFIG_PATH and CMAKE_PREFIX_PATH) and the macOS SDK's zlib. The
configure summary read "GNU TLS crypto enabled: OFF, OpenSSL crypto enabled: ON,
Native crypto enabled: ON, Default crypto: openssl"; `qpdf --show-crypto` printed
"openssl" then "native"; libqpdf links libz, libjpeg, libssl and libcrypto (otool
-L); an AES-256 encrypt, show-encryption and decrypt round trip passed. The first
install failed to run (`qpdf` had no LC_RPATH): CMAKE_INSTALL_RPATH is the fix.

The fragment's dependency on libjpeg-turbo.org ^2 is widened to *: that recipe
carries 3.x only, and qpdf asks for the libjpeg API, which 3.x provides. The
fragment's gnutls.org dependency is dropped for the reason in the header.

⛔ NOT BUILT BY THE FACTORY, NOT BUILT ON LINUX (no rpath for libstdcxx, as in the
other recipes here that depend on it).
EOT
}
