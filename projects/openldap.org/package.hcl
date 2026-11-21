# openldap — the OpenLDAP libraries (liblber, libldap), the client tools, slapd
# and its overlays.
#
# ⛔ WRITTEN FROM THE 2.7.2 TARBALL'S OWN FILES (go-zpkg/packages#440), not
# converted. It was a thirty-line fragment: a linux-only dependency, OpenSSL, a
# list of overlays, one sed on the Makefile and one linux linker flag.
#
# ⭐⭐ WHAT READING THE SOURCE FOUND:
#
#   1. TLS AND SASL WERE LEFT TO PROBES. `--with-tls` defaults to `auto`
#      (configure.ac:251-253), which tries OpenSSL, GnuTLS and mbedTLS in turn
#      and takes whichever the build host has; `--with-cyrus-sasl` defaults to
#      `auto` (:242-243) and is silently dropped when the library is missing
#      (:1884-1896). The fragment declared openssl.org and nothing for SASL, so
#      its libldap had SASL only on hosts that happened to carry it. Both are
#      now stated, and SASL is `yes`, which makes a missing library a refusal
#      (:1896).
#   2. THE `util-linux` DEPENDENCY IS A UUID PROBE, NOT A NEED. entryUUID comes
#      from libuuid's uuid_generate (:1029-1047) when <uuid/uuid.h> is present,
#      and from OpenLDAP's own generator otherwise. macOS has the header in libc
#      and the dependency is linux-only, as the fragment had it. ⚠ util-linux is
#      NOT merged in go-zpkg/recipes yet (it is the last recipe of this
#      campaign step); it resolves through the fragment until then.
#   3. THE OVERLAYS ALL EXIST AND ARE ALL OFF BY DEFAULT except syncprov
#      (:335-384). The fragment's seventeen `--enable-` names were each checked
#      against that list; `syncprov` (default yes) and the `mdb` and `relay`
#      backends (default yes, :309-320) need no flag. mdb is the only database
#      backend that is built: bdb and hdb no longer exist in 2.7.
#   4. EVERY OTHER OPTIONAL THING IS NAMED, because each is a probe or a
#      default: systemd (:244, auto, ON when libsystemd is found), threads
#      (:248, auto), the argon2 module (:392, off, so its library probe at :2484
#      is not reached) and ODBC, which only the sql backend would need.
#   5. THE DOCS NEED soelim. build/man.mk:25-39 pipes every page through
#      `$(SOELIM)`, set to a bare `soelim` (build/top.mk:156), and soelim is
#      groff's. The fragment cut `doc` from the top Makefile's SUBDIRS
#      (Makefile.in:16) so as not to need it; that is kept, with the man pages
#      lost as the price. It is a sed on the generated Makefile and not a
#      `make SUBDIRS=` because a variable given on the command line overrides
#      the SUBDIRS of every sub-make too (libraries has its own).

summary = "OpenLDAP: LDAP client libraries and tools, and the slapd directory server"

# LICENSE:1-2 "The OpenLDAP Public License, Version 2.8, 17 August 2003": SPDX
# OLDAP-2.8.
license = "OLDAP-2.8"

versions {
  url   = "https://www.openldap.org/software/download/OpenLDAP/openldap-release/"
  match = "/openldap-\\d+\\.\\d+\\.\\d+\\.tgz/"
  strip = [
    "/^openldap-/",
    "/\\.tgz$/",
  ]
}

# libssl and libcrypto are linked into libldap and slapd; libsasl2 is linked
# into libldap (:1884-1900).
dependencies = {
  "cyrusimap.org/cyrus-sasl" = "*"
  "openssl.org"              = "^3"

  linux = {
    "github.com/util-linux/util-linux" = "*"
  }
}

distributable {
  # https://www.openldap.org/software/download/ lists the release as 2.7.2
  # (feature release) and 2.6.16 (long term support). 2.7.2 is the newest the
  # index resolves. Both are signed, and each was verified with the project's
  # key when its digest was recorded.
  url              = "https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-{{version.raw}}.tgz"
  strip-components = 1

  # Recorded with `zpkb sourcepin --sig auto`. The signature URL is not a recipe
  # field (go-zpkg/zpkb#282); it is
  # https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.7.2.tgz.asc
  # and is in the provenance block.
  sha256 = {
    "2.7.2" = "aad731aa22118ff327b9b4ddfc4b6f18ef9476586205da88a532e90940b523d2"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    "gnu.org/sed"  = "*"
  }

  env {
    # configure.ac probes headers and libraries on the compiler's search path;
    # the two prefixes are put on it, with an rpath for the three shared
    # libraries, because the tools and slapd are linked against them.
    CPPFLAGS = "-I{{deps.openssl.org.prefix}}/include -I{{deps.cyrusimap.org/cyrus-sasl.prefix}}/include"
    LDFLAGS  = "-L{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib -L{{deps.cyrusimap.org/cyrus-sasl.prefix}}/lib -Wl,-rpath,{{deps.cyrusimap.org/cyrus-sasl.prefix}}/lib"

    ARGS = [
      "--prefix={{prefix}}",
      "--disable-dependency-tracking",

      # :251-253 and :242-243.
      "--with-tls=openssl",
      "--with-cyrus-sasl=yes",

      # :244, auto and ON when libsystemd is present: a service notification
      # nothing here supervises.
      "--without-systemd",

      # The overlays, :335-384, off unless named. Kept from the fragment, each
      # checked against that list.
      "--enable-accesslog",
      "--enable-auditlog",
      "--enable-constraint",
      "--enable-dds",
      "--enable-deref",
      "--enable-dyngroup",
      "--enable-dynlist",
      "--enable-memberof",
      "--enable-ppolicy",
      "--enable-proxycache",
      "--enable-refint",
      "--enable-retcode",
      "--enable-seqmod",
      "--enable-translucent",
      "--enable-unique",
      "--enable-valsort",
    ]

    # Inherited from the fragment, NOT measured here: with --enable-versioning
    # at its default `auto`, configure.ac:2525-2537 turns on a GNU version
    # script when the linker offers one, and recent lld/ld refuse a script that
    # names a symbol the library does not define.
    linux {
      CFLAGS = "-Wl,--undefined-version"
    }
  }

  script = [
    "./configure $ARGS",

    # See finding 5: the man pages need groff's soelim.
    "sed -i.bak -e 's/SUBDIRS=\\(.*\\)\\bdoc\\b\\(.*\\)/SUBDIRS=\\1\\2/' Makefile",
    "rm Makefile.bak",

    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# clients/tools/Makefile.in:34-35 PROGRAMS and :136-137 (ldapadd is a link to
# ldapmodify); servers/slapd/Makefile.in:364-368 installs slapd into libexecdir
# and :16 and :450-455 link each SLAPTOOLS name into sbindir.
provides = [
  "bin/ldapadd",
  "bin/ldapcompare",
  "bin/ldapdelete",
  "bin/ldapexop",
  "bin/ldapmodify",
  "bin/ldapmodrdn",
  "bin/ldappasswd",
  "bin/ldapsearch",
  "bin/ldapurl",
  "bin/ldapvc",
  "bin/ldapwhoami",
  "libexec/slapd",
  "sbin/slapacl",
  "sbin/slapadd",
  "sbin/slapauth",
  "sbin/slapcat",
  "sbin/slapdn",
  "sbin/slapindex",
  "sbin/slapmodify",
  "sbin/slappasswd",
  "sbin/slapschema",
  "sbin/slaptest",
]

test {
  script = [
    # clients/tools/common.c:1131-1135: -VV prints the version and exits.
    "ldapcompare -VV 2>&1 | grep {{version.raw}}",

    # SASL and TLS, the two decisions this recipe states: the build line of
    # `ldapsearch -VV` is not parsed, so what is asserted is that the program
    # runs and that slapd, with the overlays, is the same version.
    "ldapsearch -VV 2>&1 | grep {{version.raw}}",
    "{{prefix}}/libexec/slapd -VV 2>&1 | grep {{version.raw}}",
  ]
}

provenance {
  read = [
    "configure.ac",        # :242-263 the with-options; :284-294 slapd options; :300-324 backends; :330-384 overlays; :392-396 argon2; :417-418 versioning; :1029-1047 uuid; :1884-1900 cyrus sasl; :2484 argon2 probe; :2525-2537 version script
    "Makefile.in",         # :16 SUBDIRS
    "doc/Makefile.in",     # :16 SUBDIRS = man
    "build/man.mk",        # :25-39 every page piped through $(SOELIM)
    "build/top.mk",        # :156 SOELIM=soelim
    "clients/tools/Makefile.in", # :34-35 PROGRAMS; :128-137 install-local
    "servers/slapd/Makefile.in", # :16-17 SLAPTOOLS; :364-368 slapd to libexecdir; :450-455 tool links
    "clients/tools/common.c", # :1131-1135 -V / -VV
    "LICENSE",             # OpenLDAP Public License 2.8
  ]

  consulted = [
    "https://www.openldap.org/software/download/",                                                       # the release list, the .asc links and the key link
    "https://www.openldap.org/software/download/OpenLDAP/gpg-pubkey.txt",                                # the project's key, linked from the page above
    "https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.7.2.tgz.asc",       # the detached signature
    "pkgxdev/pantry projects/openldap.org/package.yml",                                                  # facts only: the fragment this recipe replaces
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the options are read from the
files above, the digest was measured and the signature verified, and the test
block is written from the sources' own output strings, not from a run.

The source archive is signed, and the signature was checked when the digest was
recorded rather than at every build:

  signature  https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.7.2.tgz.asc
  identity   OpenLDAP Project <project@openldap.org>
  signed at  2026-10-22T15:21:48Z
  key        3CE269B5398BC8B785645E987F67D5FD1CE1CBCE, from
             https://www.openldap.org/software/download/OpenLDAP/gpg-pubkey.txt,
             linked from https://www.openldap.org/software/download/

No keyserver was consulted. 2.6.16 (the LTS) is not pinned: `versions` resolves
the newest, 2.7.2.

⚠ UNMEASURED, and the first thing to look at if the build fails:
  - whether `\b` in the sed is understood by the sed that gnu.org/sed installs
    (it is GNU; BSD sed has no \b), which is why gnu.org/sed is a build
    dependency here as in the fragment;
  - the linux CFLAGS: a linker flag in CFLAGS, carried over unmeasured;
  - cyrus-sasl's own recipe is also unbuilt, so SASL here is a dependency on
    an unmeasured package;
  - util-linux resolves through the fragment, see finding 2.

Man pages are NOT installed (finding 5).
EOT
}
