# mysql.com — the MySQL 8.4 LTS server, client programs and libmysqlclient.
#
# ⛔ WRITTEN FROM MYSQL'S OWN FILES (go-zpkg/packages#440 step 1), at 8.4.13.
#
# ⭐⭐ BOOST IS NOT A DEPENDENCY OF THIS RECIPE, AND CANNOT BE. MySQL 8.4 ships
# boost 1.84.0 inside its own tarball (extra/boost/boost_1_84_0) and refuses any
# other: cmake/boost.cmake:24 names the package, :26-27 reads "Always use the
# bundled version", and :33-41 puts mysql's OWN patched headers
# (include/boost_1_84_0/patches) BEFORE boost's. There is no WITH_BOOST and no
# DOWNLOAD_BOOST option to point it elsewhere (CMakeLists.txt:1575 includes
# boost.cmake unconditionally). A separate boost recipe would never be read by
# this build, and one without those patches would be wrong. So boost 1.84.0 with
# mysql's patches is VENDORED, arrives inside the pinned archive, and is not a
# build-time fetch.
#
# ⭐ WHAT ELSE WRITING IT FOUND: every third-party library defaults to BUNDLED
# (CMakeLists.txt:1777 WITH_SYSTEM_LIBS_DEFAULT OFF; cmake/zlib.cmake:116-118,
# zstd.cmake:89-91, lz4.cmake:78-80, icu.cmake:169-171, protobuf.cmake:116-118,
# readline.cmake:212-213). A builder that names nothing silently gets copies
# inside the tree, whatever dependencies are declared. Every one is named below.

summary = "MySQL Community Server 8.4 LTS: mysqld, mysql, mysqldump, mysqladmin and libmysqlclient"

# GPL-2.0 with additional permission to link separately licensed software such
# as OpenSSL (the header of cmake/boost.cmake:3-13, repeated in every source
# file; the Community edition of LICENSE).
license = "GPL-2.0-only"

# The 8.4 series only: anything else (9.x innovation releases, 8.0, 5.x, and
# the -rc / -dmr tags) is dropped. There is no 8.4.12 tag.
versions {
  github = "mysql/mysql-server"
  strip  = "/^mysql-/"
  ignore = ["/^(?!8\\.4\\.\\d+$)/"]
}

dependencies = {
  # WITH_SSL=<prefix> (cmake/ssl.cmake:30, :539-544): the OS library is not used.
  "openssl.org" = "^3"
  # cmake/zlib.cmake:33 MIN_ZLIB_VERSION_REQUIRED 1.2.13.
  "zlib.net" = ">=1.2.13"
  # cmake/zstd.cmake:29 minimum 1.2.0; the bundled copy is 1.5.7 (:74).
  "facebook.com/zstd" = "^1"
  # cmake/lz4.cmake; the bundled copy is 1.10.0 (:64).
  "lz4.org" = "^1"
  # cmake/icu.cmake:47 minimum 55; the bundled copy is 77.1 (:124).
  "unicode.org" = "^71"
  # cmake/protobuf.cmake:36 minimum 3.5.0, bundled 3.19.4 (:33). The old fragment
  # asked for ^21 (3.21): kept.
  "protobuf.dev" = "^21"
  # cmake/readline.cmake:24: the client's line editor. It needs curses (:83).
  "thrysoee.dk/editline"         = "^3"
  "invisible-island.net/ncurses" = "*"
  linux = {
    "gnu.org/gcc/libstdcxx" = "^14"
  }
}

# cdn.mysql.com serves ONLY the current releases and REMOVES old ones: this URL
# for an older 8.4.x answers 404 some time after it was superseded, so the pin
# below is good for the newest release only, and each new 8.4.x needs its digest
# added (the recipe is fail-closed, a version without an entry is refused).
#
# 479316148 bytes. The source tarball already contains boost 1.84.0
# (extra/boost/boost_1_84_0, 9303 entries); the separate mysql-boost tarball of
# the 5.7/8.0 era is NOT published for 8.4 (mysql-boost-8.4.13.tar.gz is 404).
#
# SIGNED, and the signature verified when the digest was recorded:
#   signature   https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.13.tar.gz.asc
#   key         MySQL Release Engineering <mysql-build@oss.oracle.com>
#   fingerprint BCA4 3417 C3B4 85DD 128E C6D4 B7B3 B788 A8D3 785C
#   key source  the key block and fingerprint printed on MySQL's own documentation
#               page https://dev.mysql.com/doc/refman/8.4/en/checking-gpg-signature.html
#               (the page also names the keyserver; none was asked)
#   signed at   2026-10-01T10:43:51Z
# (`zpkb sourcepin --sig auto --key mysql_pubkey.asc --fingerprint ...`).
distributable {
  url              = "https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "8.4.13" = "f6ddc7f7fb6462bab8b533b13c06af3fff57fa9ca12259b81ab13cd9930b9d58"
  }
}

build {
  dependencies = {
    "cmake.org"                  = "^3"
    "gnu.org/bison"              = ">=3.0.4"
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/make"               = "*"
    "gnu.org/gcc"                = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # THIRD-PARTY LIBRARIES, every one named. The six that have a recipe are
      # taken from their declared prefixes (CMAKE_PREFIX_PATH, given in the script).
      #
      # SSL: a prefix, so the OS openssl is not used (cmake/ssl.cmake:30, :539-544).
      "-DWITH_SSL={{deps.openssl.org.prefix}}",
      # ZLIB, ZSTD, LZ4, ICU, PROTOBUF, EDITLINE: system = the declared copy
      # (zlib.cmake:116-124, zstd.cmake:89-95, lz4.cmake:78-84, icu.cmake:169-178,
      # protobuf.cmake:116-131, readline.cmake:212-222). The default is bundled.
      "-DWITH_ZLIB=system",
      "-DWITH_ZSTD=system",
      "-DWITH_LZ4=system",
      "-DWITH_ICU=system",
      "-DWITH_PROTOBUF=system",
      "-DWITH_EDITLINE=system",
      # RAPIDJSON: header-only, no recipe: the bundled copy (rapidjson.cmake:25,
      # :82-88).
      "-DWITH_RAPIDJSON=bundled",

      # OFF: curl is used by the Enterprise-only components (CMakeLists.txt:955-962,
      # WITH_CURL defaults to none unless WITH_INTERNAL, cmake/curl.cmake:218-230);
      # libfido2 only by the WebAuthn plugins (CMakeLists.txt:949-953 forces none
      # without them, cmake/fido2.cmake:177-187); kerberos, ldap and sasl only by
      # the LDAP and Kerberos authentication plugins (kerberos.cmake:372-376,
      # ldap.cmake:129-130, sasl.cmake:250-251), themselves Enterprise-only.
      "-DWITH_CURL=none",
      "-DWITH_FIDO=none",
      "-DWITH_AUTHENTICATION_WEBAUTHN=OFF",
      "-DWITH_AUTHENTICATION_CLIENT_PLUGINS=OFF",
      "-DWITH_AUTHENTICATION_LDAP=OFF",
      "-DWITH_AUTHENTICATION_KERBEROS=OFF",
      "-DWITH_KERBEROS=none",

      # FEATURES AND PRODUCTS, named so a changed default shows here.
      # NDB cluster (CMakeLists.txt:507): not built. The router (:859, default
      # ON) is not built either: it is a separate daemon with its own libraries,
      # and this recipe is the server and clients.
      "-DWITH_NDB=OFF",
      "-DWITH_ROUTER=OFF",
      # :855-857 the unit tests, :123 the debug build, :981 link-time optimisation
      # (slow, and an extra toolchain requirement), :1578 systemd units,
      # :824 tcmalloc, :837 jemalloc, cmake/libbacktrace.cmake:44 libbacktrace.
      "-DWITH_UNIT_TESTS=OFF",
      "-DWITH_DEBUG=OFF",
      "-DWITH_LTO=OFF",
      "-DWITH_SYSTEMD=OFF",
      "-DWITH_TCMALLOC=OFF",
      "-DWITH_JEMALLOC=OFF",
      "-DWITH_EXT_BACKTRACE=OFF",
      # :757-766 would FAIL without elfutils; a build id is not needed.
      "-DWITH_BUILD_ID=OFF",
    ]
  }

  script = [
    # The quoted argument cannot go through $ARGS: the semicolons separate the
    # prefixes (CMAKE_PREFIX_PATH is a cmake list).
    "cmake -S . -B build $ARGS \"-DCMAKE_PREFIX_PATH={{deps.openssl.org.prefix}};{{deps.zlib.net.prefix}};{{deps.facebook.com/zstd.prefix}};{{deps.lz4.org.prefix}};{{deps.unicode.org.prefix}};{{deps.protobuf.dev.prefix}};{{deps.thrysoee.dk/editline.prefix}};{{deps.invisible-island.net/ncurses.prefix}}\"",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# INSTALL_LAYOUT defaults to STANDALONE, which installs the server and the
# clients under bin (cmake/install_layout.cmake).
provides = [
  "bin/mysql",
  "bin/mysqladmin",
  "bin/mysqld",
  "bin/mysqldump",
]

test {
  script = [
    # A system mysql found first on PATH would answer for the build: the version
    # is asked of the installed binaries by path and compared with the recipe's.
    "{{prefix}}/bin/mysqld --version | grep -F '{{version.raw}}'",
    "{{prefix}}/bin/mysql --version | grep -F '{{version.raw}}'",
    "{{prefix}}/bin/mysqladmin --version | grep -F '{{version.raw}}'",
    "{{prefix}}/bin/mysqldump --version | grep -F '{{version.raw}}'",
  ]
}

provenance {
  read = [
    "cmake/boost.cmake",       # :24 boost_1_84_0; :26-27 always the bundled copy; :33-41 mysql's patches before boost's; :1575 of CMakeLists.txt includes it unconditionally
    "CMakeLists.txt",          # :123 WITH_DEBUG; :507 NDB; :755-766 build id; :824,:837 tcmalloc/jemalloc; :855-859 unit tests and router; :868-965 WITH_INTERNAL and the authentication options; :981 LTO; :1578 systemd; :1735-1745 SYSTEM_LIBRARIES; :1777-1825 WITH_SYSTEM_LIBS
    "cmake/ssl.cmake",         # :28-61 WITH_SSL forms; :535-577 prefix handling
    "cmake/zlib.cmake",        # :25, :33 minimum 1.2.13, :116-139
    "cmake/zstd.cmake",        # :24, :29 minimum 1.2.0, :89-109
    "cmake/lz4.cmake",         # :24, :78-90
    "cmake/icu.cmake",         # :32 default bundled, :47 minimum 55, :169-189
    "cmake/protobuf.cmake",    # :27, :33-36 minimum 3.5.0, :116-131
    "cmake/readline.cmake",    # :24, :83 curses, :212-228
    "cmake/rapidjson.cmake",   # :25, :82-103
    "cmake/curl.cmake",        # :24, :218-230
    "cmake/fido2.cmake",       # :24, :177-187
    "cmake/kerberos.cmake",    # :24, :372-376
    "cmake/ldap.cmake",        # :24, :129-130
    "cmake/sasl.cmake",        # :24, :250-251
    "cmake/bison.cmake",       # :27 minimum bison 3.0.4
    "cmake/libbacktrace.cmake", # :44 WITH_EXT_BACKTRACE
    "cmake/os/Linux.cmake",    # :78-83 compiler version checks
    "LICENSE",                 # 8.4.13 Community licensing manual
    "README",
  ]

  consulted = [
    "dev.mysql.com/doc/refman/8.4/en/checking-gpg-signature.html (the release key and its fingerprint)",
  ]

  note = <<EOT
⭐ VENDORED BOOST. boost 1.84.0 with mysql's own patches comes inside the
source archive and is the only boost this build accepts (cmake/boost.cmake:24-41;
no WITH_BOOST, no DOWNLOAD_BOOST). It is pinned by the archive's digest, not
fetched. No boost recipe applies.

⚠ cdn.mysql.com REMOVES OLD RELEASES. The recipe resolves every 8.4.x tag but
only pins 8.4.13; an older tag would 404 anyway, and a newer one is refused
until its digest is recorded.

The signature was checked when the digest was recorded (zpkb sourcepin), against
the key printed on MySQL's documentation page; no keyserver was consulted.

Dropped from the prior fragment: libevent.org (no CMake file of 8.4.13 refers to
it: only the licensing manual names it as bundled third-party code), curl.se and
developers.yubico.com/libfido2 (both switched off above, with the options that
would need them).

⛔ NOT BUILT. No session here can run the factory: the option names are read from
the CMake files, the build has not been run, and the test is unexercised.
EOT
}
