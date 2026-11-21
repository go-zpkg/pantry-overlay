# oracle.com/berkeley-db — Oracle Berkeley DB: the embedded key/value library
# and its db_* utilities.
#
# ⛔ WRITTEN FROM THE 18.1.40 TARBALL'S OWN FILES (go-zpkg/packages#440), not
# converted. It was a four-line fragment declaring one dependency.
#
# ⭐⭐ WHAT READING THE SOURCE FOUND, in three parts:
#
#   1. TWO FLAGS THE OLD RECIPE PASSED DO NOT EXIST IN THIS RELEASE.
#      `--enable-sql` and `--enable-sql_codegen` come from the 5.x/6.x tree.
#      18.1.40's `dist/aclocal/options.m4` has no `AC_ARG_ENABLE(sql…)` and its
#      generated `dist/configure` mentions "sql" three times, none of them an
#      option; `lang/` holds csharp cxx db185 dbm hsearch java perl php_db4 tcl
#      and NO `sql`. autoconf accepts an unknown --enable-X with a warning, so
#      both flags were silently ignored — a recipe stating a feature the build
#      never had. They are left out, and so is the `dbsql` shell nobody got.
#   2. OPENSSL IS NOT OPTIONAL BY DEFAULT: --with-repmgr-ssl defaults to
#      "default", which means ON whenever replication is built
#      (options.m4:476-494), and then configure.ac:888-939 probes -lssl and
#      -lcrypto and accepts whatever it finds on the search path. The flag is
#      stated `yes`, and the paths are passed, so the result is not decided by
#      what the builder happened to have.
#   3. THE C++ TLS PROBE FAILS ON CURRENT CLANG. dist/aclocal/tls.m4:20-29 uses
#      `NULL` in a C++ translation unit that includes nothing. MEASURED with
#      this machine's Apple clang 21 (clang++ -c on that exact snippet):
#      "use of undeclared identifier 'NULL'", and the same file compiles with
#      `-include stddef.h`. With the probe failing, --enable-stl has no TLS
#      class. So CPPFLAGS carries `-include stddef.h`.

summary = "Oracle Berkeley DB: embedded key/value database library and db_* tools"

# LICENSE:7-8 "The Oracle Berkeley DB product is licensed under the GNU AFFERO
# GENERAL PUBLIC LICENSE", :11-12 Version 3. The "or any later version" at
# :646-648 is the licence's own template text, not a grant by Oracle, so this
# is -only (homebrew-core records the same). :676 onwards carries third party
# BSD notices (UC Regents, 1990-1995) for files that came from elsewhere.
license = "AGPL-3.0-only"

# ⛔ A STATIC LIST, AND WHY. Oracle publishes no machine-readable release list:
# download.oracle.com serves no directory index, and the downloads page names
# the distribution by a login-gated bundle, V997917-01.zip, not by the tarball.
# 18.1.40 (May 29, 2020, RELEASE:DB_RELEASE_DATE) is the last open-source
# release of the line, and Oracle's downloads page links its changelog as
# changelog_18_1_40.html and no later one. The project is no longer released.
versions = ["18.1.40"]

dependencies = {
  # configure.ac:888-939, reached because --with-repmgr-ssl=yes below: the
  # library links libssl and libcrypto (LIBSO_LIBS gains -lssl -lcrypto).
  "openssl.org" = "^3"
}

distributable {
  # The tarball Oracle serves unauthenticated from download.oracle.com. 30763705
  # bytes, Last-Modified 2020-06-01.
  url              = "https://download.oracle.com/berkeley-db/db-{{version.raw}}.tar.gz"
  strip-components = 1

  # Recorded with `zpkb sourcepin`.
  #
  # ⚠ NO SIGNATURE AND NO PUBLISHED CHECKSUM FOR THIS FILE, stated. Oracle's
  # downloads page does print a SHA256 — 1af4a120…dd35b — but for the OTHER
  # artefact, the 42751957-byte zip V997917-01.zip, not this tarball. So the
  # corroboration is two things, and neither is the author's:
  #   - a second independent fetch (curl + shasum -a 256) giving the same digest;
  #   - homebrew-core's formula records the same sha256.
  sha256 = {
    "18.1.40" = "0cecb2ef0c67b166de93732769abdeba0555086d51de1090df325e18ee8da9c8"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  # ⛔ EVERYTHING BUILDS FROM build_unix (README → docs/installation): the
  # configure script is ../dist/configure.
  working-directory = "build_unix"

  env {
    # configure.ac has no --with-openssl; the only route is the compiler flags
    # (its own error text, :908-910, says "by setting LDFLAGS/LIBS/CPPFLAGS").
    # `-include stddef.h` is finding 3 of the header.
    CPPFLAGS = "-include stddef.h -I{{deps.openssl.org.prefix}}/include"
    LDFLAGS  = "-L{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib"

    ARGS = [
      "--prefix={{prefix}}",

      # options.m4:157-162: debug defaults no. Named so a change is visible.
      "--disable-debug",
      "--disable-static",

      # The language bindings and extras, each stated. Defaults read from
      # options.m4: cxx :150-155 no, stl :266-274 no, compat185 :143-148 no,
      # dbm :305 no, java :212-217 no, tcl :276-281 no, test :283-288 no,
      # dump185 :205-210 no. The first four are turned ON; the last four are
      # stated OFF because each pulls a host tool (a JDK, tclsh).
      "--enable-cxx",
      "--enable-stl",
      "--enable-compat185",
      "--enable-dbm",
      "--disable-java",
      "--disable-tcl",
      "--disable-test",
      "--disable-dump185",

      # options.m4:459-474 and :476-494, stated rather than defaulted. The
      # cryptography is Berkeley DB's own software implementation (`yes`, as
      # opposed to Intel IPP), which needs no library.
      "--with-cryptography=yes",
      "--with-repmgr-ssl=yes",
    ]
  }

  # ⛔ `DOCLIST=license` is dist/Makefile.in:1302-1304's list of documentation
  # trees install_docs copies; narrowing it to `license` keeps the install from
  # carrying the whole documentation set. install_docs still creates $(docdir)
  # (:1308-1310), which is `{{prefix}}/docs`, so it is removed.
  # ⛔ NO `--jobs` ON make: homebrew-core's formula says "BerkeleyDB dislikes
  # parallel builds" and deparallelizes it. That is a third party's report and
  # was not reproduced here; serial is the cautious reading.
  script = [
    "../dist/configure $ARGS",
    "make install DOCLIST=license",
    "rm -rf {{prefix}}/docs",
  ]
}

# dist/Makefile.in:894-898, UTIL_PROGS: fifteen utilities, installed by
# install_utilities (:1279-1291). db_dump185 is added to that list only under
# --enable-dump185 (configure.ac:807-808), which is off.
provides = [
  "bin/db_archive",
  "bin/db_checkpoint",
  "bin/db_convert",
  "bin/db_deadlock",
  "bin/db_dump",
  "bin/db_hotbackup",
  "bin/db_load",
  "bin/db_log_verify",
  "bin/db_printlog",
  "bin/db_recover",
  "bin/db_replicate",
  "bin/db_stat",
  "bin/db_tuner",
  "bin/db_upgrade",
  "bin/db_verify",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    # `db_verify -V` prints DB_VERSION_STRING ("Berkeley DB 18.1.40: (May 29,
    # 2020)", RELEASE:DB_VERSION_STRING), so the tools are the ones just built.
    "db_verify -V | grep {{version.raw}}",
    "test -f {{prefix}}/include/db.h",
    "test -f {{prefix}}/include/db_cxx.h",
    # The tools through the library, then the library through the C++ API (what
    # homebrew-core's test also does). Put, get, close, and a file on disk.
    {
      fixture = {
        content  = <<EOT
#include <cstring>
#include <iostream>
#include <db_cxx.h>

int main() {
  Db db(NULL, 0);
  if (db.open(NULL, "test.db", NULL, DB_BTREE, DB_CREATE, 0) != 0) {
    std::cout << "open failed" << std::endl;
    return 1;
  }

  const char *k = "key";
  const char *v = "value stored by the fixture";
  Dbt key(const_cast<char *>(k), (u_int32_t)strlen(k) + 1);
  Dbt data(const_cast<char *>(v), (u_int32_t)strlen(v) + 1);
  if (db.put(NULL, &key, &data, DB_NOOVERWRITE) != 0) {
    std::cout << "put failed" << std::endl;
    return 1;
  }

  Dbt got;
  if (db.get(NULL, &key, &got, 0) != 0 || strcmp(v, (const char *)got.get_data()) != 0) {
    std::cout << "get did not return what was put" << std::endl;
    return 1;
  }
  db.close(0);

  int major, minor, patch;
  db_version(&major, &minor, &patch);
  std::cout << "libdb " << major << "." << minor << "." << patch << " round-tripped" << std::endl;
  return 0;
}
EOT
        extname = "cpp"
      }
      run = "c++ $FIXTURE -o roundtrip -I{{prefix}}/include -L{{prefix}}/lib -Wl,-rpath,{{prefix}}/lib -ldb_cxx"
    },
    "./roundtrip | grep {{version.raw}}",
    "test -f test.db",
    # And the file the library wrote is a valid database to the TOOL.
    "db_verify test.db",
  ]
}

provenance {
  read = [
    "dist/aclocal/options.m4",  # :143-155 compat185/cxx default no; :205-217 dump185/java no; :266-288 stl/tcl/test no; :459-474 --with-cryptography; :476-494 --with-repmgr-ssl defaults to \"default\"; NO --enable-sql anywhere
    "dist/aclocal/tls.m4",      # :20-29 the C++ probe that uses NULL with no include
    "dist/configure.ac",        # :807-808 db_dump185 only under dump185; :872-941 replication manager SSL probe, -lssl -lcrypto, :908-910 the CPPFLAGS/LDFLAGS message
    "dist/Makefile.in",         # :894-898 UTIL_PROGS; :1279-1291 install_utilities; :1302-1312 DOCLIST and install_docs
    "dist/configure",           # three occurrences of \"sql\", none an option; --enable-compat185/cxx/stl/dbm are all handled
    "RELEASE",                  # 18.1.40, May 29 2020, DB_VERSION_STRING
    "README",
    "LICENSE",                  # :7-12 AGPL v3 ; :676 onwards third party BSD notices
  ]

  consulted = [
    "homebrew-core Formula/b/berkeley-db.rb",                                                   # facts only: the sha256 witness, the serial build, the DOCLIST=license trick
    "pkgxdev/pantry projects/oracle.com/berkeley-db/package.yml",                               # facts only: the flag list this recipe corrects
    "https://www.oracle.com/database/technologies/related/berkeleydb-downloads.html",          # the zip's SHA256 and the changelog link
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the C++ probe finding was
measured by compiling the snippet, the rest is read from the files above.

⚠ NOT DONE, on purpose: homebrew-core carries a patch,
Patches/libtool/configure-pre-0.4.2.418-big_sur.diff, against `-flat_namespace`
on macOS Big Sur and later (dist/aclocal/libtool.m4 predates it). It is a
third-party patch to a generated libtool, so it is NOT reproduced here; if the
darwin build produces a flat-namespace dylib, that is the thing to look at, and
the recipe-level `platforms` key is where a darwin refusal would go.

⚠ THE LICENCE IS A READ OF A SINGLE FILE. LICENSE names AGPL v3 for the
product and lists third party BSD notices below it; the per-file headers were
not audited, so BSD parts are not itemised in the SPDX expression.

⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED, with the second fetch and
homebrew-core as the witnesses.
EOT
}
