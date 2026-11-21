# libcap-ng — a library for programming with POSIX capabilities, and three
# utilities (pscap, netcap, filecap).
#
# ⛔ WRITTEN FROM LIBCAP-NG'S OWN FILES at 0.9.6 (go-zpkg/packages#440 step 1).
# OpenVPN's configure.ac makes libcap-ng mandatory on Linux (it stops with
# AC_MSG_ERROR when `libcap-ng` is not found by pkg-config) and no recipe
# existed.

summary = "Library for POSIX capabilities, with the pscap, netcap and filecap utilities"

# The library is LGPL: src/cap-ng.c:5-8 "GNU Lesser General Public License ...
# version 2.1 ... or (at your option) any later version". The utilities are GPL:
# utils/pscap.c:6-9 "GNU General Public License ... version 2, or (at your
# option) any later version". COPYING is the GPL text and COPYING.LIB the LGPL
# one. What is installed is both, hence AND.
license = "LGPL-2.1-or-later AND GPL-2.0-or-later"

# Linux capabilities are a Linux kernel interface.
platforms = ["linux"]

versions {
  # Tags are `v0.9.6`. Since 0.9 the project no longer publishes tarballs on
  # people.redhat.com (README.md:168), and its GitHub releases carry NO assets.
  github = "stevegrubb/libcap-ng"
}

distributable {
  # ⚠ A GENERATED TAG ARCHIVE, the weakest rung this fleet accepts: the releases
  # v0.9.2 to v0.9.6 have zero stored assets, so there is no file the project
  # uploaded to pin. GitHub makes this tarball on demand from the tag; its bytes
  # are not guaranteed stable across GitHub's tooling changes, and a change shows
  # up as a sha256 mismatch here, never as a silent different build.
  #
  # 0.9.6: 186292 bytes. It is the git tree, NOT a `make dist` tarball: there is
  # no configure script in it, so the build below runs autoreconf (README.md:170-
  # 178 and autogen.sh do exactly that).
  #
  # Witness: the same bytes were fetched a second time from codeload.github.com,
  # the host GitHub redirects the archive URL to, and the two digests agree. That
  # is the same GitHub backend, so it proves the fetch was not corrupted and the
  # archive is reproducible today; it does NOT say who made the bytes. The project
  # publishes no signature and no digest.
  url              = "https://github.com/stevegrubb/libcap-ng/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "0.9.6" = "399040138e0ca62fa2bcabd63da9af4431a246ef7a654561a0ca3cb00010a539"
  }
}

dependencies = {}

build {
  # autogen.sh:4-5 is `touch NEWS` then `autoreconf -fv --install`, so the
  # autotools are build tools here (libtool for the .la library, automake for
  # Makefile.am and AM_PATH_PYTHON, m4 for autoconf).
  dependencies = {
    "gnu.org/autoconf" = "^2"
    "gnu.org/automake" = "^1"
    "gnu.org/libtool"  = "^2"
    "gnu.org/m4"       = "^1"
    "gnu.org/make"     = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # configure.ac:351-355: Python 3 bindings are `auto` by default and need
      # SWIG and Python.h. They would land in site-packages, which is not what
      # a C consumer (OpenVPN) wants, so they are off.
      "--without-python",

      # configure.ac:76-79: cap-audit is `no` by default and needs clang,
      # bpftool, libbpf and libaudit (README.md:259-260). Named so it is stated.
      "--disable-cap-audit",

      # configure.ac:195-199: the deprecated utilities (captest) are `no` by
      # default. Named so it is stated.
      "--disable-deprecated",
    ]
  }

  script = [
    "touch NEWS",
    "autoreconf -fv --install",
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# utils/Makefile.am:35 `bin_PROGRAMS = pscap netcap filecap` (captest only with
# --enable-deprecated).
provides = [
  "bin/filecap",
  "bin/netcap",
  "bin/pscap",
]

test {
  script = [
    "test -f {{prefix}}/include/cap-ng.h",
    "pkg-config --exists libcap-ng",
    "test \"$(pkg-config --modversion libcap-ng)\" = {{version.raw}}",
    "ls {{prefix}}/lib/libcap-ng.* > /dev/null",
    "test -x {{prefix}}/bin/pscap",
  ]
}

provenance {
  read = [
    "configure.ac",      # :32 AC_INIT 0.9.6; :76-79 --enable-cap-audit; :195-199 --enable-deprecated; :351-360 --with-python; :446-447 python conditionals
    "autogen.sh",        # :4-5 touch NEWS; autoreconf -fv --install
    "README.md",         # :168 no more people.redhat.com tarballs; :170-181 build; :253-263 cap-audit needs clang/bpftool/libbpf/libaudit
    "src/Makefile.am",   # :25-26 libcap-ng.pc; :32-36 libcap-ng.la, libdrop_ambient.la, cap-ng.h
    "utils/Makefile.am", # :35 bin_PROGRAMS = pscap netcap filecap; :52-53 captest only if deprecated
    "src/cap-ng.c",      # :5-8 LGPL 2.1 or later
    "utils/pscap.c",     # :6-9 GPL 2 or later
    "src/libcap-ng.pc.in", # :7 Version: @VERSION@; :10 License: LGPL-2.1-or-later
    "COPYING.LIB",       # the LGPL text
    "COPYING",           # the GPL text
  ]

  consulted = [
    "https://github.com/stevegrubb/libcap-ng/releases",
    "https://codeload.github.com/stevegrubb/libcap-ng/tar.gz/refs/tags/v0.9.6",
  ]

  note = <<EOT
Written, not converted: no recipe existed.

The archive is a GENERATED tag archive: the project's releases carry no assets,
it publishes no signature and no digest. The pin rests on two fetches from
github.com/archive and codeload.github.com agreeing (186292 bytes, one digest),
which is one backend twice. Stated rather than implied.

⛔ THE BUILD AND THE TEST BLOCK WERE NOT RUN IN THIS SESSION. Stated rather than
implied. In particular the autoreconf step is read from autogen.sh, not run;
src/libcap-ng.pc.in:7 is `Version: @VERSION@`, which configure fills with the
AC_INIT version, so the test's modversion check is read, not exercised.
EOT
}
