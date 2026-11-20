# tcl-lang.org/tk — Tk, the Tcl GUI toolkit, built against the core Tcl of
# `tcl-lang.org` (go-zpkg/recipes#122 step 3). It is what python's `_tkinter`
# links: CPython 3.15.2 configure.ac:4607 asks pkg-config for
# `tcl >= 8.5.12 tk >= 8.5.12`, and tk.pc is installed by this recipe.
#
# ⛔ WRITTEN FROM TK 9.0.4'S AND 8.6.18'S OWN FILES (go-zpkg/packages#431), read
# out of the published source tarballs. 9.0.4 was BUILT AND INSTALLED in a
# scratch directory on darwin/arm64 twice — as an X11 Tk against XQuartz's
# libraries (Xft and XScreenSaver both found and compiled in) and as an Aqua Tk.
# 8.6.18 was built on darwin/arm64 (Aqua) and on linux/aarch64 (a debian:trixie
# container, X11 with Xft and XScreenSaver; see provenance.note). NOT built by
# the factory.
#
# ⭐ WHICH VERSIONS, AND WHY BOTH: 9.0.4, the line CPython 3.15.2 itself ships
# (see tcl-lang.org), AND 8.6.18, matching the Tcl 8.6.18 that recipe pins.
# tcl-lang.org/expect asks for `tcl-lang.org ^8`, and its Tk scripts
# (`tkpasswd`, `tknewsbiff`: `package require Tk` under `tclsh`) need a Tk that
# loads into Tcl 8.6, which Tk 9 does not (tcl-lang.org/expect's header: Tk 9's
# pkgIndex refuses an 8.x Tcl; and unix/configure.ac of 9.0.4 says "requires
# Tcl 9.0+", :40-41).
# The two lines differ in three ways this recipe keeps apart:
#
#   * the Tcl it needs: `^9` for 9.x, `^8` for 8.x, as a version scope in
#     `dependencies` (a scope is a flat map, build.go reduceDepMap, so it can
#     carry a project but not a platform);
#   * libcups: Tk 9 only. unix/configure.in of 8.6.18 has no `cups` at all
#     (`grep -n cups` finds nothing) and its `--help` lists no
#     `--enable-libcups`, so the switch is passed for 9 and not for 8, and the
#     test asserts that libtk8.6 does NOT link libcups. The cups dependency
#     below is shared by both lines for the reason stated there;
#   * the library name and the zipfs: Tk 9 is libtcl9tk9.0 with its script
#     library embedded as a zip; Tk 8.6 is libtk8.6 with lib/tk8.6 beside it.
#
# Xft and XScreenSaver are in 8.6.18 exactly as in 9.0.4: unix/configure.in
# :456-535 (`--enable-xft` default "default", a miss is silent unless
# `yes`, and even `yes` only WARNS at :516-518) and :597-639 (`--enable-xss`
# default yes, HAVE_XSS only when header AND library are found). Both are named
# below for both lines.
#
# ⭐ THE FULL FUNCTION THE OWNER ASKED FOR, on X11 targets (linux): antialiased
# fonts through Xft and the activity timer through XScreenSaver, each NAMED so
# a miss is fatal-by-test and not a warning:
#
#   Xft  — unix/configure.ac:345-424. `--enable-xft` defaults to "default", and
#          a probe that fails sets enable_xft=no and, unless it was passed
#          `yes`, says NOTHING; even with `yes` it only WARNS (:405-407) and
#          falls back to core X fonts (tkUnixFont.o instead of tkUnixRFont.o,
#          :416-419). The probe is `xft-config`, then
#          `pkg-config --cflags/--libs xft fontconfig` (:359-364), a header
#          compile (:373) and a link of XftFontOpen (:385). So this recipe passes
#          `--enable-xft`, declares x.org/xft and freedesktop.org/fontconfig, and
#          the TEST reads `-DHAVE_XFT=1` out of the installed tkConfig.sh.
#   XSS  — :481-523. `--enable-xss` defaults YES and a miss is silent (:518
#          defines HAVE_XSS only if header AND library were found). The library
#          is libXss (:505), from x.org/xscrnsaver, the header
#          X11/extensions/scrnsaver.h (:497). The test reads `-DHAVE_XSS=1`.
#
# ⛔ DARWIN IS AQUA, AND THAT IS NOT A DOWNGRADE OF THOSE TWO. Both blocks sit
# inside `if test $tk_aqua = no` (:345, :481): on darwin they do not exist. The
# default there is X11 (`--enable-aqua` default no, :210), which would need an
# X server; CPython's own macOS installer builds Tk with `--enable-aqua`
# (Mac/BuildScript/build-installer.py:300), and Aqua is the toolkit a Mac user
# has a display for. So darwin passes `--enable-aqua` and takes no X library.
#
#   CUPS — :427-469, 9.0 only, default on, inside the same `tk_aqua = no`
#          fence. It is auto-detected by running a bare `cups-config` (:441) and
#          then compiling `cups/cups.h` (:458-462), and a miss sets found_cups=no
#          and says nothing — even with `--enable-libcups` (:432-435 only
#          distinguishes "no"). The header is looked for through CPPFLAGS only
#          (CUPS_CFLAGS is just -DHAVE_CUPS, :448) and the library through
#          LDFLAGS (`cups-config --libs` prints only -lcups), so this recipe puts
#          `cups-config` on PATH for configure and passes -I and -L of
#          openprinting.github.io/cups. tkConfig.sh does not record CUPS (read off
#          the scratch install), so the TEST reads the outcome off libtcl9tk9.0:
#          it must name libcups and import the cups calls of unix/tkUnixPrint.c.
#          What it gives: Tk 9's `tk print` to a CUPS queue of the host's
#          scheduler (see openprinting.github.io/cups for where libcups looks).
#
# ⛔ THE TWO MACPORTS PATCHES THE MONOLITH FETCHED WITH curl ARE NOT NEEDED.
# They were applied only `if: <8.6.14` ("fixed in 8.6.14", the pantry's own
# words). In 9.0.4 the KVO crash fix is visibly present:
# macosx/tkMacOSXWm.c:1390 `[preferences removeObserver:deadNSWindow.contentView`
# (8.6.18 has it at :1095). The ThemeChanged fix could not be located by name
# in either tree, so that half rests on the pantry's statement and on the
# build of Aqua Tk 9.0.4 above, not on a grep.

summary = "Tk: the Tcl graphical user interface toolkit (X11 with Xft and XScreenSaver, Aqua on darwin)"

# license.terms, shared with Tcl: the Tcl/Tk licence, SPDX `TCL`.
license = "TCL"

platforms = ["linux", "darwin"]

dependencies = {
  # Tk finds tclConfig.sh through --with-tcl, and the two lines need different
  # Tcls. 8.6: tk.pc.in `Requires: tcl >= 8.6`. 9.x: unix/configure.ac:40-41
  # "requires Tcl 9.0+"; tk.pc `Requires: tcl >= 9.0`, read off the scratch
  # install. The scope overrides the plain key for 9.x (reduceDepMap: plain
  # keys, then platform, then version scope), and a closure that does not know
  # the version takes the scope's, so the walks that precede resolution see the
  # newest line, 9.
  "tcl-lang.org" = "^8"
  ">=9"          = { "tcl-lang.org" = "^9" }

  linux = {
    # SC_PATH_X (unix/tcl.m4:1963-2016) finds libX11 and the headers through
    # --x-includes/--x-libraries; Xlib.h includes X11/X.h from xorgproto.
    "x.org/x11"      = "^1"
    "x.org/protocol" = "*"
    # XScreenSaverQueryInfo is in libXss and needs libXext (:500-515).
    "x.org/xext"       = "^1"
    "x.org/xscrnsaver" = "*"
    # :359-364 the Xft probe, and Xft's own requirements.
    "x.org/xft"                  = "^2"
    "x.org/xrender"              = "^0.9"
    "freedesktop.org/fontconfig" = "^2"
    "freetype.org"               = "^2"

    # unix/configure.ac:427-469 (9.x only), see the header. Darwin is Aqua and
    # never uses it. SHARED BY BOTH LINES, STATED: a platform sub-map cannot
    # carry a version scope (reduceDepMap's mergeSub copies keys flat), so 8.6
    # on linux declares a dependency it does not link; the test asserts that
    # libtk8.6 names no libcups, and 8.6 is not told about it (no switch).
    "openprinting.github.io/cups" = "^2.4"
  }

  "zlib.net" = "^1.3"
}

# Same SourceForge listing as tcl-lang.org: that is where the tarball lives.
versions {
  match = "/Tcl\\/\\d+\\.\\d+\\.\\d+\\//"
  strip = [
    "/^Tcl\\//",
    "/\\/$/",
  ]
  url = "https://sourceforge.net/projects/tcl/files/Tcl/"

  # As in tcl-lang.org: 9.0.5 is rc0 and 9.1.0 is not a release, and a version
  # absent from `sha256` is refused, so `^9` must not resolve to them. 8.x is
  # no longer ignored: 8.6.18 is pinned below, and a version absent from
  # `sha256` is refused whichever line it is on.
  ignore = ["/^9\\.0\\.5$/", "/^9\\.1\\./"]
}

distributable {
  url              = "https://downloads.sourceforge.net/project/tcl/Tcl/{{version.raw}}/tk{{version.raw}}-src.tar.gz"
  strip-components = 1

  # 9.0.4: 4613019 bytes; 8.6.18: 4600288 bytes. Each recorded with the
  # builder's own fetcher (`zpkb sourcepin --version <v> <url>`; zpkb v0.89.0 for
  # 9.0.4, v0.92.0 for 8.6.18) and confirmed by a second, independent
  # fetch-and-hash (curl + shasum; for 8.6.18 from the project's own
  # `…/Tcl/8.6.18/tk8.6.18-src.tar.gz/download` redirect as well as the
  # downloads.sourceforge.net URL above).
  #
  # ⭐ 9.0.4's DIGEST IS IDENTICAL TO THE ONE CPYTHON'S OWN REPOSITORY PINS for
  # Tk 9.0.4: Mac/BuildScript/build-installer.py:270 `tk_checksum='d7a146d2…01dbb4'`.
  # ⚠ 8.6.18 HAS ONLY THE TWO FETCHES: tcl-lang.org publishes no checksum and no
  # signature (the download page carries no digest, and the SourceForge folder of
  # 8.6.18 lists archives, a README and the release notes, with no signature or
  # checksum file), so nothing project-stated exists to verify against.
  sha256 = {
    "9.0.4"  = "d7a146d2917eb8b5cc95276dbf0e3d03c7464d2b19c1675357857c989301dbb4"
    "8.6.18" = "95cd528a80f5e4bdb557af9b14a7197d6860793a3894e25e7c9fad2ed05d4c3c"
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
      "--with-tcl={{deps.tcl-lang.org.prefix}}/lib",

      # ⛔ THE SWITCHES THE HELP LISTS, EACH NAMED OR REFUSED (`./configure
      # --help`, 9.0.4 and 8.6.18, read):
      #   --enable-shared     default on; python links libtcl9tk9.0 (libtk8.6).
      "--enable-shared",
      #   --enable-load       default on (both lines); Tk is itself loaded with
      #                       `load`.
      "--enable-load",
      #   --enable-zipfs      9.0 only (the 8.6.18 help has no such switch),
      #                       default on (ZIPFS_BUILD=1 in tkConfig.sh): the Tk
      #                       script library is embedded in libtcl9tk9.0, so
      #                       `package require Tk` needs no lib/tk9.0 lookup.
      #   --enable-threads    8.6 only (the 9.0 configure has no such switch),
      #                       default on, and it must match the Tcl 8.6.18 of
      #                       tcl-lang.org, which is threaded. Kept.
      #   --enable-64bit-vis  8.6 only, Sparc VIS. Default off. Kept.
      #   --enable-corefoundation default on, darwin only. Kept.
      #   --enable-symbols    default off. --enable-framework default off.
      #   --enable-man-*      documentation layout only.
      #   --enable-64bit      REFUSED for the reason given in tcl-lang.org: a
      #                       platform-case flag selector that is a no-op on
      #                       64-bit linux and darwin.
      #   --with-encoding     default utf-8. Kept.
      #   --with-x            default on where X is used; passed through
      #                       --x-includes/--x-libraries below.
      #   --enable-libcups    9.0 only. NAMED on X11 targets in the script below
      #                       (see the header; the 8.6.18 configure does not
      #                       know it, and an option a configure does not know
      #                       is only WARNED about by autoconf); on darwin
      #                       (Aqua) the block does not exist.
    ]

    # X11 targets: the two NAMED detections, and where X lives. configure.ac's
    # Xft probe uses pkg-config, which finds the declared recipes; the XSS
    # header and library checks (:497-515) and SC_PATH_X do NOT, so their
    # directories are passed.
    linux = {
      ARGS = [
        "--enable-xft",
        "--enable-xss",
        "--x-includes={{deps.x.org/x11.prefix}}/include",
        "--x-libraries={{deps.x.org/x11.prefix}}/lib",
      ]
      CPPFLAGS = "-I{{deps.x.org/protocol.prefix}}/include -I{{deps.x.org/xext.prefix}}/include -I{{deps.x.org/xscrnsaver.prefix}}/include -I{{deps.openprinting.github.io/cups.prefix}}/include"
      LDFLAGS  = "-L{{deps.x.org/xext.prefix}}/lib -L{{deps.x.org/xscrnsaver.prefix}}/lib -L{{deps.openprinting.github.io/cups.prefix}}/lib"

      # Where configure finds the bare `cups-config` (:441).
      CUPSBIN = "{{deps.openprinting.github.io/cups.prefix}}/bin"
    }

    # darwin: Aqua (see the header). --enable-xft/--enable-xss would be inert
    # there and are not passed.
    darwin = {
      ARGS = [
        "--enable-aqua",
      ]
    }
  }

  # Makefile.in:647-650 and :687-690 append the Tk script library as a zip to
  # libtcl9tk9.0 and to wish (zipfs, ZIPFS_BUILD); a Mach-O rewrite over that
  # data breaks the archive, exactly as for tclsh (see tcl-lang.org).
  skip = ["fix-machos"]

  script = [
    # --enable-libcups only where Tk knows it (9.x) and where there is an X11
    # target to name it on (CUPSBIN is set on linux only); see the header.
    "cd unix && case \"{{version.major}}:$${CUPSBIN:-}\" in 9:?*) X=--enable-libcups ;; *) X= ;; esac && PATH=\"$${CUPSBIN:-/nonexistent}:$PATH\" ./configure $ARGS $X",
    "cd unix && make --jobs {{ hw.concurrency }}",
    "cd unix && make install",

    # Extension builds (itk) read tkInt.h; installed only on request.
    "cd unix && make install-private-headers",

    "ln -s wish{{version.marketing}} \"{{prefix}}/bin/wish\"",
  ]
}

provides = [
  "bin/wish{{version.marketing}}",
  "bin/wish",
]

test {
  script = [
    "test -x \"{{prefix}}/bin/wish{{version.marketing}}\"",
    "test -f \"{{prefix}}/include/tk.h\"",
    "test -f \"{{prefix}}/include/tkInt.h\"",
    "test -f \"{{prefix}}/lib/tkConfig.sh\"",
    "test -f \"{{prefix}}/lib/pkgconfig/tk.pc\"",

    # python's query 1 (configure.ac:4607) needs tk.pc at the version built.
    {
      run = <<EOT
set -eu
PKG_CONFIG_PATH="{{prefix}}/lib/pkgconfig:{{deps.tcl-lang.org.prefix}}/lib/pkgconfig" pkg-config --exact-version={{version.raw}} tk
EOT
    },

    # ⛔⛔ THE WINDOWING SYSTEM AND THE TWO NAMED DETECTIONS, READ OFF THE
    # INSTALLED tkConfig.sh (TK_DEFS records the HAVE_* the build ended with) AND
    # tk.pc. A probe that missed would have printed a warning and built a Tk
    # with core X fonts and no activity timer; this is where that fails.
    {
      run = <<EOT
set -eu
cfg="{{prefix}}/lib/tkConfig.sh"
pc="{{prefix}}/lib/pkgconfig/tk.pc"
case "$(uname -s)" in
  Darwin)
    grep -q -e '-DMAC_OSX_TK=1' "$cfg" || { echo "darwin Tk is not Aqua" >&2; exit 1; }
    ;;
  *)
    grep -q -e '-DHAVE_XFT=1' "$cfg" || { echo "Tk was built WITHOUT Xft (core X fonts only)" >&2; exit 1; }
    grep -q -e '-DHAVE_XSS=1' "$cfg" || { echo "Tk was built WITHOUT XScreenSaver" >&2; exit 1; }
    grep -q -e '-lXft' "$pc" || { echo "tk.pc does not link Xft" >&2; exit 1; }
    grep -q -e '-lXss' "$pc" || { echo "tk.pc does not link Xss" >&2; exit 1; }
    # CUPS is read off the library: configure's miss is silent and tkConfig.sh
    # does not record it. libcups is a DT_NEEDED entry and the calls of
    # unix/tkUnixPrint.c are imported symbols. That is Tk 9 only: Tk 8.6 has no
    # print support and must NOT link libcups (its dependency on cups is only
    # the shared declaration, see `dependencies`).
    case "{{version.major}}" in
      9)
        lib="{{prefix}}/lib/libtcl9tk9.0.so"
        grep -aq -e 'libcups' "$lib" || { echo "Tk was built WITHOUT libcups (no tk print)" >&2; exit 1; }
        for f in cupsGetNamedDest cupsCopyDestInfo cupsCreateDestJob cupsStartDestDocument cupsFinishDestDocument; do
          grep -aq -e "$f" "$lib" || { echo "libtcl9tk9.0 does not import $f" >&2; exit 1; }
        done
        ;;
      *)
        lib="{{prefix}}/lib/libtk{{version.marketing}}.so"
        test -f "$lib" || { echo "no $lib" >&2; exit 1; }
        ! grep -aq -e 'libcups' "$lib" || { echo "Tk 8.6 links libcups, which it has no use for" >&2; exit 1; }
        # the library 8.6 reads its scripts from, beside it (no zipfs)
        test -f "{{prefix}}/lib/tk{{version.marketing}}/tk.tcl" || { echo "no lib/tk{{version.marketing}}/tk.tcl" >&2; exit 1; }
        ;;
    esac
    ! grep -q -e '-DMAC_OSX_TK=1' "$cfg"
    ;;
esac
EOT
    },

    # A real Tk, only where a display is actually available and X is the
    # windowing system. `package require Tk` opens a display: on a headless
    # host it raises, and on darwin Aqua without a window session it can hang
    # (measured), so it is not run there.
    {
      run = <<EOT
set -eu
test "$(uname -s)" != Darwin || exit 0
test -n "$${DISPLAY:-}" || { echo "no DISPLAY: Tk not started" >&2; exit 0; }
cat > "$PWD/tkcheck.tcl" <<'TCL'
package require Tk
if {[tk windowingsystem] ne "x11"} { puts stderr "not x11"; exit 1 }
button .b -text hello
pack .b
update
if {[winfo exists .b] != 1} { exit 1 }
puts "Tk [info patchlevel] ok"
exit 0
TCL
"{{prefix}}/bin/wish" "$PWD/tkcheck.tcl"
EOT
    },
  ]
}

provenance {
  read = [
    "unix/configure.ac",  # 9.0.4 :40-41 requires Tcl 9.0+; :140-143 Tk/Tcl prefix warning; :210 --enable-aqua default no; :241-264 aqua frameworks vs SC_PATH_X; :345-424 Xft probe and its warning-only miss; :427-469 libcups; :481-523 XScreenSaver
    "unix/tcl.m4",        # :1963-2016 SC_PATH_X; --x-includes/--x-libraries honoured
    "unix/tk.pc.in",      # Requires: tcl; Libs.private carries the X libraries (read off the install)
    "macosx/tkMacOSXWm.c", # 9.0.4 :1390 removeObserver, the KVO crash fix
    "license.terms",
    "Mac/BuildScript/build-installer.py (CPython 3.15.2)", # :258-312 Tk 9.0.4, its checksum, `--enable-aqua --enable-shared --enable-threads`
    "https://www.tcl-lang.org/software/tcltk/download.html",
  ]

  consulted = [
    "pkgxdev/pantry projects/tcl-lang.org/package.yml", # facts only: the two macports patches and the `if: <8.6.14` fence; `--without-x` was NOT carried
  ]

  note = <<EOT
⛔ BUILT HERE IN SCRATCH, NOT BY THE FACTORY, AND NOT ON LINUX. On darwin/arm64,
against Tcl 9.0.4 built from the previous recipe:

  * an X11 Tk configured with `--enable-xft --enable-xss --enable-libcups=no`
    against XQuartz's /opt/X11 (pkg-config, --x-includes, --x-libraries) printed
    "checking for XftFontOpen in -lXft... yes" and "checking for
    XScreenSaverQueryInfo in -lXss... yes", built, installed, and its tkConfig.sh
    carried `-DHAVE_XFT=1 -DHAVE_XSS=1` and tk.pc listed `-lXft ... -lXss`;
    libtcl9tk9.0.dylib links libXft, libfontconfig, libfreetype, libX11, libXss
    (weak, a darwin linker choice) and libXext;
  * an Aqua Tk configured with `--enable-aqua` built and installed, with
    `-DMAC_OSX_TK=1` and no X library in TK_LIBS.

  * an X11 Tk configured with `--enable-libcups`, `cups-config` on PATH and
    CPPFLAGS/LDFLAGS at a scratch openprinting.github.io/cups install printed
    "checking whether to use libcups... yes", "checking for cups/cups.h... yes",
    built, and libtcl9tk9.0.dylib linked libcups.2.dylib and imported
    cupsGetNamedDest, cupsCopyDestInfo, cupsCreateDestJob, cupsStartDestDocument,
    cupsFinishDestDocument; tkConfig.sh and tk.pc recorded nothing about CUPS.

NOT RUN: `package require Tk` (no X server for the X build, and Aqua without a
window session can hang), the linux flag set (the CPPFLAGS/LDFLAGS for the
xorgproto, libXext and libXss prefixes are written from configure.ac's own
header and library checks, not exercised), and the recipe text as the factory
executes it. The test block's grep checks were run by hand on the darwin
installs.

⚠ `wish` of Tk 9 embeds its script library through zipfs, as libtcl9tk9.0
does; do not rewrite either binary after linking.

⚠ SIGNATURES: none exist (tcl-lang.org signs nothing). The digest equals the
one CPython's repository pins.
EOT
}
