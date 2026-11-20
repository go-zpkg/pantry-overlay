# freetds.org — the TDS client libraries (Sybase / Microsoft SQL Server) and
# the tsql, freebcp and bsqldb tools. One of the fragments of
# go-zpkg/packages#440: it declared four dependencies and nothing else.
#
# ⛔ WRITTEN FROM FREETDS'S OWN FILES, at 1.5.22.
#
# ⭐⭐ THE FINDING: FOUR OPTIONAL FEATURES, AND EACH OF THEM IS DROPPED
# SILENTLY WHEN ITS LIBRARY IS NOT FOUND. configure.ac probes for readline,
# Kerberos and OpenSSL and carries on without them on a miss; only
# --with-unixodbc is fatal. A recipe that declares the four dependencies and
# passes nothing would stage them, link none, and exit 0. Each is named below
# with the line that makes it loud, and the test reads the result back.

summary = "FreeTDS: libraries and tools (tsql, freebcp, bsqldb) speaking TDS to Sybase and SQL Server"

# README.md:16: "FreeTDS is licensed under the GNU LGPL license", and
# src/dblib/dblib.c:5-8 names the GNU Library General Public License, version
# 2 or later. That is the libraries. COPYING.txt (the GPL) sits beside
# COPYING_LIB.txt for the programs; the recipe states the library licence,
# which is what a consumer linking libct or libsybdb receives.
license = "LGPL-2.0-or-later"

versions {
  # Tags are `v1.5.22`. The repository also carries a release-candidate tag,
  # `R1_6RC1`, whose asset is freetds-1.6rc1.tar.bz2: the `strip` only removes
  # a leading `v`, so a tag that does not look like a version is for
  # `zpkb versions` to refuse, and the resolved list is checked below.
  github = "FreeTDS/freetds/releases"
  strip  = ["/^v/"]
}

dependencies = {
  # All four are LINKED by the installed programs or libraries (see build),
  # so they are runtime and not build-only.
  "gnu.org/readline" = "*"
  "kerberos.org"     = "*"
  "openssl.org"      = "^3"
  "unixodbc.org"     = "*"
}

distributable {
  # The stored release asset on GitHub. The project's own download area,
  # https://www.freetds.org/files/stable/freetds-1.5.22.tar.bz2, serves the
  # same bytes: fetched from both, the sha256 is identical.
  url              = "https://github.com/FreeTDS/freetds/releases/download/v{{version.raw}}/freetds-{{version.raw}}.tar.bz2"
  strip-components = 1

  # 3923670 bytes. Witnesses: (1) the sha256 of the GitHub asset and of the
  # website copy agree; (2) the website publishes freetds-1.5.22.tar.bz2.md5 =
  # 5434e94d59a3a01260dd2864b637dfb2, and the md5 of these bytes is that. There
  # is NO signature: freetds-1.5.22.tar.bz2.asc answers 404. So the second
  # witness is a published checksum on the project's own host, which proves the
  # two hosts agree, not that the author signed.
  sha256 = {
    "1.5.22" = "b31cbc50f9e2ad4adf8dd3958807e4e7b8f4e588b080f8dbddbe465ceefb9231"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ OpenSSL. m4/check_openssl.m4:10 runs PKG_CHECK_MODULES(OPENSSL,
      # [openssl]) first, so a preset OPENSSL_CFLAGS and OPENSSL_LIBS (set in
      # the script) bypass pkg-config. :31-32 makes a miss FATAL only when
      # --with-openssl was given a value; with no value a miss falls through
      # silently. So the value is the point of this line.
      "--with-openssl={{deps.openssl.org.prefix}}",

      # ⛔ unixODBC. configure.ac:594-637: --with-unixodbc=DIR uses
      # DIR/bin/odbc_config if present, else DIR/include and DIR/lib, and is
      # fatal when sql.h is not found. It also builds libtdsodbc and bsqlodbc
      # (src/apps/Makefile.am:8-10, conditional on ODBC).
      "--with-unixodbc={{deps.unixodbc.org.prefix}}",

      # ⛔ Kerberos. configure.ac:161-170: no option leaves krb5_libs empty
      # (off). A bare --enable-krb5 is the `auto` arm, whose probe at :214-221
      # (AC_SEARCH_LIBS gss_init_sec_context over gssapi_krb5, gssapi) defines
      # ENABLE_KRB5 only if found: a silent drop. An explicit library takes
      # the :222-225 arm and sets it unconditionally, so a missing GSSAPI
      # fails at link time.
      "--enable-krb5=-lgssapi_krb5",
    ]
  }

  script = [
    # ⛔ readline has NO option: configure.ac:241-272 probes unconditionally
    # with AC_CHECK_LIB([readline],[readline]) and, on a miss, resets LIBS and
    # drops HAVE_READLINE without a word. The only way to reach it is the
    # search paths, so they are set here, with those of Kerberos.
    {
      run = <<EOT
set -eu
export CPPFLAGS="-I{{deps.gnu.org/readline.prefix}}/include -I{{deps.kerberos.org.prefix}}/include"
export LDFLAGS="-L{{deps.gnu.org/readline.prefix}}/lib -L{{deps.kerberos.org.prefix}}/lib"
export OPENSSL_CFLAGS="-I{{deps.openssl.org.prefix}}/include"
export OPENSSL_LIBS="-L{{deps.openssl.org.prefix}}/lib -lssl -lcrypto"
./configure $ARGS
EOT
    },
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = [
  "bin/tsql",
  "bin/freebcp",
  "bin/bsqldb",
  "bin/bsqlodbc",
  "bin/defncopy",
  "bin/datacopy",
  "bin/osql",
  "bin/tdspool",
]

test {
  script = [
    "test -x \"{{prefix}}/bin/tsql\"",
    "test -x \"{{prefix}}/bin/bsqlodbc\"",
    "test -x \"{{prefix}}/bin/tdspool\"",
    {
      run = <<EOT
set -eu
ls "{{prefix}}"/lib/libsybdb.* >/dev/null 2>&1 \
  || { echo "libsybdb is missing from {{prefix}}/lib" >&2; exit 1; }
ls "{{prefix}}"/lib/libct.* >/dev/null 2>&1 \
  || { echo "libct is missing from {{prefix}}/lib" >&2; exit 1; }
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR THE SILENT DROPS. `tsql -C`
    # (src/apps/tsql.c:503-518) prints one `<name>: yes|no` line each for
    # iconv, unixodbc, Kerberos, OpenSSL, GnuTLS and MARS, read from what
    # configure decided, so it answers for the artifact and not the build log.
    {
      run = <<EOT
set -eu
out=$("{{prefix}}/bin/tsql" -C)
for feature in unixodbc Kerberos OpenSSL; do
  case "$out" in
    *"$feature: yes"*) ;;
    *) echo "tsql was built without $feature:" >&2; echo "$out" >&2; exit 1 ;;
  esac
done
EOT
    },

    # readline is not in `tsql -C`, so it is read off the binary: tsql.c:34-35
    # includes readline, and a build that linked it names libreadline (the
    # shared object) in the executable. The bare word `readline` would match
    # the function tsql_readline (tsql.c:113), hence `libreadline`.
    "grep -q libreadline \"{{prefix}}/bin/tsql\"",
  ]
}

provenance {
  read = [
    "configure.ac",            # :161-170,:214-228 Kerberos and its silent arm; :241-272 readline, no option; :594-637 --with-unixodbc; :802-834 GnuTLS off, else CHECK_OPENSSL
    "m4/check_openssl.m4",     # :10 PKG_CHECK_MODULES first, so OPENSSL_CFLAGS/LIBS bypass it; :31-32 fatal only with a value
    "README.md",               # :16 the licence
    "COPYING_LIB.txt",         # the library licence text
    "src/dblib/dblib.c",       # :5-8 GNU Library General Public License, version 2 or later
    "src/apps/Makefile.am",    # :7 tsql freebcp bsqldb defncopy datacopy; :8-10 bsqlodbc only with ODBC; :14 osql
    "src/pool/Makefile.am",    # :2 tdspool
    "src/server/Makefile.am",  # :5 tdssrv is noinst, not provided
    "src/apps/tsql.c",         # :34-35 readline; :113 tsql_readline; :503-518 the -C feature report
    "https://www.freetds.org/files/stable/", # the download area, and the .md5 beside each archive
  ]

  note = <<EOT
The distributable is the GitHub release asset v1.5.22
(freetds-1.5.22.tar.bz2). The project's own site serves the same file
(https://www.freetds.org/files/stable/freetds-1.5.22.tar.bz2) with the same
sha256, and publishes a .md5 beside it which equals the md5 of these bytes.

⚠ NO SIGNATURE EXISTS to check: the .asc beside the archive answers 404. The
second witness is therefore a published checksum and a second host agreeing on
the bytes, which is weaker than a signature; no key was fetched and no keyserver
was asked.

bsqlodbc is listed in provides because --with-unixodbc is fatal when it is
missing, so the ODBC arm that builds it always runs here.
EOT
}
