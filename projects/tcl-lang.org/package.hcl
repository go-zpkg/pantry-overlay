# tcl-lang.org — Tcl, the core only: the interpreter, libtcl, the bundled
# packages Tcl itself distributes under pkgs/, and the headers an extension
# needs. This used to be one recipe that built SIX packages (Tcl, Tk, critcl,
# tcllib, tcltls, itk); go-zpkg/recipes#122 split it. Tk is `tcl-lang.org/tk`;
# critcl, tcllib, tcltls and itk are recipes of their own.
#
# ⛔ WRITTEN FROM TCL'S OWN FILES (go-zpkg/packages#431), at 9.0.4 and 8.6.18,
# both read out of the published source tarballs, and BOTH BUILT AND INSTALLED
# in a scratch directory on darwin/arm64 (not by the factory).
#
# ⭐ WHICH VERSIONS, AND WHY BOTH. The recipe it replaces pinned `=8.6.16` for
# python with the note "9.0.2 introduced a build issue on darwin". Decided from
# the sources, not from that note:
#
#   * CPython 3.15.2 ITSELF SHIPS 9.0.4: PCbuild/get_externals.bat:60 and :83
#     (`tcl-9.0.4.0`, `tcltk-9.0.4.0`) and Mac/BuildScript/build-installer.py:
#     267 (`tcl_tk_ver='9.0.4'`, built with `--enable-aqua --enable-shared
#     --enable-threads`). Modules/_tkinter.c carries both arms
#     (`#if TK_MAJOR_VERSION >= 9`, Tcl_Size), and configure.ac:4607 asks
#     `tcl >= 8.5.12 tk >= 8.5.12`, which 9.0.4 satisfies.
#   * The darwin failure is real and is NOT specific to 9.0.2: see the build
#     block. 9.0.4 builds and installs on darwin with the staging below.
#   * 8.6.18 STAYS, because two consumers outside this tree say `^8`:
#     python-pillow.org and tcl-lang.org/expect both depend on `tcl.tk/tcl: ^8`,
#     the duplicate core Tcl this recipe replaces (step 5 of #122). Dropping the
#     8.6 line here would make that retirement break them.
#
# ⛔ SQLITE3_ANALYZER, SETTLED (the contradiction filed in #122): the monolith
# DELETED `bin/sqlite3_analyzer` and `tcl.tk/tcl` DECLARES it. `tcl.tk/tcl` is
# right. pkgs/sqlite3.53.0/Makefile.in:452, in `install-bin-binaries`, is an
# unconditional `$(INSTALL_PROGRAM) $(srcdir)/compat/sqlite3/spaceanal.tcl
# "$(DESTDIR)$(bindir)/sqlite3_analyzer"` — no `test -f`, no switch — and
# Makefile.in:2094-2109 `install-packages` runs every pkgs/*/ `make install`.
# Measured: both scratch installs contain bin/sqlite3_analyzer. It is also
# part of what `make install` means, so deleting it was removing Tcl's own
# output.
# ⚠ AND IT NEEDS `tclsh` ON PATH: its first lines are
# `exec tclsh "$0" ${1+"$@"}`. Tcl installs only `tclsh<major.minor>`, so this
# recipe makes the `tclsh` link, and the test RUNS the analyzer.

summary = "Tcl: the Tool Command Language interpreter, libtcl and the packages Tcl bundles"

# license.terms:1-4 — "This software is copyrighted by the Regents of the
# University of California, Sun Microsystems, Inc., Scriptics Corporation,
# ActiveState Corporation and other parties. … The following terms apply to all
# files": the Tcl/Tk licence, SPDX `TCL`.
license = "TCL"

dependencies = {
  # unix/configure.ac:156-169 (9.0.4): zlib is AUTO-DETECTED — `zlib.h`,
  # `gz_header`, `deflateSetHeader` — and a miss is SILENT: it falls to
  # `ZLIB_OBJS` and TCL_WITH_INTERNAL_ZLIB, Tcl's vendored copy in compat/zlib.
  # There is no switch to force the system one, so the dependency is declared
  # and the TEST reads the outcome off tclConfig.sh (TCL_LIBS carries `-lz`
  # only when the search found it) and off tcl.pc.
  # unix/tcl.pc.in:13 states the floor: `zlib >= 1.2.3`.
  "zlib.net" = "^1.3"
}

# Enumerate where the tarball actually LIVES: `distributable` downloads from
# SourceForge, and tcl-lang.org's own download page lists only what upstream
# currently recommends (go-zpkg/recipes#47). Kept verbatim.
#
# ⚠ The listing also shows pre-releases (9.0.5 is `rc0`, 9.1.0 is not a
# release). They enumerate and cannot build: `sha256` below is a map, and a
# version absent from it is REFUSED rather than fetched unverified.
versions {
  match = "/Tcl\\/\\d+\\.\\d+\\.\\d+\\//"
  strip = [
    "/^Tcl\\//",
    "/\\/$/",
  ]
  url = "https://sourceforge.net/projects/tcl/files/Tcl/"

  # ⛔ MEASURED: `zpkb versions` resolves 9.1.0 and 9.0.5 as the NEWEST, so a
  # consumer asking `^9` would be handed a version this recipe refuses to build
  # (it is absent from `sha256`). 9.0.5 is `rc0` and 9.1.0 is not a release
  # (SourceForge folders 9.0.5 and 9.1.0 hold `tk9.0.5rc0-src.tar.gz` and
  # pre-release files). Excluded until a release is pinned.
  ignore = ["/^9\\.0\\.5$/", "/^9\\.1\\./"]
}

distributable {
  url              = "https://downloads.sourceforge.net/project/tcl/Tcl/{{version.raw}}/tcl{{version.raw}}-src.tar.gz"
  strip-components = 1

  # 9.0.4: 11866337 bytes; 8.6.18: 11816279 bytes. Recorded with the builder's
  # own fetcher (`zpkb sourcepin --version <v> <url>`, zpkb v0.89.0) and
  # confirmed by a second, independent fetch-and-hash (curl + shasum).
  #
  # ⭐ 9.0.4's DIGEST IS ALSO THE ONE CPYTHON'S OWN REPOSITORY PINS: build-
  # installer.py:268 `tcl_checksum='d0aed492…7551ea'`, identical byte for byte.
  # A third source, controlled by a project that is not Tcl's.
  # ⚠ 8.6.18 HAS ONLY THE TWO FETCHES: tcl-lang.org publishes no checksum and no
  # signature for either release (the download page and the software page carry
  # neither), so there is no signature to verify and no project-stated digest.
  sha256 = {
    "9.0.4"  = "d0aed49230bc02a65c1e0229e65f34590a4b037ec40d546f32573b467f7551ea"
    "8.6.18" = "14f9af32b1767ff718477a8f974ad03c34341097e6b43f4ce54644ee974e268e"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ NO `--includedir=…/include/tcl-tk`, which the monolith passed. It put
      # Tcl's headers where only an -I from tcl.pc finds them, and existed to
      # let Tcl and Tk share one directory. With Tk a recipe of its own the
      # default `include/` is the one every extension build expects, and
      # tcl.pc's `Cflags: -I${includedir}` (unix/tcl.pc.in:16) follows it.

      # ⛔ THE NINE SWITCHES THE CONFIGURE HELP LISTS THAT CHANGE THE ARTIFACT
      # (`./configure --help`, 9.0.4 and 8.6.18, read, not remembered), each
      # either named or refused:
      #
      #   --enable-shared      default ON (tcl.m4:510). Restated: python links
      #                        libtcl, and a static Tcl cannot load extensions.
      "--enable-shared",
      #   --enable-load        default ON (tcl.m4:1741). Restated: `load` and
      #                        every binary extension (tcltls, itk, critcl's
      #                        output) depend on it.
      "--enable-load",
      #   --enable-symbols     default OFF; debug symbols are not wanted.
      #   --enable-dtrace      default OFF (configure.ac:662); DTrace is not a
      #                        dependency of this tree.
      #   --enable-framework   default OFF (tcl.m4:545): a macOS .framework
      #                        bundle is a different layout, not the prefix one
      #                        pkg-config describes.
      #   --enable-corefoundation default ON (tcl.m4:1454): darwin uses
      #                        CoreFoundation for locale and encoding; the
      #                        build links `-framework CoreFoundation`
      #                        (tclConfig.sh TCL_LIBS, read off the scratch
      #                        install). Kept at its default.
      #   --enable-langinfo    default ON (tcl.m4:662): system encoding from
      #                        nl_langinfo. Kept.
      #   --enable-dll-unloading default ON (9.0 configure.ac:598). Kept.
      #   --enable-zipfs       9.0 only, default ON (configure.ac:815): tclsh is
      #                        built with its library zip APPENDED to the
      #                        executable (Makefile.in:837). Kept, and it is why
      #                        nothing may rewrite the binary after linking —
      #                        see the build block.
      #   --disable-rpath      default ON; Kept: libtcl is found beside the
      #                        executable by rpath.
      #
      # ⛔ REFUSED, WITH THE REASON: `--enable-64bit` (default off, tcl.m4:887).
      # It selects a 64-bit compiler flag set on Solaris, AIX, HP-UX and
      # universal darwin; tcl.m4:1725 turns `do64bit=yes` with no matching
      # platform case into an ERROR. On the 64-bit linux and darwin targets this
      # recipe builds, the default compiler is already 64-bit, and the test
      # asserts `tcl_platform(pointerSize)` and `wordSize` equal 8 off the
      # installed tclsh rather than passing a flag that is a no-op there.
      #
      # ⛔ REFUSED: `--enable-threads` (8.6 only; 9.0 has no such option and
      # warns on it). 8.6 defaults to ON (the 8.6.18 help says "default: on");
      # the test asserts `tcl_platform(threaded)` for 8.6.

      # ⛔ AUTO-DETECTED, NAMED: libtommath (9.0.4 configure.ac:175-195).
      # `--with-system-libtommath` is "true if available, false otherwise", so a
      # build host that happens to have tommath.h changes the artifact, and
      # tcl.pc grows `Requires.private: libtommath >= 1.2.0`. Neither this tree
      # nor the pantry has a libtommath recipe, so the system copy cannot be a
      # declared dependency: the vendored libtommath/ in Tcl's own tarball (the
      # copy Tcl's test-suite runs against) is chosen BY NAME, which
      # makes the artifact the same on every host. The 8.6 line has no such
      # switch (its help lacks it) and always uses its vendored copy, so the
      # flag is appended in the script for 9.x only — an option the configure
      # does not know is the mistyped-identifier defect of go-zpkg/pantry-
      # overlay#120, and autoconf only WARNS about it.
      #
      # ⛔ AUTO-DETECTED, NAMED: timezone data (configure.ac:613-656).
      # `--with-tzdata` default is autodetect: if /usr/share/zoneinfo has UTC or
      # GMT, Tcl installs NONE and relies on the OS; otherwise it installs its
      # own. A builder with and a builder without zoneinfo would produce
      # different artifacts. `yes` makes Tcl ship its own and the artifact
      # independent of the host (library/clock.tcl searches the installed copy
      # first); the test reads a zone off the installed tclsh.
      "--with-tzdata=yes",
    ]
  }

  # ⛔⛔ THE STAGING BELOW IS NOT DECORATION — IT IS THE "9.0 BUILD ISSUE ON
  # DARWIN", REPRODUCED. A single `make` of 9.0.4 on darwin/arm64 fails with
  #
  #   configure: error: cannot find a usable native Tcl 9 tclsh.
  #   Either set TCLSH_NATIVE or use configure with --disable-zipfs
  #   make: *** [configure-packages] Error 1
  #
  # Makefile.in:2053-2077 `configure-packages` configures every pkgs/* with the
  # tclsh just built, and on darwin the built tclsh's install_name is the FINAL
  # `{{prefix}}/lib/libtcl9.0.dylib` ("Library not loaded", measured), which
  # does not exist yet. So it is installed FIRST: `binaries` and `libraries`,
  # `install-binaries install-libraries`, and only then the packages. The
  # sequence builds and installs 9.0.4 cleanly and is harmless on 8.6.
  #
  # ⚠ AND IT IS WHY NOTHING MAY REWRITE tclsh AFTERWARDS. The tclsh of 9.x has
  # its library zip appended past the end of the Mach-O (Makefile.in:831-840);
  # install_name_tool, codesign or strip over it breaks the archive (the
  # pantry's `skip: fix-machos` and "fix-machos breaks tclsh" comments are this).
  # The schema's `build.skip` lists fix-machos among the fix-up steps (package.
  # schema.json:45), so it is skipped; the prefix is final, so the absolute
  # install_name already points at the installed libtcl. The test runs the
  # INSTALLED tclsh and reads `info library`, so a rewrite would be caught.
  skip = ["fix-machos"]

  script = [
    # (Each line is its own shell, as in the gcc recipe, hence `cd unix &&`.)
    "cd unix && case \"{{version.major}}\" in 9) X=--without-system-libtommath ;; *) X= ;; esac && ./configure $ARGS $X",
    "cd unix && make --jobs {{ hw.concurrency }} binaries libraries",
    "cd unix && make install-binaries install-libraries",
    "cd unix && make --jobs {{ hw.concurrency }}",
    "cd unix && make install",

    # Tk's `--with-tcl` and extension builds read tclInt.h; Tcl installs the
    # private headers only on request (Makefile.in:1203).
    "cd unix && make install-private-headers",

    # sqlite3_analyzer execs `tclsh`; Tcl installs only tclsh<major.minor>.
    "ln -s tclsh{{version.marketing}} \"{{prefix}}/bin/tclsh\"",
  ]
}

# Read from the install rules, not guessed:
#   Makefile.in:1024-1025  tclsh → $(BIN_INSTALL_DIR)/tclsh$(VERSION)
#   pkgs/sqlite3.53.0/Makefile.in:452  sqlite3_analyzer, unconditional
# ⚠ `tclsh<major.minor>` is listed through the template, as the pantry did, so
# `provides` stays right for the next line.
provides = [
  "bin/tclsh{{version.marketing}}",
  "bin/tclsh",
  "bin/sqlite3_analyzer",
]

test {
  script = [
    "test -x \"{{prefix}}/bin/tclsh{{version.marketing}}\"",
    "test -f \"{{prefix}}/include/tcl.h\"",
    "test -f \"{{prefix}}/include/tclInt.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/tcl.pc\"",

    # tclConfig.sh TCL_LIBS names `-lz` only when configure.ac's zlib search
    # found the system library (the SILENT-FALLBACK census above).
    "grep -q -e '-lz' \"{{prefix}}/lib/tclConfig.sh\"",
    "grep -q '^Requires.private:.* zlib' \"{{prefix}}/lib/pkgconfig/tcl.pc\"",

    {
      run = <<EOT
set -eu
cat > "$PWD/check.tcl" <<'TCL'
# the interpreter is the one asked for, and 64-bit
set want "{{version.raw}}"
if {[info patchlevel] ne $want} { puts stderr "patchlevel [info patchlevel] != $want"; exit 1 }
if {$tcl_platform(pointerSize) != 8 || $tcl_platform(wordSize) != 8} { puts stderr "not 64-bit"; exit 1 }
if {[string match 8.* $want] && !$tcl_platform(threaded)} { puts stderr "8.6 without threads"; exit 1 }
# bignums: vendored libtommath
if {[expr {2**100}] ne "1267650600228229401496703205376"} { puts stderr "bignum"; exit 1 }
# zlib, and the timezone data we asked Tcl to carry
if {[zlib crc32 hello] != 907060870} { puts stderr "zlib"; exit 1 }
if {[clock format 0 -timezone :Europe/Paris -format %H] ne "01"} { puts stderr "tzdata"; exit 1 }
# every package Tcl bundles under pkgs/
foreach p {sqlite3 Thread Itcl tdbc tdbc::sqlite3 tcltest} {
  if {[catch {package require $p} v]} { puts stderr "package $p: $v"; exit 1 }
}
sqlite3 db :memory:
db eval {create table t(x); insert into t values (41)}
if {[db eval {select x+1 from t}] != 42} { puts stderr "sqlite3"; exit 1 }
puts "tcl [info patchlevel] ok, library [info library]"
TCL
"{{prefix}}/bin/tclsh" "$PWD/check.tcl"
EOT
    },

    # ⛔ THE CONTRADICTION'S WITNESS: the analyzer is installed AND RUNS, which
    # also proves `bin/tclsh` is on its path. A sqlite database file is made
    # by the bundled sqlite3 package.
    {
      run = <<EOT
set -eu
cat > "$PWD/mkdb.tcl" <<'TCL'
package require sqlite3
sqlite3 db "$::env(PWD)/probe.db"
db eval {create table t(x); insert into t values (1)}
db close
TCL
"{{prefix}}/bin/tclsh" "$PWD/mkdb.tcl"
PATH="{{prefix}}/bin:$PATH" "{{prefix}}/bin/sqlite3_analyzer" "$PWD/probe.db" | grep -q 'Page size'
EOT
    },

    # What python links: libtcl found through pkg-config, at the version built.
    {
      run = <<EOT
set -eu
PKG_CONFIG_PATH="{{prefix}}/lib/pkgconfig" pkg-config --exact-version={{version.raw}} tcl
EOT
    },
  ]
}

provenance {
  read = [
    "unix/configure.ac",   # 9.0.4 :156-169 zlib auto-detect and silent vendored fallback; :175-195 --with-system-libtommath; :598 dll-unloading; :613-656 --with-tzdata; :662 dtrace; :815 zipfs
    "unix/tcl.m4",         # :510 shared; :545 framework; :662 langinfo; :887 64bit and :1725 its error; :1454 corefoundation; :1741 load
    "unix/Makefile.in",    # 9.0.4 :831-840 zip appended to tclsh; :1014-1030 install-binaries; :1203 install-private-headers; :2040-2109 bundled-package configure, build and install
    "unix/tcl.pc.in",      # :13 `zlib >= 1.2.3`; :14-16 Libs, Cflags
    "pkgs/sqlite3.53.0/Makefile.in",  # :452 the unconditional sqlite3_analyzer install
    "pkgs/sqlite3.53.0/configure.ac", # :117-128 --with-system-sqlite, default no: the bundled SQLite is what is built
    "pkgs/tdbcmysql1.1.13/generic/fakemysql.h", # the tdbc drivers carry fake client headers (fakepq.h, fakesql.h likewise): no build-time detection
    "pkgs/package.list.txt",
    "license.terms",
    "Mac/BuildScript/build-installer.py (CPython 3.15.2)", # :258-310 Tcl/Tk 9.0.4, its checksums, --enable-aqua
    "PCbuild/get_externals.bat (CPython 3.15.2)",           # :60, :83
    "https://www.tcl-lang.org/software/tcltk/download.html", # lists 9.0.4 and 8.6.18; carries no checksum and no signature
  ]

  consulted = [
    # Read for facts only: the dependency list, the `tclsh` link, the two
    # bundled-sqlite contradictions. Nothing copied (go-zpkg/packages#431).
    "pkgxdev/pantry projects/tcl-lang.org/package.yml",
    "pkgxdev/pantry projects/tcl.tk/tcl/package.yml",
  ]

  note = <<EOT
⛔ BUILT HERE, NOT BY THE FACTORY. Both versions were configured, built and
installed on darwin/arm64 in a scratch directory with exactly the build block's
commands and switches (both versions through the staging), and the INSTALLED
tclsh was run against every check of the test block, all passing: patchlevel,
64-bit, sqlite3 3.53.0, Thread, Itcl 4.3.x, tdbc and tdbc::sqlite3 1.1.13,
tcltest, a bignum, zlib, tzdata, `-lz` in tclConfig.sh, the tcl.pc version,
sqlite3_analyzer reading a database (with tclsh on its path), and the zipfs
library for 9.0.4. Not run: linux, and the recipe text as the factory executes
it (the shell snippets were run by hand).

⚠ THE BUNDLED tdbc DRIVERS FOR MYSQL, ODBC AND POSTGRESQL ARE BUILT AND
INSTALLED (pkgs/ holds them and Makefile.in:2094 installs every directory) and
they NEED NO LIBRARY AT BUILD TIME — they carry fake client headers and a stub
table and bind the vendor library at run time. So nothing is declared for them,
and `package require tdbc::mysql` will fail at run time on a host without
libmysqlclient. That is upstream's design, named so it is not mistaken for a
missing dependency.

⚠ ONE UNPINNED-SIGNATURE FACT: tcl-lang.org signs nothing. 9.0.4's digest has a
second project's pin (CPython); 8.6.18's has only two fetches.
EOT
}
