# postgresql.org — the PostgreSQL server, its clients (psql, pg_dump, initdb,
# pg_ctl …) and contrib. A whole recipe (go-zpkg/packages#440 step 1): it was
# a fragment of seven dependencies.
#
# ⛔ WRITTEN FROM POSTGRESQL'S OWN FILES (go-zpkg/packages#431), at 18.7.
#
# WHAT IS INSTALLED: the programs, libraries, headers, share/ and contrib
# extensions, under the prefix. NO cluster, NO service registration: no
# systemd unit (--without-systemd below), no launchd plist, no initdb run, no
# user. A consumer runs `initdb` itself.
#
# ⭐⭐ WHAT WRITING IT FOUND: every optional library is named below, and one
# line of the old fragment was a latent failure, not a choice. It pinned
# libxml2 at ~2.13 and left libxslt to the pantry, and recipes#214 / pantry
# #15143 found why: libxslt 1.1.45 links libxml2.so.16 while the pin kept
# libxml2 at 2.13, so configure's link test could not load it. The cause was
# asking for libxslt at all. libxslt is used ONLY by contrib/xml2 (configure.ac:
# 1120 "use XSLT support when building contrib/xml2"); the server's own XML
# support is libxml2 alone. REFUSED here, so the libxml2 pin has nothing left
# to disagree with. (contrib/xml2 is still built, without its xslt_process().)

summary = "PostgreSQL: the object-relational database server, its clients and contrib"

# COPYRIGHT:1-23: "Portions Copyright (c) 1996-2026, PostgreSQL Global
# Development Group" and 1994 The Regents of the University of California,
# under the PostgreSQL licence. Code compiled into the server with its own
# notice, each read from its header:
#   BSD-3-Clause   src/common/md5.c, sha1.c (KAME), sha2.c (Gifford),
#                  src/port/getopt*.c, snprintf.c (the Regents)
#   Apache-2.0 OR BSL-1.0  Ulf Adams' Ryu: src/common/d2s.c:10-26 ("under the
#                  terms of the Boost license (not the Apache license)")
#   LicenseRef-Henry-Spencer-regex  src/backend/regex/regcomp.c:5-29,
#                  bespoke text, no SPDX identifier
#   LicenseRef-public-domain  src/timezone/localtime.c:4, zic.c:4 (tz
#                  database code), src/common/wchar.c:584 (Markus Kuhn)
# NOT added: src/backend/jit/llvm/SectionMemoryManager.* (LLVM licence) is
# compiled only with --with-llvm, refused below.
license = "PostgreSQL AND BSD-3-Clause AND (Apache-2.0 OR BSL-1.0) AND LicenseRef-Henry-Spencer-regex AND LicenseRef-public-domain"

versions {
  url   = "https://ftp.postgresql.org/pub/source/"
  match = "/v\\d+\\.\\d+\\//"
  strip = ["/^v/", "/\\/$/"]
}

dependencies = {
  # --with-libxml. The pin is kept as it was in the fragment.
  "gnome.org/libxml2" = "~2.13"
  # --with-gssapi, as libpq (postgresql.org/libpq) does.
  "kerberos.org" = "*"
  # --with-lz4: fatal when missing (configure.ac:1149-1150).
  "lz4.org" = "*"
  # --with-ssl=openssl.
  "openssl.org" = "^3"
  # --with-icu: ON by default, fatal when missing (configure.ac:831-837).
  "unicode.org" = "^73"
  # --with-zlib: ON by default, fatal when missing (:1136).
  "zlib.net" = "*"

  linux = {
    # --with-readline: ON by default (:958). On macOS the system's libedit
    # answers the same probe, so only Linux needs a recipe.
    "gnu.org/readline" = "*"
  }
}

distributable {
  url              = "https://ftp.postgresql.org/pub/source/v{{version.raw}}/postgresql-{{version.raw}}.tar.bz2"
  strip-components = 1

  # 23155657 bytes. ⚠ A SINGLE-HOST CHAIN, stated: the project does not sign
  # its tarballs (the .asc URL answers a 146-byte error page); it publishes
  # postgresql-18.7.tar.bz2.sha256 beside them, on the same host. That file
  # said 441dfae4… and so did two independent fetches of the tarball.
  sha256 = {
    "18.7" = "441dfae4280cae3e0425e5f876f80559fb0731c140f1aae22b3e5a54d0411bfd"
  }
}

build {
  dependencies = {
    "gnu.org/bison"              = "*"
    "gnu.org/make"               = "*"
    "github.com/westes/flex"     = "*"
    "freedesktop.org/pkg-config" = "*"
    "perl.org"                   = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ THE LIBRARIES, EACH NAMED. configure.ac defaults, read:
      #   ON by default and FATAL without: icu :831, readline :958, zlib :1136
      #   OFF by default: everything else below.
      "--with-ssl=openssl", # :1383, no default: without it, no TLS
      "--with-icu",
      "--with-readline",
      "--with-zlib",
      "--with-lz4",        # :1144
      "--with-libxml",     # :1082
      "--with-gssapi",     # :873

      # REFUSED, each at its default of "no" and named so a change of default
      # is visible here:
      "--without-zstd",     # :1169 backup compression with zstd; kept off, as the fragment had it
      "--without-libxslt",  # :1120 see the header
      "--without-pam",      # :901 no PAM recipe in this tree
      "--without-ldap",     # :921
      "--without-systemd",  # :950 and no unit file: no service registration
      "--without-selinux",  # :942
      "--without-bonjour",  # :932
      "--without-bsd-auth", # :911
      "--without-liburing", # :982
      "--without-libnuma",  # :1068
      "--without-libcurl",  # :1026 OAuth validators
      "--without-llvm",     # :397 JIT
      "--without-perl",     # :857 PL/Perl
      "--without-python",   # :865 PL/Python
      "--without-tcl",      # :844 PL/Tcl
      # :999 uuid has no default; unnamed, contrib/uuid-ossp is not built.
      # The server's own gen_random_uuid() needs none.

      # :1129 no system-tzdata: the server uses the tz database it ships
      # (src/timezone/data), so time zones do not depend on the builder's OS.
    ]
  }

  # world-bin: the server, clients and contrib, WITHOUT the documentation
  # (which needs docbook and xsltproc).
  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }} world-bin",
    "make install-world-bin",
  ]
}

provides = [
  "bin/initdb",
  "bin/pg_ctl",
  "bin/pg_config",
  "bin/pg_dump",
  "bin/pg_dumpall",
  "bin/pg_restore",
  "bin/postgres",
  "bin/psql",
]

test {
  script = [
    "postgres --version",
    # pg_config --configure prints the arguments configure ran with.
    "pg_config --configure > configure.args",
    "grep -q -- --with-ssl=openssl configure.args",
    "grep -q -- --with-icu configure.args",
    "grep -q -- --with-lz4 configure.args",
    "grep -q -- --with-libxml configure.args",
    "grep -q -- --with-gssapi configure.args",
    "grep -q -- --without-libxslt configure.args",
    "grep -q -- --without-systemd configure.args",
    # pg_config.h: what the compiler saw.
    "grep -q '^#define USE_OPENSSL 1' \"{{prefix}}/include/postgresql/server/pg_config.h\"",
    "grep -q '^#define USE_ICU 1' \"{{prefix}}/include/postgresql/server/pg_config.h\"",
    "grep -q '^#define USE_LZ4 1' \"{{prefix}}/include/postgresql/server/pg_config.h\"",
    "grep -q '^#define USE_LIBXML 1' \"{{prefix}}/include/postgresql/server/pg_config.h\"",
    "! grep -q '^#define USE_SYSTEMD 1' \"{{prefix}}/include/postgresql/server/pg_config.h\"",
    # Nothing was registered or started: no unit file in the prefix.
    "test -z \"$(find {{prefix}} -name '*.service' -o -name '*.plist')\"",
    # And the server really runs: a cluster in a scratch directory, on a unix
    # socket only, asked about each optional feature.
    {
      run = <<EOT
set -eu
D="$(mktemp -d)"
trap 'pg_ctl -D "$D/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$D"' EXIT
initdb -D "$D/data" --no-sync -E UTF8 --locale-provider=icu --icu-locale=en-US >/dev/null
pg_ctl -D "$D/data" -o "-c listen_addresses= -k $D -c fsync=off" -w start >/dev/null
q() { psql -h "$D" -d postgres -Atc "$1"; }
test "$(q "select xmlserialize(content xmlparse(content '<a/>') as text)")" = "<a/>"
test "$(q "select datlocprovider from pg_database where datname = 'postgres'")" = "i"
q "create table t (v text compression lz4); insert into t select repeat('x', 10000); select pg_column_compression(v) from t" | grep -q lz4
test "$(q "select 1")" = "1"
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                      # :831 icu, :844-865 the PLs, :873 gssapi, :901-950 pam/ldap/bonjour/selinux/systemd, :958 readline, :982 liburing, :1026 libcurl, :1068 libnuma, :1082 libxml, :1120 libxslt "contrib/xml2", :1129 system-tzdata, :1136 zlib, :1144 lz4, :1169 zstd, :1383 ssl
    "meson_options.txt",                 # :76-166 the same options, "auto" by default; autoconf is used because its defaults are explicit
    "COPYRIGHT",                         # :1-23 the licence
    "src/common/d2s.c",                  # :10-26 Ryu, Apache-2.0 or Boost
    "src/backend/regex/regcomp.c",       # :5-29 Henry Spencer's notice
    "src/timezone/localtime.c",          # :4 public domain
    "src/common/sha2.c",                 # BSD-3-Clause
    "src/common/md5.c",                  # BSD-3-Clause
    "src/port/snprintf.c",               # BSD-3-Clause
    "https://ftp.postgresql.org/pub/source/v18.7/postgresql-18.7.tar.bz2.sha256",
  ]

  consulted = [
    # Read for facts only. Nothing copied.
    "pkgxdev/pantry projects/postgresql.org/package.yml",
    "go-zpkg/recipes#214, pkgxdev/pantry#15143 (the libxslt / libxml2 mismatch)",
  ]

  note = <<EOT
⛔ libxslt is refused, and that CHANGES the artifact: contrib/xml2's
xslt_process() is gone. It is deprecated upstream and nothing else in
PostgreSQL uses libxslt; the alternative was keeping a pin that drifts.

⚠ zstd was off in the fragment and stays off; asking for it is a one-line
change plus a facebook.com/zstd dependency.

⚠ NO SIGNATURE: PostgreSQL publishes only a .sha256 beside each tarball.

⛔ NOT BUILT. No session here can run the factory; the test is read from the
sources and the options, not run.
EOT
}
