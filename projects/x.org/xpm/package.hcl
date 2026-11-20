# x.org/xpm — libXpm, the X Pixmap (XPM) image format library, and the `cxpm`
# checker. Written whole (go-zpkg/packages#440 step 1) from libXpm 3.5.20's own
# files, at the newest version `versions` resolves.
#
# ⭐ WHAT WRITING IT FOUND, each read off configure.ac / README.md / the Makefile.am files:
#
#   1. TWO OPTIONAL FEATURES EXECUTE EXTERNAL PROGRAMS, AND BAKE THEIR PATHS IN.
#      `--enable-open-zfile` (default yes off mingw, configure.ac:59-88) makes
#      libXpm open a pipe to `gzip`/`compress`/`uncompress` for names ending in
#      .gz/.Z, and README.md says the paths are set AT CONFIGURE TIME to the first
#      copy found in the PATH used to run configure. A relocatable library would
#      then carry the absolute path of whichever gzip the BUILD host had, and
#      configure fails outright without one (:77-78). `--enable-stat-zfile`
#      (:90-100) rides on it. Both are REFUSED: `--disable-open-zfile` and
#      `--disable-stat-zfile`, each named so that no host decides it.
#   2. GETTEXT IS A SILENT DETECTION (:33-50): AC_SEARCH_LIBS(gettext) sets
#      USE_GETTEXT, and when it is yes cxpm/Makefile.am and sxpm/Makefile.am add
#      `noinst_DATA = cxpm.po`, which `make` builds with `xgettext`. glibc has
#      gettext, so a linux build would need xgettext and darwin would not.
#      `--with-localedir=no` (:35-44: LOCALEDIR=no => USE_GETTEXT=no) turns it
#      off. Nothing is lost: the tarball ships no po/ directory and installs no
#      message catalogue.
#   3. UNIT TESTS AND GLIB (:102-108): `--enable-unit-tests` defaults to auto and
#      probes glib. Only `make check` uses them, but the probe is a host-dependent
#      detection, so `--disable-unit-tests --without-glib` name it off.
#   4. sxpm NEEDS libXt (:28-30, `x11 xt xext xextproto`), AND IS A SILENT
#      CONDITIONAL: build_sxpm is true when pkg-config happens to find xt. There
#      is no switch, and x.org/xt is not in this tree. So the build is told which
#      directories to make: `make SUBDIRS="doc include man src cxpm"` (top
#      Makefile.am:4 lists `doc include man src sxpm cxpm test`; SUBDIRS is an
#      ordinary make variable). The consequence is stated, not hidden: sxpm.1 is
#      installed (man/Makefile.am), the `sxpm` program is not, and the test below
#      asserts that. `test/` (unit tests) is skipped for the same reason as 3.

summary = "X.Org libXpm: the X Pixmap (XPM) image format library, and cxpm"

# COPYING holds four notices. :1-22 GROUPE BULL, :24-45 Arnaud LE HORS and :47-68
# Lorens Younes are one text, each ending "Except as contained in this notice,
# the name of … shall not be used in advertising": X11. :71-90, "Copyright (c)
# 2023, Oracle and/or its affiliates", is the X.Org text with "(including the
# next paragraph)" and no advertising clause: MIT.
license = "X11 AND MIT"

platforms = ["linux", "darwin"]

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/libXpm-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = ["/libXpm-/", "/\\.tar\\.xz/"]
}

dependencies = {
  # configure.ac:27 `PKG_CHECK_MODULES(XPM, xproto x11)`; xpm.pc.in
  # `Requires: x11`, `Requires.private: x11`.
  "x.org/x11"      = "^1"
  "x.org/protocol" = "*"
}

distributable {
  # 473428 bytes, signature verified with `zpkb sourcepin` (see provenance.note)
  # and equal to a second, independent fetch-and-hash (curl + shasum).
  url              = "https://www.x.org/releases/individual/lib/libXpm-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "3.5.20" = "c064ead03e4dde78afdeb121fe0b644d25c550444cf903fbdc537f1a78f3ef74"
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

      # ⛔ THE SWITCHES `./configure --help` LISTS, EACH NAMED OR REFUSED:
      #   --enable-shared / --enable-static   libtool, both default yes. Kept.
      #   --enable-open-zfile  REFUSED, finding 1.
      "--disable-open-zfile",
      #   --enable-stat-zfile  REFUSED, finding 1.
      "--disable-stat-zfile",
      #   --enable-unit-tests  REFUSED, finding 3.
      "--disable-unit-tests",
      #   --with-glib          REFUSED, finding 3.
      "--without-glib",
      #   --with-localedir     `no`: finding 2.
      "--with-localedir=no",
      #   --enable-strict-compilation  default off (turns warnings into errors:
      #                        a newer compiler would break the build). Kept off.
      #   --enable-selective-werror    default on. Kept.
    ]
  }

  script = [
    "./configure $ARGS",
    # finding 4: sxpm is not built.
    "make --jobs {{ hw.concurrency }} SUBDIRS=\"doc include man src cxpm\"",
    "make install SUBDIRS=\"doc include man src cxpm\"",
  ]
}

provides = [
  "bin/cxpm",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f \"{{prefix}}/include/X11/xpm.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/xpm.pc\"",
    "pkg-config --exists xpm",
    "pkg-config --exact-version={{version.raw}} xpm",

    # finding 4, read off the artifact.
    "test ! -e \"{{prefix}}/bin/sxpm\"",

    # finding 1, read off the artifact: no gzip path was baked in.
    {
      run = <<EOT
set -eu
lib=""
for f in "{{prefix}}"/lib/libXpm.so "{{prefix}}"/lib/libXpm.dylib; do
  if test -e "$f"; then lib="$f"; break; fi
done
test -n "$lib" || { echo "no libXpm shared library" >&2; exit 1; }
real=$(readlink -f "$lib" 2>/dev/null || echo "$lib")
! grep -aq -e '/gzip' "$real" || { echo "libXpm embeds the path of a gzip" >&2; exit 1; }
EOT
    },

    # The tool: cxpm checks the syntax of an XPM file.
    {
      fixture = {
        content  = <<EOT
/* XPM */
static char * p_xpm[] = {
"2 2 2 1",
"a c #000000",
"b c #FFFFFF",
"ab",
"ba"};
EOT
        extname = "xpm"
      }
      run = "cxpm $FIXTURE"
    },

    # And the LIBRARY, which is what dependents link: the header's version and
    # the library's must agree (a disagreement is how a build picks up a system
    # libXpm instead of the one it just made), then a real file is parsed.
    {
      run = <<EOT
set -eu
cat > p.xpm <<'XPM'
/* XPM */
static char * p_xpm[] = {
"2 2 2 1",
"a c #000000",
"b c #FFFFFF",
"ab",
"ba"};
XPM
cat > roundtrip.c <<'C'
#include <stdio.h>
#include <X11/xpm.h>

int main(void) {
  if (XpmIncludeVersion != XpmLibraryVersion()) {
    printf("header %d but library %d\n", XpmIncludeVersion, XpmLibraryVersion());
    return 1;
  }
  XpmImage img;
  int rc = XpmReadFileToXpmImage("p.xpm", &img, NULL);
  if (rc != XpmSuccess) {
    printf("read: %s\n", XpmGetErrorString(rc));
    return 1;
  }
  if (img.width != 2 || img.height != 2 || img.ncolors != 2) {
    printf("wrong image %ux%u, %u colors\n", img.width, img.height, img.ncolors);
    return 1;
  }
  XpmFreeXpmImage(&img);
  puts("libXpm read a 2x2 pixmap");
  return 0;
}
C
gcc roundtrip.c -o roundtrip $(pkg-config --cflags --libs xpm)
./roundtrip
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",    # :27-30 modules, sxpm conditional; :33-50 gettext; :59-100 open-zfile, stat-zfile; :102-108 unit tests, glib
    "Makefile.am",     # :4 SUBDIRS = doc include man src sxpm cxpm test
    "src/Makefile.am", # the library sources; -version-number 4:11:0
    "sxpm/Makefile.am", # BUILD_SXPM conditional, noinst_DATA po
    "cxpm/Makefile.am", # noinst_DATA po
    "xpm.pc.in",       # Requires: x11
    "README.md",       # :27-48 the two zfile features, paths fixed at configure time
    "COPYING",         # :1-90 the four notices
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://github.com/alanc.gpg",               # the signer's key, from GitHub's account endpoint
  ]

  consulted = [
    # Read for facts only: the name x.org/xpm. Its `--disable-open-zfile` was
    # looked at and the reason for it (finding 1) was written from README.md.
    "pkgxdev/pantry projects/x.org/xpm/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, with a key from an account endpoint rather than a keyserver.

  signature   https://www.x.org/releases/individual/lib/libXpm-3.5.20.tar.xz.sig
  signed at   2026-10-16, RSA, issuer fingerprint
              3AB285232C46AE43D8E192F4DAB0F78EA6E7E2D2
  signer      Alan Coopersmith <alan.coopersmith@oracle.com>
  key from    https://github.com/alanc.gpg (GitHub's account endpoint)

⚠ THE RUNG, STATED: GitHub's account page, a third party that is not X.Org (the
same chain as x.org/xscrnsaver). X.Org itself publishes no page naming the
signing keys of its release archives.

⛔ NOT BUILT by the factory, and NOT ON LINUX. Built on darwin/arm64 against
XQuartz's /opt/X11 libX11 (PKG_CONFIG_PATH), with exactly the arguments above:
configure printed "whether to handle compressed pixmaps... no", "where to
install localized messages... nowhere" and "whether to build unit test cases...
no"; `make SUBDIRS="doc include man src cxpm" install` installed libXpm.4.dylib,
libXpm.a, X11/xpm.h, xpm.pc (Version: 3.5.20, Requires: x11) and bin/cxpm and no
sxpm; cxpm accepted a 2x2 pixmap and a C program linked through `pkg-config
--libs xpm` read it back with XpmReadFileToXpmImage. The test block's gcc step
was run by hand with those results. NOT RUN: the recipe text as the factory
executes it; the linux build (glibc has gettext, so finding 2 is the difference
that would show there).
EOT
}
