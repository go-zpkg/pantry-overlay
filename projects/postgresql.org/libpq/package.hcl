# postgresql.org/libpq — the PostgreSQL client library, its headers and
# `pg_config`, and nothing of the server. A whole recipe (go-zpkg/packages#440
# step 1): it was a fragment of five dependencies.
#
# ⛔ WRITTEN FROM POSTGRESQL'S OWN FILES (go-zpkg/packages#431), at 18.7.
#
# ⭐⭐ WHAT WRITING IT FOUND: the fragment declared readline and ICU, which
# libpq does not link. They were there because PostgreSQL's configure turns
# BOTH ON by default and stops without them, so a libpq-only build had to
# either carry them or refuse them. Refused below, so the closure of every
# consumer of libpq gets smaller. And the fragment said nothing about GSSAPI
# (kerberos.org was declared, nothing turned it on), so whether libpq spoke
# GSSAPI depended on nothing the recipe controlled.

summary = "PostgreSQL's client library (libpq), its headers and pg_config"

# COPYRIGHT:1-23: "Portions Copyright (c) 1996-2026, PostgreSQL Global
# Development Group" and 1994 The Regents of the University of California,
# under the PostgreSQL licence. Files compiled into libpq carry their own
# BSD-3-Clause notices, each read from its header:
#   src/common/md5.c, sha1.c (KAME / WIDE Project), src/common/sha2.c
#   (Aaron D. Gifford), src/port/getopt.c, getopt_long.c, snprintf.c (the
#   Regents of the University of California; snprintf.c also Eric P. Allman).
# NOT added: src/backend/regex/* (Henry Spencer's licence) is server-only code
# and libpq does not compile it.
license = "PostgreSQL AND BSD-3-Clause"

versions {
  url   = "https://ftp.postgresql.org/pub/source/"
  match = "/v\\d+\\.\\d+\\//"
  strip = ["/^v/", "/\\/$/"]
}

dependencies = {
  # --with-gssapi, below: fatal when the library is missing.
  "kerberos.org" = "*"
  # --with-ssl=openssl: fatal when missing.
  "openssl.org" = "^3"
  # --with-zlib is ON by default and stops without it (configure.ac:1136).
  "zlib.net" = "*"
}

distributable {
  url              = "https://ftp.postgresql.org/pub/source/v{{version.raw}}/postgresql-{{version.raw}}.tar.bz2"
  strip-components = 1

  # 23155657 bytes. ⚠ A SINGLE-HOST CHAIN, stated: the project does not sign
  # its tarballs (the .asc URL answers a 146-byte error page); it publishes
  # postgresql-18.7.tar.bz2.sha256 beside them, on the same host. That file
  # said 441dfae4… and so did two independent fetches of the tarball.
  #
  # ⚠ 19.0 ADDED 2026-11-20 (go-zpkg/recipes#208), a major release, pinned
  # after checking the build still applies: 23982241 bytes, digest equal to
  # postgresql-19.0.tar.bz2.sha256. In 19.0's tarball ./configure is still
  # shipped, every --with/--without in ARGS exists with the same default, and
  # the four directories the script makes (src/include, src/common,
  # src/interfaces/libpq, src/bin/pg_config) are all present. The configure.ac
  # line numbers cited below are 18.7's (~+40 in 19.0). Not built.
  sha256 = {
    "18.7" = "441dfae4280cae3e0425e5f876f80559fb0731c140f1aae22b3e5a54d0411bfd"
    "19.0" = "a89fd70efbad6a08c7dbed8d4872e3af30170d9e5ca9dc7906523be95b4e692d"
  }
}

build {
  dependencies = {
    "gnu.org/bison"            = "*"
    "gnu.org/make"             = "*"
    "github.com/westes/flex"   = "*"
    "freedesktop.org/pkg-config" = "*"
    "perl.org"                 = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # configure.ac:1383-1387: no default, so without it there is no TLS.
      "--with-ssl=openssl",
      # :873 default no. libpq's Makefile compiles fe-gssapi-common.o and
      # fe-secure-gssapi.o only when it is yes (src/interfaces/libpq/Makefile:60-63).
      "--with-gssapi",

      # ⛔ Defaults that would stop or silently change the build:
      # :958 readline defaults to yes and the build stops without it; libpq has
      # no use for it (psql is not built).
      "--without-readline",
      # :831 ICU defaults to yes (PKG_CHECK_MODULES, fatal); only the server uses it.
      "--without-icu",

      # Defaults of "no", named so a future change of default is visible.
      "--without-ldap",     # :921
      "--without-pam",      # :901
      "--without-libcurl",  # :1026, the OAuth flow (libpq-oauth)
      "--without-libxml",   # :1082
      "--without-libxslt",  # :1120
      "--without-lz4",      # :1144
      "--without-zstd",     # :1169
      "--without-systemd",  # :950
      "--without-selinux",  # :942
      "--without-bonjour",  # :932
      "--without-liburing", # :982
      "--without-libnuma",  # :1068
      "--without-llvm",     # :397
    ]
  }

  # Only what libpq needs: the headers (src/include), the library with its
  # pkg-config file (src/interfaces/libpq) and pg_config. No server, no psql.
  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }} -C src/include",
    "make --jobs {{ hw.concurrency }} -C src/common",
    "make --jobs {{ hw.concurrency }} -C src/interfaces/libpq",
    "make --jobs {{ hw.concurrency }} -C src/bin/pg_config",
    "make -C src/include install",
    "make -C src/interfaces/libpq install",
    "make -C src/bin/pg_config install",
  ]
}

provides = [
  "bin/pg_config",
]

test {
  fixture = <<EOT
#include <libpq-fe.h>
#include <stdio.h>

int main(void)
{
	/* 18.7 is 180007 (PQlibVersion, the library the program is linked to). */
	if (PQlibVersion() < 180000) {
		fprintf(stderr, "PQlibVersion %d\n", PQlibVersion());
		return 1;
	}
	/* A connection to nowhere fails cleanly and gives an error message. */
	PGconn *c = PQconnectdb("host=/nonexistent dbname=x connect_timeout=1");
	int bad = PQstatus(c) != CONNECTION_BAD;
	PQfinish(c);
	return bad;
}
EOT

  script = [
    "test -f \"{{prefix}}/include/libpq-fe.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/libpq.pc\"",
    # pg_config --configure prints the arguments configure ran with, so every
    # pin above is read off the installed tool, not inferred.
    "pg_config --configure > configure.args",
    "grep -q -- --with-ssl=openssl configure.args",
    "grep -q -- --with-gssapi configure.args",
    "grep -q -- --without-readline configure.args",
    # pg_config.h: the compile-time outcomes.
    "grep -q '^#define USE_OPENSSL 1' \"{{prefix}}/include/pg_config.h\"",
    "grep -q '^#define ENABLE_GSS 1' \"{{prefix}}/include/pg_config.h\"",
    "! grep -q '^#define USE_ICU 1' \"{{prefix}}/include/pg_config.h\"",
    "cc -x c $FIXTURE -x none -o t -I{{prefix}}/include -L{{prefix}}/lib -lpq",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./t
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                         # :831 icu, :873 gssapi, :958 readline, :1136 zlib, :1383 ssl; every other with_* default
    "meson_options.txt",                    # the same options for meson, defaults all "auto"; the autoconf build is used because its defaults are explicit
    "COPYRIGHT",                            # :1-23 the licence
    "src/interfaces/libpq/Makefile",        # :18 exports, :60-63 gssapi objects, :88-92 the libraries it links, :116 libpq-oauth
    "src/common/sha2.c",                    # BSD-3-Clause, Gifford
    "src/common/md5.c",                     # BSD-3-Clause, KAME
    "src/port/snprintf.c",                  # BSD-3-Clause
    "https://ftp.postgresql.org/pub/source/v18.7/postgresql-18.7.tar.bz2.sha256",
  ]

  consulted = [
    # Read for facts only: that libpq is installed from three sub-makes.
    "pkgxdev/pantry projects/postgresql.org/libpq/package.yml",
  ]

  note = <<EOT
⛔ The old fragment's readline and ICU are gone on purpose; see the header.

⚠ NO SIGNATURE: PostgreSQL publishes only a .sha256 beside each tarball.

⛔ NOT BUILT. No session here can run the factory; the make targets and the
test are read from the sources, not run.
EOT
}
