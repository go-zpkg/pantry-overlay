# qalculate.github.io — libqalculate, the Qalculate! calculation library, and
# `qalc`, its command line calculator.
#
# ⛔ WRITTEN FROM LIBQALCULATE'S OWN configure.ac (go-zpkg/packages#440), not from
# a fragment. Only the library and the text port are built: the GTK and Qt
# front ends (qalculate-gtk, qalculate-qt) are separate repositories.

summary = "Qalculate!: a multi-purpose calculator library and its qalc command"

# libqalculate/Calculator.cc:1-12 carries the header "either version 2 of the
# License, or (at your option) any later version" (the same header is on the
# other sources), and COPYING is the GNU General Public License text.
license = "GPL-2.0-or-later"

versions {
  github = "Qalculate/libqalculate"
}

dependencies = {
  # configure.ac:109-113 AC_CHECK_HEADER/LIB gmp and mpfr, both AC_MSG_ERROR.
  "gnu.org/gmp"  = "*"
  "gnu.org/mpfr" = "*"
  # configure.ac:157 PKG_CHECK_MODULES(LIBXML, [libxml-2.0 >= 2.3.8]), required.
  "gnome.org/libxml2" = "*"
  # configure.ac:133-139 --with-libcurl, default yes: PKG_CHECK_MODULES(libcurl)
  # for the built-in exchange-rate download.
  "curl.se" = "*"
  # configure.ac:185-267 --with-readline: qalc's line editing, tried against
  # -lncurses first (:208-211), so ncurses is named too.
  "gnu.org/readline"             = "^8"
  "invisible-island.net/ncurses" = "^6"
  # configure.ac:302-303 AM_GNU_GETTEXT(external) needs libintl at run time on
  # platforms where libc has none (macOS).
  "gnu.org/gettext" = "^1"
  linux = {
    # src/Makefile.am:11 builds qalc as C++; the library is C++ throughout.
    "gnu.org/gcc/libstdcxx" = 14
  }
}

distributable {
  # THE STORED RELEASE ASSET, which is a `make dist` tarball: it carries a
  # generated ./configure, so no autoconf, automake or libtool is needed to
  # build (the generated archive of the tag would have none).
  url              = "https://github.com/Qalculate/libqalculate/releases/download/v{{version.raw}}/libqalculate-{{version.raw}}.tar.gz"
  strip-components = 1

  # 3609253 bytes, fetched with `zpkb sourcepin`; a second, independent fetch
  # (curl, then shasum -a 256) gave the same digest. 5.13.2 is the newest
  # release `zpkb versions` resolves.
  sha256 = {
    "5.13.2" = "81af6c54018d5cbc9ce4df5a82c3ffb7b195193d72dcabb904f522b69936f3e6"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/gettext"            = "^1"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # Every optional input is named, none left to auto-detection:
      #
      # :16-19 --disable-textport; default yes. This is `qalc`, the point of
      # the package.
      "--enable-textport",
      # :26-34 --enable-unittests defaults to YES and builds a `unittest`
      # runner into src/. Not installed (src/Makefile.am:12 puts it in
      # noinst_PROGRAMS), so it is OFF to save the build.
      "--disable-unittests",
      "--disable-tests",
      "--disable-defs2doc",
      # :120-124 compile the definitions into the library instead of reading
      # share/qalculate/*.xml: default off, kept off so the data files stay
      # editable.
      "--disable-compiled-definitions",
      # :133 default yes; libcurl is a dependency above.
      "--with-libcurl",
      # :141-147 default yes and PKG_CHECK_MODULES(icu-uc) is then REQUIRED.
      # OFF: this tree has no ICU recipe (the fragment named "unicode.org",
      # which does not exist). The cost, per the option's own help text, is
      # case-insensitive matching of non-ASCII unit and variable names.
      "--without-icu",
      # :149-152 default yes: lets plot() and command() popen an external
      # gnuplot. No gnuplot is a dependency, and the call is only made when the
      # user asks for a plot, so it stays at the default.
      "--with-gnuplot-call",
      # :186-197 readline in qalc: ON, the default.
      "--with-readline=yes",
      # AM_GNU_GETTEXT(external), configure.ac:302: translations ON.
      "--enable-nls",
      # Shared library only: libtool's default would build both and install a
      # static libqalculate.a that nothing here links.
      "--disable-static",
      "--enable-shared",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

# src/Makefile.am:11 `bin_PROGRAMS = @QALCULATE_TEXT@`, which configure.ac:182
# sets to qalc. The commented-out install-exec-local at :54-55 would have made a
# `qalculate` link; it is commented out, so it is not provided.
provides = [
  "bin/qalc",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/libqalculate/Calculator.h",
    "test -f {{prefix}}/lib/pkgconfig/libqalculate.pc",
    "pkg-config --exists libqalculate",
    # Data the calculator needs to start: Makefile.am:5 builds data/, which
    # installs the definition files under share/qalculate.
    # (elements.xml is generated from elements.xml.in, data/Makefile.am:7.)
    "test -f {{prefix}}/share/qalculate/elements.xml",
    # -t is terse output. Pure arithmetic, so no exchange-rate download.
    {
      run = "test \"$(qalc -t '(1+2)*3')\" = 9"
    },
    {
      fixture = {
        content  = <<EOT
#include <libqalculate/qalculate.h>
#include <iostream>
#include <string>

int main() {
  new Calculator();
  CALCULATOR->loadGlobalDefinitions();
  std::string r = CALCULATOR->calculateAndPrint("2^10 + 1", 2000);
  if (r != "1025") {
    std::cout << "unexpected: " << r << std::endl;
    return 1;
  }
  std::cout << "libqalculate computed " << r << std::endl;
  return 0;
}
EOT
        extname = "cc"
      }
      run = "g++ -std=c++17 $FIXTURE -o qcheck $(pkg-config --cflags --libs libqalculate)"
    },
    "./qcheck",
  ]
}

provenance {
  read = [
    "configure.ac",            # :16-34 feature switches; :109-113 gmp, mpfr; :120 compiled defs; :133-147 libcurl, icu; :149 gnuplot; :157 libxml; :185-267 readline; :302 gettext
    "src/Makefile.am",         # :11 bin_PROGRAMS qalc; :12 noinst unittest; :20-27 qalc link line
    "Makefile.am",             # :5 SUBDIRS; :12-13 libqalculate.pc
    "libqalculate.pc.in",      # :9-11 Libs.private, Requires.private
    "libqalculate/Makefile.am",   # :23-25 headers install under include/libqalculate
    "data/Makefile.am",           # :5-7 definition files install under share/qalculate
    "docs/reference/Makefile.am", # :8 doxygen docs only when doxygen is on PATH
    "libqalculate/Calculator.cc", # :1-12 GPL-2.0-or-later header
  ]

  consulted = [
    "homebrew-core Formula/lib/libqalculate.rb",
    "pkgxdev/pantry projects/qalculate.github.io/package.yml",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; the build and test blocks have
not been run on either platform.

⛔ THE 5.13.2 TARBALL SAYS 5.13.1 INSIDE. Its configure.ac:9 is
`AC_INIT([libqalculate],[5.13.1])` and configure:598 is PACKAGE_VERSION='5.13.1'
(measured by unpacking the pinned asset). Upstream tagged v5.13.2 without bumping
it, so no test here compares a printed version with the package version: the test runs
arithmetic through qalc and through the library instead.

ICU is OFF because it is missing from this tree (see the build note), not
because the project treats it as optional in spirit.

Doxygen is not switchable: configure.ac:167-171 only looks for `doxygen` on PATH
and docs/reference/Makefile.am:8 then installs the HTML reference. The build
environment has none and none is declared, so the reference is not built.

The old fragment also named "ginac.de/cln" and "unicode.org". CLN is not used by
configure.ac (libqalculate computes with gmp and mpfr), and unicode.org has no
recipe; both are dropped.
EOT
}
