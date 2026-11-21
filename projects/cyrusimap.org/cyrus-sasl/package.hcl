# cyrus-sasl — Cyrus SASL: libsasl2, its mechanism plugins, saslauthd and the
# sasldb tools.
#
# ⛔ WRITTEN FROM THE 2.1.28 TARBALL'S OWN FILES (go-zpkg/packages#440), not
# converted. It was a twenty-line fragment: dependencies, a configure call and
# one linux compiler flag.
#
# ⭐⭐ WHAT READING THE SOURCE FOUND:
#
#   1. THE FRAGMENT'S `--with-ssl=<openssl>` DOES NOT EXIST. The OpenSSL switch
#      is `--with-openssl` (m4/openssl.m4:7-9, default "yes"); the configure.ac
#      has no AC_ARG_WITH(ssl…). autoconf accepts an unknown --with-X with a
#      warning, so the flag was ignored, and OpenSSL was found only because it
#      is staged and "yes" means "look on the search path" (m4/openssl.m4:19-44).
#      The path was never passed. It is now: `--with-openssl=<prefix>` adds
#      -I<prefix>/include and the library directory (:14-16).
#   2. THE DATABASE BACKEND IS DECIDED BY THE BUILDER. `--with-dblib` defaults
#      to auto_detect (m4/sasldb.m4:6-12), which tries Berkeley DB, then lmdb,
#      then ndbm, then gdbm (:61-95). So an unstated recipe produces a sasldb
#      on whatever the machine had. It is stated: `berkeley`, with its include
#      and library directories handed over (--with-bdb-incdir/--with-bdb-libdir,
#      m4/berkdb.m4:256-266). The probe loop ends with a bare `-ldb`
#      (m4/berkdb.m4:243-250), which is what oracle.com/berkeley-db installs.
#   3. GSSAPI IS "YES" BY DEFAULT AND AUTO-FOUND (m4/sasl2.m4:9-13, :71-72).
#      kerberos.org is declared and handed over (`--enable-gssapi=<prefix>`,
#      :54-60), with `--with-gss_impl=mit` (:14-18) so Heimdal is not picked on
#      a host that has it.
#   4. EVERY OTHER OPTIONAL LIBRARY IS NAMED, because each is a probe that links
#      whatever it finds: PAM (configure.ac:553-575, default yes), LDAP (:670,
#      default no), SQL (:699, no), LDAPDB (:983, no), OPIE (:422, no default
#      and a probe), and sphinx-build for the docs (:1274-1287, a PATH search).

summary = "Cyrus SASL: the SASL authentication library, its plugins, saslauthd and the sasldb tools"

# COPYING:1-5 and :7-35: the Carnegie Mellon University licence, a four clause
# BSD style text whose clause 4 is an acknowledgment, and the disclaimer. SPDX
# names exactly this text BSD-Attribution-HPND-disclaimer.
#
# ⚠ THE BUILD LINKS AGPL CODE BY THIS RECIPE'S CHOICE. sasldb uses Berkeley DB
# 18.1.40 (AGPL-3.0-only, see oracle.com/berkeley-db). The licence field above
# is the project's own; what a consumer of libsasldb inherits is stated here
# rather than in the SPDX expression.
license = "BSD-Attribution-HPND-disclaimer"

versions {
  github = "cyrusimap/cyrus-sasl"
  strip  = ["/^cyrus-sasl-/"]
  ignore = ["/alpha|beta|rc/"]
}

# All three are linked into libsasl2's plugins (libotp and the digest and scram
# mechanisms use libcrypto, libgssapiv2 uses libgssapi_krb5, libsasldb uses
# libdb), so they are runtime dependencies, not only build ones.
dependencies = {
  "kerberos.org"           = "*"
  "openssl.org"            = "^3"
  "oracle.com/berkeley-db" = "*"
}

distributable {
  # The stored release asset (4034803 bytes) the maintainers uploaded, not the
  # tag archive GitHub generates. 2.1.28 (2022-02-18, the signature's creation
  # date) is the newest release `versions` resolves.
  url              = "https://github.com/cyrusimap/cyrus-sasl/releases/download/cyrus-sasl-{{version.raw}}/cyrus-sasl-{{version.raw}}.tar.gz"
  strip-components = 1

  # Recorded with `zpkb sourcepin`, and the same digest from an independent
  # fetch with curl and `shasum -a 256`.
  #
  # ⚠ THE SIGNATURE IS NOT A WITNESS HERE, and that is stated rather than
  # glossed. A detached signature is published beside the asset
  # (cyrus-sasl-2.1.28.tar.gz.sig, an RSA-4096 OpenPGP signature made
  # 2022-02-18 by key DEA1999F0CDB1AAEBA001E0DBEE3E3B4D2F06546). But the project
  # publishes NO public key for it: not in the tarball (searched for the key
  # id, and for gpg/pgp/.sig in doc/ docsrc/ README INSTALL.TXT), not on
  # cyrusimap.org's SASL pages (home, installation, download, release notes),
  # not in the repository tree (no KEYS or *.asc, and none in cyrus-imapd's),
  # and the release body is two lines of links. No keyserver was asked, by
  # rule, so the fingerprint is the signature's own claim and nothing attests
  # it. It is recorded in this comment so that a key, once published, can be
  # checked against it.
  sha256 = {
    "2.1.28" = "7ccfc6abd01ed67c1a0924b353e526f1b766b21f42d4562ee635a8ebfc5bb38c"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env {
    # The configure probes add -L for the paths they are given but no rpath, and
    # the plugins (libgssapiv2, libsasldb, libotp…) are dlopened, so the rpaths
    # are stated for the three libraries the build links.
    LDFLAGS = "-L{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib -L{{deps.kerberos.org.prefix}}/lib -Wl,-rpath,{{deps.kerberos.org.prefix}}/lib -L{{deps.oracle.com/berkeley-db.prefix}}/lib -Wl,-rpath,{{deps.oracle.com/berkeley-db.prefix}}/lib"

    ARGS = [
      "--prefix={{prefix}}",
      "--disable-dependency-tracking",
      "--disable-silent-rules",

      # configure.ac:1065-1071. The framework is a replacement for Apple's own
      # SASL.framework. Any occurrence of the flag sets building_for_macosx=no
      # (the action-if-given), which is why it is spelt --disable-.
      "--disable-macos-framework",

      # Found by path, :14-16 of m4/openssl.m4.
      "--with-openssl={{deps.openssl.org.prefix}}",

      # m4/sasldb.m4:6-26 and m4/berkdb.m4:256-266.
      "--with-dblib=berkeley",
      "--with-bdb-incdir={{deps.oracle.com/berkeley-db.prefix}}/include",
      "--with-bdb-libdir={{deps.oracle.com/berkeley-db.prefix}}/lib",

      # m4/sasl2.m4:6-18 and :54-60.
      "--enable-gssapi={{deps.kerberos.org.prefix}}",
      "--with-gss_impl=mit",

      # Named OFF: each is a probe for a library nothing here declares.
      "--with-pam=no",
      "--with-ldap=no",
      "--disable-sql",
      "--disable-ldapdb",
      "--with-opie=no",
      "--with-sphinx-build=no",

      # configure.ac:75-78 (default yes): `client`, `server` and
      # http_digest_client are noinst_PROGRAMS (sample/Makefile.am:47), built
      # and never installed.
      "--disable-sample",

      # configure.ac:232-245. The default compiles saslauthd and records
      # /var/state/saslauthd as its socket directory, a path that exists on few
      # hosts. The socket is mutable state, so it is pointed outside the prefix,
      # at the directory distributions use.
      "--with-saslauthd=/var/run/saslauthd",
    ]

    # Inherited from the fragment, NOT measured here: a linux-only flag that
    # turns implicit declarations back into warnings for the old configure
    # probes under a recent gcc.
    linux {
      CFLAGS = "-Wno-implicit-function-declaration"
    }
  }

  # No `--disable-static`: configure.ac:115 is AC_DISABLE_STATIC, so static
  # libraries are already off unless --with-staticsasl is given (:103-107).
  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Makefile.am:68 SUBDIRS; utils/Makefile.am:48 sbin_PROGRAMS = @SASL_DB_UTILS@
# pluginviewer (saslpasswd2 and sasldblistusers2 exist because the dblib is not
# `none`); saslauthd/Makefile.am:2 sbin_PROGRAMS = saslauthd testsaslauthd.
provides = [
  "sbin/saslauthd",
  "sbin/testsaslauthd",
  "sbin/pluginviewer",
  "sbin/saslpasswd2",
  "sbin/sasldblistusers2",
]

test {
  script = [
    # saslauthd prints "saslauthd <VERSION>" and its mechanisms to stderr
    # (saslauthd-main.c:964-975).
    "{{prefix}}/sbin/saslauthd -v 2>&1 | grep 'saslauthd {{version.raw}}'",

    # The plugins the recipe's decisions switch on, by what the mechanisms
    # print. GSSAPI is kerberos.org's, SCRAM-SHA-256 and DIGEST-MD5 and OTP are
    # OpenSSL's (configure.ac:373, :340, :400-407).
    "{{prefix}}/sbin/pluginviewer -a > mechs.txt 2>&1",
    "grep GSSAPI mechs.txt",
    "grep SCRAM-SHA-256 mechs.txt",
    "grep DIGEST-MD5 mechs.txt",
    "grep OTP mechs.txt",

    # The Berkeley DB decision, end to end: create a user (saslpasswd2 -p reads
    # the password from stdin, saslpasswd.c:306-310), then list it back.
    "echo secret | {{prefix}}/sbin/saslpasswd2 -p -c -f sasldb.test -u example.org alice",
    "test -s sasldb.test",
    "{{prefix}}/sbin/sasldblistusers2 -f sasldb.test | grep alice@example.org",
  ]
}

provenance {
  read = [
    "configure.ac",         # :51 AC_INIT 2.1.28; :75-78 sample; :103-107 staticsasl; :115 AC_DISABLE_STATIC; :232-245 saslauthd; :373-407 scram/otp; :422-447 opie; :553-575 pam; :670-688 ldap; :699 sql; :983 ldapdb; :1045-1055 plugindir/configdir; :1065-1071 macos-framework; :1274-1287 sphinx
    "m4/openssl.m4",        # :7-9 --with-openssl default yes; :14-16 path handling; no --with-ssl anywhere
    "m4/sasldb.m4",         # :6-12 --with-dblib default auto_detect; :18-95 the backends tried in order
    "m4/berkdb.m4",         # :204-254 the library name loop ending in -ldb; :256-266 --with-bdb-libdir/--with-bdb-incdir
    "m4/sasl2.m4",          # :9-18 --enable-gssapi / --with-gss_impl; :54-60 the directory form; :71-72 the header probe
    "m4/kerberos_v4.m4",    # :81 --enable-krb4 default no
    "Makefile.am",          # :47-68 SAD, PWC, SAM, SUBDIRS
    "utils/Makefile.am",    # :48 sbin_PROGRAMS
    "saslauthd/Makefile.am", # :2 sbin_PROGRAMS
    "sample/Makefile.am",   # :47 noinst_PROGRAMS
    "saslauthd/saslauthd-main.c", # :964-975 show_version
    "utils/saslpasswd.c",   # :306-337 options -p -c -f -u
    "COPYING",              # CMU licence, :1-35
  ]

  consulted = [
    "https://www.cyrusimap.org/sasl/",                                                 # the project's pages, read for a signing key: none
    "https://www.cyrusimap.org/sasl/sasl/installation.html",
    "https://github.com/cyrusimap/cyrus-sasl/releases/tag/cyrus-sasl-2.1.28",           # the assets and the two line release body
    "pkgxdev/pantry projects/cyrusimap.org/cyrus-sasl/package.yml",                     # facts only: the fragment this recipe replaces
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the options are read from the
files above, the digest is measured, and the test block is written from the
sources' own output strings (saslauthd-main.c:964-975, saslpasswd.c:306-310),
not from a run.

⚠ UNMEASURED, and the first thing to look at if the build fails:
  - the plugins' rpaths: LDFLAGS carries them for openssl, kerberos and
    berkeley-db, but a plugin's link line is libtool's, and whether the flags
    reach it was not checked;
  - Berkeley DB 18 is found by the bare `-ldb` fallback of berkdb.m4:243-250,
    and 18.1.40's header is db.h in the include directory of that package; the
    link probe `db_open` of :247 is the OLD API and is only reached if the
    `db_create` probe at :236-238 fails.

⚠ THE SIGNATURE IS UNVERIFIED, for want of a published key: see the comment on
the digest. The two witnesses are two fetches that agree.

⚠ saslauthd's PAM, LDAP and shadow mechanisms: PAM and LDAP are off; getpwent
and shadow are libc and stay; kerberos5 follows from GSSAPI. Nothing here
checks which mechanisms the built binary lists.

The sasldb path stays at its default, /etc/sasldb2 (sasldb.m4:168): a database
is host state, like saslauthd's socket directory.
EOT
}
