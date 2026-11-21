# apr-util — Apache Portable Runtime Utility Library: XML, URI, buckets,
# hashing, crypto, DBM and DBD interfaces on top of APR.
#
# ⛔ WRITTEN FROM APR-UTIL'S OWN FILES at 1.6.6, continuing go-zpkg/packages#440
# step 1. Serf and Subversion both depend on "apache.org/apr-util" and no
# recipe for it existed in this tree.

summary = "Apache Portable Runtime Utility Library: XML, URI, hashing, crypto, DBM and DBD on top of APR"

# LICENSE opens "Apache License" and NOTICE is the ASF's standard notice.
license = "Apache-2.0"

versions {
  # ⛔ archive.apache.org, NOT downloads.apache.org (current files only there).
  url   = "https://archive.apache.org/dist/apr/"
  match = "/apr-util-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^apr-util-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://archive.apache.org/dist/apr/apr-util-{{version.raw}}.tar.bz2"
  strip-components = 1

  # 442523 bytes. TWO WITNESSES, BOTH CHECKED WHEN THE DIGEST WAS RECORDED:
  #
  #   1. The release's own published checksum, apr-util-1.6.6.tar.bz2.sha256,
  #      reads the digest below and `shasum -a 256` of the bytes fetched here
  #      gives the same value.
  #
  #   2. The detached signature apr-util-1.6.6.tar.bz2.asc verifies with gpg
  #      against https://downloads.apache.org/apr/KEYS (Apache's published
  #      keys file, no keyserver asked): "Good signature", key
  #      65B2D44FE74BD5E3DE3AC3F082781DE46D5954FA, Eric Covener
  #      <covener@apache.org>, signed 2026-10-29.
  sha256 = {
    "1.6.6" = "aa77dd25f036731b7246abbfbebe6cc813b42799b62c874bc82bd4e1f90f2918"
  }
}

# What configure links, from build/apu-conf.m4 and build/crypto.m4:
#
#   apache.org/apr     --with-apr (build/find_apr.m4:100); required.
#   libexpat.github.io --with-expat=DIR (apu-conf.m4:135-150): "Expat cannot be
#                      disabled (at this time)" (:140), and the bundled copy is
#                      gone, so the system search is the only path.
#   openssl.org        only through --with-crypto (crypto.m4:34-73): without
#                      that flag apu_have_crypto=0 (:72) and OpenSSL is never
#                      looked at. 1.6.6 supports OpenSSL 3 (CHANGES:75,
#                      apr_crypto_openssl.c:42,80).
dependencies = {
  "apache.org/apr"     = "^1"
  "libexpat.github.io" = "^2"
  "openssl.org"        = "^3"
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--with-apr={{deps.apache.org/apr.prefix}}",
      "--with-expat={{deps.libexpat.github.io.prefix}}",

      # ⛔ OFF BY DEFAULT, SO ASKED FOR: with no --with-crypto the apr_crypto
      # interface is compiled out (crypto.m4:72) and the openssl dependency
      # above would be declared and unused. --with-openssl=DIR (:88-101) adds
      # -I DIR/include and -L DIR/lib -L DIR/lib64.
      "--with-crypto",
      "--with-openssl={{deps.openssl.org.prefix}}",
    ]
  }

  # LDFLAGS carries the run-time search path of the two libraries configure
  # reaches only by -L (apu-conf.m4:144, crypto.m4:101), so the installed
  # libaprutil finds them without an environment variable.
  #
  # NOT PASSED, AND WHY: every other backend is opt-in in this release. DBM:
  # gdbm "unless the user asks for it" (dbm.m4:555), ndbm (:637-640) and
  # Berkeley DB (:648-650) likewise, so the build has sdbm alone; LDAP is
  # looked for only under --with-ldap (apu-conf.m4:233-235); the DBD drivers
  # (pgsql dbd.m4:31, mysql :168, sqlite3 :258, odbc :431) are all
  # --with-<name>. SQLite is left out on purpose: its recipe is blocked on
  # go-zpkg/artifact#238, so apr_dbd_sqlite3 is not built here.
  script = <<EOT
export LDFLAGS="-Wl,-rpath,{{deps.libexpat.github.io.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib"
./configure $ARGS
make -j {{ hw.concurrency }}
make install
EOT
}

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test \"$(apu-1-config --version)\" = \"{{version.raw}}\"",
    "test \"$(pkg-config --modversion apr-util-1)\" = \"{{version.raw}}\"",
    "test -f {{prefix}}/include/apr-1/apr_uri.h",
    "test -f {{prefix}}/lib/libaprutil-1.a",

    # THROUGH THE LIBRARY, with the two features this recipe turned on: the
    # crypto interface and the expat-backed XML parser. apu_version() says what
    # the library is.
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <apr_pools.h>
#include <apr_general.h>
#include <apu_version.h>
#include <apr_xml.h>
#include <apr_crypto.h>

int main(void) {
  apr_pool_t *pool;
  apr_version_t v;
  apr_xml_parser *parser;
  apr_initialize();
  apr_pool_create(&pool, NULL);
  apu_version(&v);
  if (v.major != APU_MAJOR_VERSION || v.minor != APU_MINOR_VERSION ||
      v.patch != APU_PATCH_VERSION) {
    printf("header %s but library %d.%d.%d\n", APU_VERSION_STRING, v.major,
           v.minor, v.patch);
    return 1;
  }
  parser = apr_xml_parser_create(pool);
  if (parser == NULL) {
    return 2;
  }
  if (apr_crypto_init(pool) != APR_SUCCESS) {
    return 3;
  }
  printf("libaprutil %d.%d.%d with xml and crypto\n", v.major, v.minor, v.patch);
  apr_terminate();
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o libcheck $(pkg-config --cflags --libs apr-util-1 apr-1)"
    },
    "./libcheck",
  ]
}

provenance {
  read = [
    "build/apu-conf.m4",  # :135-150 --with-expat, "Expat cannot be disabled" :140; :233-235 --with-ldap opt-in
    "build/crypto.m4",    # :34-73 --with-crypto, default apu_have_crypto=0 :72; :88-101 --with-openssl
    "build/dbm.m4",       # :555 gdbm only on request; :637-640 ndbm; :648-650 Berkeley DB; :543 --with-dbm
    "build/dbd.m4",       # :31 pgsql, :168 mysql, :258 sqlite3, :431 odbc, all --with-<name>
    "build/find_apr.m4",  # :100 --with-apr
    "crypto/apr_crypto_openssl.c", # :42 and :80 OPENSSL_VERSION_NUMBER >= 0x30000000 branches
    "CHANGES",            # :75 "apr_crypto_openssl: Compatibility with OpenSSL 3"
    "apr-util.pc.in",     # the apr-util-1 pkg-config name
    "LICENSE",
    "NOTICE",
  ]

  consulted = [
    "https://downloads.apache.org/apr/",
    "https://downloads.apache.org/apr/KEYS",
    "https://downloads.apache.org/apr/apr-util-1.6.6.tar.bz2.asc",
    "https://downloads.apache.org/apr/apr-util-1.6.6.tar.bz2.sha256",
    "https://archive.apache.org/dist/apr/",
  ]

  note = <<EOT
Autoconf build, written from the m4 files above. Nothing was converted and no
third-party recipe was used.

Signature, for the record:

  https://downloads.apache.org/apr/apr-util-1.6.6.tar.bz2.asc
  key         https://downloads.apache.org/apr/KEYS (Apache's published keys)
  identity    Eric Covener <covener@apache.org>
  fingerprint 65B2D44FE74BD5E3DE3AC3F082781DE46D5954FA
  checked     when the digest was recorded, not at every build

⛔ SQLITE: apr_dbd_sqlite3 is not built (--with-sqlite3 is not passed) because
the sqlite recipe is blocked on go-zpkg/artifact#238. Subversion does not need
it.

⛔ NOT RUN: the build script is read-checked, not executed.
EOT
}
