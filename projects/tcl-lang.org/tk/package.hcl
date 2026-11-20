# tcl-lang.org/tk — Tk, the Tcl GUI toolkit, built against the core Tcl of
# `tcl-lang.org` (go-zpkg/recipes#122 step 3). It is what python's `_tkinter`
# links: CPython 3.15.2 configure.ac:4607 asks pkg-config for
# `tcl >= 8.5.12 tk >= 8.5.12`, and tk.pc is installed by this recipe.
#
# ⛔ WRITTEN FROM TK 9.0.4'S OWN FILES (go-zpkg/packages#431), read out of the
# published source tarball, and BUILT AND INSTALLED in a scratch directory on
# darwin/arm64 twice — as an X11 Tk against XQuartz's libraries (Xft and
# XScreenSaver both found and compiled in) and as an Aqua Tk. NOT built by the
# factory, and not built on linux.
#
# ⭐ WHICH VERSION: 9.0.4 only, the line CPython 3.15.2 itself ships (see
# tcl-lang.org). Tk 8.6 is not pinned: its only consumer here was python, and
# no recipe of this tree asks for it.
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
# ⛔ NOT DONE, WITH THE REASON: `--enable-libcups` (:427-469, 9.0 only, default
# on) is PINNED OFF. It is auto-detected through `cups-config` and a miss is
# silent, so it must be named; but libcups is a recipe this tree does not have
# (`openprinting.github.io/cups` is a dependencies-only fragment that cannot
# resolve once go-zpkg/zpkb#514 lands), and declaring a fragment makes this
# recipe unresolvable. What is lost is Tk 9's `tk print` to a CUPS queue. This is
# a stated gap, to be closed by writing the cups recipe, not a decision that
# printing is unwanted.
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
  # unix/configure.ac:40-41 "requires Tcl 9.0+"; tk.pc `Requires: tcl >= 9.0`,
  # read off the scratch install. Tk finds tclConfig.sh through --with-tcl.
  "tcl-lang.org" = "^9"

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
}

distributable {
  url              = "https://downloads.sourceforge.net/project/tcl/Tcl/{{version.raw}}/tk{{version.raw}}-src.tar.gz"
  strip-components = 1

  # 4613019 bytes, recorded with the builder's own fetcher (`zpkb sourcepin
  # --version 9.0.4 <url>`, zpkb v0.89.0) and confirmed by a second, independent
  # fetch-and-hash (curl + shasum).
  #
  # ⭐ IDENTICAL TO THE DIGEST CPYTHON'S OWN REPOSITORY PINS for Tk 9.0.4:
  # Mac/BuildScript/build-installer.py:270 `tk_checksum='d7a146d2…01dbb4'`.
  # tcl-lang.org publishes no checksum and no signature, so there is nothing to
  # verify beyond that.
  sha256 = {
    "9.0.4" = "d7a146d2917eb8b5cc95276dbf0e3d03c7464d2b19c1675357857c989301dbb4"
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
      # --help`, 9.0.4, read):
      #   --enable-shared     default on; python links libtcl9tk9.0.
      "--enable-shared",
      #   --enable-load       default on; Tk is itself loaded with `load`.
      "--enable-load",
      #   --enable-zipfs      default on (ZIPFS_BUILD=1 in tkConfig.sh): the Tk
      #                       script library is embedded in libtcl9tk9.0, so
      #                       `package require Tk` needs no lib/tk9.0 lookup.
      #   --enable-corefoundation default on, darwin only. Kept.
      #   --enable-symbols    default off. --enable-framework default off.
      #   --enable-man-*      documentation layout only.
      #   --enable-64bit      REFUSED for the reason given in tcl-lang.org: a
      #                       platform-case flag selector that is a no-op on
      #                       64-bit linux and darwin.
      #   --with-encoding     default utf-8. Kept.
      #   --with-x            default on where X is used; passed through
      #                       --x-includes/--x-libraries below.
      #   --enable-libcups    PINNED OFF (see the header): auto-detected,
      #                       silent on a miss, and no libcups recipe exists.
      "--disable-libcups",
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
      CPPFLAGS = "-I{{deps.x.org/protocol.prefix}}/include -I{{deps.x.org/xext.prefix}}/include -I{{deps.x.org/xscrnsaver.prefix}}/include"
      LDFLAGS  = "-L{{deps.x.org/xext.prefix}}/lib -L{{deps.x.org/xscrnsaver.prefix}}/lib"
    }

    # darwin: Aqua (see the header). --enable-xft/--enable-xss would be inert
    # there and are not passed.
    darwin = {
      ARGS = [
        "--enable-aqua",
      ]
    }
  }

  script = [
    "cd unix && ./configure $ARGS",
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
