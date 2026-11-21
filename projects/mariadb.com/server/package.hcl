# mariadb.com/server — the MariaDB database server, its client tools and
# libmariadb. One of the fragments of go-zpkg/packages#440: it declared
# dependencies and a build that ran `git submodule update` (a network fetch),
# `sed -i` patches and one `-DPLUGIN_ROCKSDB=NO`.
#
# ⛔ WRITTEN FROM MARIADB'S OWN FILES, at 12.3.4 (LTS).
#
# ⭐⭐ THE FINDING: this CMake build DOWNLOADS THINGS WHEN A SYSTEM LIBRARY IS
# NOT FOUND, AND SAYS LITTLE. cmake/libfmt.cmake:19 fetches fmt 12.2.0 by
# ExternalProject, cmake/pcre.cmake:68 fetches pcre2-10.49, cmake/zlib.cmake:68-69
# falls back to the bundled zlib, and a bare path as WITH_SSL falls back to
# wolfssl. The `auto` defaults make a missing dependency into a different build.
# Every one is therefore set to `system` below (which is FATAL when missing),
# and the plugins whose libraries have no recipe are turned OFF by name.

summary = "MariaDB: the community-developed fork of MySQL, a relational database server"

# COPYING:1-3 is the GPL-2.0 text ("GNU GENERAL PUBLIC LICENSE Version 2,
# June 1991"). The client library libmariadb is LGPL-2.1, but the recipe states
# the licence of the project itself.
license = "GPL-2.0-only"

versions {
  # ⚠ ONLY THE LONG-TERM-SUPPORT SERIES. archive.mariadb.org lists every
  # directory, previews and release candidates included (13.2 is a Preview, 13.1
  # an RC, 13.0 a rolling Stable per https://downloads.mariadb.org/rest-api/
  # mariadb/), and a preview must never be what `latest` installs. The series
  # below are the ones that REST API marks LTS: 12.3, 11.8, 11.4, 10.11. When a
  # new LTS is announced it is ADDED to this pattern by hand.
  url   = "https://archive.mariadb.org/"
  match = "/mariadb-(?:12\\.3|11\\.8|11\\.4|10\\.11)\\.\\d+\\//"
  strip = [
    "/^.*mariadb-/",
    "/\\/$/",
  ]
}

dependencies = {
  "facebook.com/zstd"             = "^1"
  "github.com/besser82/libxcrypt" = "^4"
  "invisible-island.net/ncurses"  = "^6"
  "lz4.org"                       = "^1"
  "openssl.org"                   = "^3"
  "pcre.org/v2"                   = "^10"
  "sourceware.org/bzip2"          = "^1"
  "tukaani.org/xz"                = "^5"
  "zlib.net"                      = "^1"
}

distributable {
  # THE PROJECT'S OWN ARCHIVE HOST, not the GitHub tag archive: the tarball
  # carries the submodule contents (libmariadb, wsrep-lib, storage/*) and no
  # .git, so nothing has to be fetched at build time. 231906229 bytes.
  url              = "https://archive.mariadb.org/mariadb-{{version}}/source/mariadb-{{version}}.tar.gz"
  strip-components = 1

  # The second witness is the project's PUBLISHED CHECKSUM FILE,
  # https://archive.mariadb.org/mariadb-12.3.4/source/sha256sums.txt, whose line
  # for this tarball is the same digest, and so is the `sha256sum` field of the
  # REST API. An .asc exists beside the tarball but no key was obtainable
  # without a keyserver, so the signature was NOT verified.
  sha256 = {
    "12.3.4" = "75aae4d48df905734e24a85b955bbcdc43f4b122b450bc4ad2bc92f5d1ac578d"
  }
}

build {
  dependencies = {
    "cmake.org"                  = "^3"
    "freedesktop.org/pkg-config" = "*"
    "fmt.dev"                    = "*"
    "gnu.org/bison"              = "*"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
      "-DMYSQL_DATADIR={{prefix}}/var/mysql",
      "-DINSTALL_SYSCONFDIR=etc",
      "-DINSTALL_MYSQLSHAREDIR=share/mysql",
      "-DDEFAULT_CHARSET=utf8mb4",
      "-DDEFAULT_COLLATION=utf8mb4_general_ci",

      # cmake/submodules.cmake:1-20: UPDATE_SUBMODULES is ON by default and
      # would run `git submodule update`; with no .git it already cannot, but
      # it is named so that a tarball WITH a .git cannot start fetching.
      "-DUPDATE_SUBMODULES=OFF",

      # ⛔ EVERY `auto` THAT DOWNLOADS, SET TO `system` (fatal when absent).
      # cmake/libfmt.cmake:35-52 (header-only check, FMT_HEADER_ONLY), the
      # include directory is given in the script. cmake/pcre.cmake:3-8,65-69.
      # cmake/zlib.cmake:16-73. cmake/ssl.cmake:38,76-157: `system` is
      # fail-closed, a bare path is not.
      "-DWITH_LIBFMT=system",
      "-DWITH_PCRE=system",
      "-DWITH_ZLIB=system",
      "-DWITH_SSL=system",

      # Optional libraries NOT wired, switched off so a host copy cannot be
      # picked up. cmake/jemalloc.cmake:3 and cmake/systemd.cmake:20 are `auto`
      # (systemd.io exists but is not wired here); CMakeLists.txt:133 NUMA is
      # AUTO; tpool/CMakeLists.txt:26-58 auto-detects liburing and libaio
      # (FIND_PACKAGE QUIET) and no recipe provides either.
      "-DWITH_JEMALLOC=no",
      "-DWITH_SYSTEMD=no",
      "-DWITH_NUMA=OFF",
      "-DCMAKE_DISABLE_FIND_PACKAGE_URING=ON",
      "-DCMAKE_DISABLE_FIND_PACKAGE_LIBAIO=ON",
      # FIND_PACKAGE(CURL|GSSAPI|LZO|Snappy|Judy|Java|JNI): plugin/hashicorp_key_management:1,
      # libmariadb/CMakeLists.txt:92, storage/videx:24, storage/maria:121,
      # plugin/auth_gssapi:19, plugin/provider_lzo:1, plugin/provider_snappy:1,
      # storage/oqgraph:24, storage/connect:274-277. None is a dependency.
      "-DCMAKE_DISABLE_FIND_PACKAGE_CURL=ON",
      "-DCMAKE_DISABLE_FIND_PACKAGE_GSSAPI=ON",
      "-DCMAKE_DISABLE_FIND_PACKAGE_LZO=ON",
      "-DCMAKE_DISABLE_FIND_PACKAGE_Snappy=ON",
      "-DCMAKE_DISABLE_FIND_PACKAGE_Judy=ON",
      "-DCMAKE_DISABLE_FIND_PACKAGE_Java=ON",
      "-DCMAKE_DISABLE_FIND_PACKAGE_JNI=ON",

      # Not built: CMakeLists.txt:186 unit tests; :529 embedded server;
      # cmake/wsrep.cmake:21-30 Galera replication (no Galera library recipe).
      "-DWITH_UNIT_TESTS=OFF",
      "-DWITH_EMBEDDED_SERVER=OFF",
      "-DWITH_WSREP=OFF",

      # ⛔ PLUGINS THAT CANNOT BE WIRED TO AN EXISTING RECIPE, OFF BY NAME
      # (cmake/plugin.cmake:94-145 accepts NO). Each is a MYSQL_ADD_PLUGIN
      # target whose upper-cased name is the switch.
      #   ROCKSDB, COLUMNSTORE, DUCKDB, SPHINX  large bundled engines that need
      #       libraries or toolchains with no recipe (storage/rocksdb is the
      #       one the fragment already disabled);
      #   MROONGA, SPIDER, CONNECT, OQGRAPH  need groonga, ODBC/MySQL client
      #       libraries, libxml2/Java, Boost+Judy respectively;
      #   S3, AWS_KEY_MANAGEMENT  the AWS SDK (cmake/aws_sdk.cmake:1);
      #   AUTH_PAM, AUTH_PAM_V1, CRACKLIB_PASSWORD_CHECK, AUTH_GSSAPI,
      #   AUTH_GSSAPI_CLIENT, HASHICORP_KEY_MANAGEMENT, VIDEX
      #       link PAM, cracklib, Kerberos or libcurl, none of which has a recipe;
      #   PROVIDER_LZO, PROVIDER_SNAPPY  no LZO or Snappy recipe.
      # Kept: InnoDB, Aria, MyISAM, MERGE, HEAP, CSV, PERFSCHEMA, SEQUENCE and
      # the providers for bzip2, lz4 and lzma, which ARE wired (below).
      "-DPLUGIN_ROCKSDB=NO",
      "-DPLUGIN_COLUMNSTORE=NO",
      "-DPLUGIN_DUCKDB=NO",
      "-DPLUGIN_SPHINX=NO",
      "-DPLUGIN_MROONGA=NO",
      "-DPLUGIN_SPIDER=NO",
      "-DPLUGIN_CONNECT=NO",
      "-DPLUGIN_OQGRAPH=NO",
      "-DPLUGIN_S3=NO",
      "-DPLUGIN_AWS_KEY_MANAGEMENT=NO",
      "-DPLUGIN_AUTH_PAM=NO",
      "-DPLUGIN_AUTH_PAM_V1=NO",
      "-DPLUGIN_CRACKLIB_PASSWORD_CHECK=NO",
      "-DPLUGIN_AUTH_GSSAPI=NO",
      "-DPLUGIN_AUTH_GSSAPI_CLIENT=NO",
      "-DPLUGIN_HASHICORP_KEY_MANAGEMENT=NO",
      "-DPLUGIN_VIDEX=NO",
      "-DPLUGIN_PROVIDER_LZO=NO",
      "-DPLUGIN_PROVIDER_SNAPPY=NO",
    ]
  }

  script = [
    # The dependencies are found through CMAKE_PREFIX_PATH (FIND_PACKAGE for
    # BZip2, LZ4, LibLZMA, Curses, ZLIB) and the cmake/pcre.cmake pkg-config
    # probe; libmariadb's FindZStd.cmake:8-14 uses ZSTD_ROOT_DIR.
    {
      run = <<EOT
set -eu
export PKG_CONFIG_PATH="{{deps.pcre.org/v2.prefix}}/lib/pkgconfig"
cmake -S . -B build $ARGS \
  "-DCMAKE_PREFIX_PATH={{deps.pcre.org/v2.prefix}};{{deps.zlib.net.prefix}};{{deps.openssl.org.prefix}};{{deps.facebook.com/zstd.prefix}};{{deps.lz4.org.prefix}};{{deps.sourceware.org/bzip2.prefix}};{{deps.tukaani.org/xz.prefix}};{{deps.invisible-island.net/ncurses.prefix}};{{deps.github.com/besser82/libxcrypt.prefix}}" \
  "-DLIBFMT_INCLUDE_DIR={{deps.fmt.dev.prefix}}/include" \
  "-DOPENSSL_ROOT_DIR={{deps.openssl.org.prefix}}" \
  "-DZSTD_ROOT_DIR={{deps.facebook.com/zstd.prefix}}"
EOT
    },
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

provides = [
  "bin/mariadbd",
  "bin/mariadb",
  "bin/mariadb-admin",
  "bin/mariadb-dump",
  "bin/mariadb-install-db",
  "bin/mariadb_config",
]

test {
  script = [
    "test -x \"{{prefix}}/bin/mariadbd\"",
    "test -x \"{{prefix}}/bin/mariadb\"",
    {
      run = <<EOT
set -eu
out=$("{{prefix}}/bin/mariadbd" --version 2>&1)
case "$out" in
  *"{{version}}"*) ;;
  *) echo "mariadbd --version does not name {{version}}: $out" >&2; exit 1 ;;
esac
out=$("{{prefix}}/bin/mariadb" --version 2>&1)
case "$out" in
  *"{{version}}"*) ;;
  *) echo "mariadb --version does not name {{version}}: $out" >&2; exit 1 ;;
esac
EOT
    },
    "test -f \"{{prefix}}/include/mysql/mysql.h\"",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                              # :133 WITH_NUMA AUTO; :182 WITHOUT_SERVER; :186 WITH_UNIT_TESTS; :529 WITH_EMBEDDED_SERVER
    "COPYING",                                     # :1-3 GPL v2
    "cmake/submodules.cmake",                      # :1-20 UPDATE_SUBMODULES; :22-48 ADD_SUBMODULE fails without a .git
    "cmake/libfmt.cmake",                          # :4-57 auto/bundled/system; :19 the download; :36-46 the header-only check
    "cmake/pcre.cmake",                            # :3-8, 65-69, 90-113 auto, the pcre2-10.49 download, the pkg-config probe
    "cmake/zlib.cmake",                            # :16-73 bundled or system; :68-69 silent fallback
    "cmake/ssl.cmake",                             # :38, 76-157 WITH_SSL system vs path
    "cmake/jemalloc.cmake",                        # :3 auto
    "cmake/systemd.cmake",                         # :20-80 yes/no/auto
    "cmake/plugin.cmake",                          # :94-145 PLUGIN_x NO|YES|AUTO|STATIC|DYNAMIC
    "cmake/aws_sdk.cmake",                         # :49-53 FOREACH(pkg CURL ZLIB OpenSSL)
    "tpool/CMakeLists.txt",                        # :26-58 URING and LIBAIO auto-detected QUIET
    "cmake/FindURING.cmake",                       # :1-7 find_path/find_library
    "libmariadb/cmake/FindZStd.cmake",             # :8-17 ZSTD_ROOT_DIR
    "libmariadb/plugins/compress/CMakeLists.txt",  # :14-23 the zstd plugin is built only when found
    "libmariadb/CMakeLists.txt",                   # :298-320 compression plugins and zlib
    "plugin/provider_lz4/CMakeLists.txt",          # :1 FIND_PACKAGE(LZ4 1.6)
    "plugin/provider_bzip2/CMakeLists.txt",        # :1 FIND_PACKAGE(BZip2)
    "plugin/provider_lzma/CMakeLists.txt",         # :1 FIND_PACKAGE(LibLZMA)
    "configure.cmake",                             # :123 MY_SEARCH_LIBS(crypt) is how libcrypt is found
    "https://archive.mariadb.org/mariadb-12.3.4/source/sha256sums.txt",
    "https://downloads.mariadb.org/rest-api/mariadb/",  # series statuses and the sha256sum field
  ]

  consulted = [
    "the previous fragment of this recipe (dependencies and build)",
  ]

  note = <<EOT
NOT BUILT. This recipe was written from the project's own files and its test
block has not been run on either platform. NOT RUN: the CMake configure.

Open points, stated rather than hidden:
  - libxcrypt is kept as a dependency because configure.cmake:123 searches for
    -lcrypt; whether the libcrypt it finds is the declared one is unverified.
  - The fragment's libxml2 and groonga dependencies are dropped: libxml2 was
    used only by CONNECT (storage/connect:143) and groonga only by MROONGA,
    both turned off.
  - The fragment's darwin sed of OS_DATA_FILE_NO_O_DIRECT is NOT carried:
    unverified at 12.3.4 and a source patch the recipe does not need on linux.
  - The tarball signature (.asc beside it) was not verified (no key without a
    keyserver); the published sha256sums.txt is the second witness.
  - The header path in the test (include/mysql) is the STANDALONE layout,
    cmake/install_layout.cmake:116; the layout was not pinned and the default
    was not read, so a different default would fail that line.
EOT
}
