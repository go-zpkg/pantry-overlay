# thrift — Apache Thrift: the `thrift` IDL compiler and the C++ runtime
# libraries.
#
# ⛔ WRITTEN FROM THRIFT'S OWN FILES at 0.25.0, step 1 of go-zpkg/packages#440.
# It was a fragment — a list of `--without-<language>` flags copied from a
# third-party formula, with no version, no source and no pin.

summary = "Apache Thrift: IDL compiler and C++ runtime libraries"

# LICENSE:2-3 is "Apache License / Version 2.0, January 2004" and
# NOTICE is Apache's usual notice. LICENSE:204-end lists SUBCOMPONENTS with
# their own terms (an autoconf macro, a Crockford file, a Windows socketpair,
# an MSVC stdint.h) — every one of them is for a path that is NOT built here
# (aclocal/ax_boost_base.m4 is a build-time macro, not shipped in the output),
# so the artifact's licence is the project's own.
license = "Apache-2.0"

versions {
  # ⛔ A DIRECTORY PER RELEASE, not a flat file list: downloads.apache.org/thrift/
  # holds only the CURRENT releases (0.24.0, 0.25.0) and archive.apache.org keeps
  # all of them, so the archive is the index that sees every version.
  url   = "https://archive.apache.org/dist/thrift/"
  # ⛔ ANCHORED AT `0\.`, AND THE REASON WAS MEASURED. The first draft was
  # `\d+\.\d+\.\d+/`, which matched inside the index entry `0.9.3.1/` (a real
  # four-part release, 2020-07-06) as "9.3.1" — a version that does not exist,
  # 404s, and sorted as the NEWEST, so it would have been the one built.
  # Thrift's releases are all 0.x; the optional fourth part keeps 0.9.3.1 whole.
  match = "/0\\.\\d+\\.\\d+(\\.\\d+)?\\//"
  strip = [
    "/\\/$/",
  ]
}

distributable {
  # downloads.apache.org is the primary mirror and serves the live releases;
  # a release that is superseded is removed from it and survives only on
  # archive.apache.org, which is why `versions` reads the archive. The
  # distributable is the stored release tarball in either case.
  url              = "https://downloads.apache.org/thrift/{{version.raw}}/thrift-{{version.raw}}.tar.gz"
  strip-components = 1

  # 0.25.0 — 5 068 440 bytes, fetched with `zpkb sourcepin`:
  #
  #   signed by  8CD87F186F06E958EFCA963D76BD340FC4B75865
  #              Jens Geyer <jensg@apache.org>, signed 2026-09-24
  #   key from   https://downloads.apache.org/thrift/KEYS — the project's
  #              own list, on the release host. Exported from that file for
  #              the check; no keyserver was asked.
  #
  # ⭐ A SECOND, INDEPENDENT WITNESS: the release directory publishes
  # thrift-0.25.0.tar.gz.sha256 beside the archive, and it says
  # 66da4707214c54c94bac082103dc67adaf9e08925662700f269170a7b534b214 — the
  # digest sourcepin computed. Two statements agree, from the signature and
  # from a file.
  #
  # ⛔ Both come from the same Apache host, so the pair is continuity and not
  # independence from Apache; what the signature adds is that the key is one
  # of the project's release managers' keys in KEYS rather than the host's.
  sha256 = {
    "0.25.0" = "66da4707214c54c94bac082103dc67adaf9e08925662700f269170a7b534b214"
  }

  # ⛔ NO `sha` FIELD for the same reason as gawk: a `.asc` there fails every
  # build. The signature lives in `provenance`.
}

build {
  dependencies = {
    # Headers only: lib/cpp/Makefile.am:36,54,130-132 passes $(BOOST_CPPFLAGS)
    # and $(BOOST_LDFLAGS), and the libboost_*.a archives that
    # configure.ac:153-158 substitute are used only by the tests, which are
    # off below.
    "boost.org" = "*"

    # configure.ac:89 AC_PROG_BISON(2.5). The tarball ships thriftl.cc and
    # thrifty.cc (compiler/cpp/src/thrift/), so bison is not expected to run —
    # it is declared because the generated Makefile.in carries the rule that
    # reruns it when timestamps order the grammar after its output, which a
    # tarball extract does not guarantee.
    "gnu.org/bison" = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir={{prefix}}/lib",

      # ⛔⛔ EVERY OPTIONAL INPUT NAMED, because configure.ac auto-detects each
      # of these on the build host and the output depends on what is staged.
      #
      # DEPENDENCIES WE USE. `--with-openssl=DIR` is exact: ax_check_openssl.m4
      # :40-48 refuses yes/no and takes a directory. `--with-zlib=DIR` and
      # `--with-boost=DIR` are the same shape (ax_lib_zlib.m4:115-128;
      # AX_BOOST_BASE, configure.ac:151).
      "--with-openssl={{deps.openssl.org.prefix}}",
      "--with-zlib={{deps.zlib.net.prefix}}",
      "--with-boost={{deps.boost.org.prefix}}",

      # libevent builds libthriftnb and thrift-nb.pc (lib/cpp/Makefile.am:40-43)
      # and is searched in /usr, /usr/local and /opt (ax_lib_event.m4:168) —
      # i.e. exactly where a host's own copy would be found. The fragment this
      # replaces never declared it, so any result was the host's. OFF here:
      # `--with-libevent=no` is ax_lib_event.m4:146-147.
      "--with-libevent=no",

      # THE LANGUAGE BINDINGS — every AX_THRIFT_LIB in configure.ac, the full
      # list (lines 148, 168, 189, 207, 222, 234, 259, 269, 279, 296, 313,
      # 328, 345, 354, 366, 387, 399, 443, 467, 477, 487, 497) and each
      # default is `yes` (ax_thrift_internal.m4:20-23). The C++ library
      # (`cpp`) is the one kept; the others are enumerated OFF so that a host
      # with a JDK, Erlang, Lua, a Python, Ruby or Go toolchain does not grow
      # extra install trees. `swift` is not an option of this release and is
      # not listed.
      "--with-cpp",
      "--without-qt5",
      "--without-c_glib",
      "--without-java",
      "--without-kotlin",
      "--without-erlang",
      "--without-nodejs",
      "--without-nodets",
      "--without-lua",
      "--without-python",
      "--without-py3",
      "--without-perl",
      "--without-php",
      "--without-php_extension",
      "--without-dart",
      "--without-ruby",
      "--without-go",
      "--without-rs",
      "--without-cl",
      "--without-haxe",
      "--without-netstd",
      "--without-d",

      # configure.ac:600-617: tests and tutorial are built by default and add
      # SUBDIRS (Makefile.am:24-30); neither is part of what is installed.
      "--disable-tests",
      "--disable-tutorial",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }}
make install
EOT
}

# compiler/cpp/Makefile.am:31 `bin_PROGRAMS = thrift`; the libraries and
# thrift.pc, thrift-z.pc come from lib/cpp/Makefile.am:33-47 (thrift-nb.pc
# only with libevent, so it is not listed).
provides = [
  "bin/thrift",
]

test {
  dependencies = {
    "gnu.org/gcc"                = "*"
    "freedesktop.org/pkg-config" = "*"
  }

  script = [
    "thrift --version | grep {{version.raw}}",
    "test -f {{prefix}}/include/thrift/Thrift.h",
    "pkg-config --exists thrift",
    "pkg-config --exists thrift-z",

    # ⛔ THE WITNESS FOR "libevent=no": a build that picked up the host's copy
    # would also have produced libthriftnb and its .pc.
    "! pkg-config --exists thrift-nb",

    # The compiler end to end: an IDL in, C++ out.
    {
      fixture = {
        content  = <<EOT
namespace cpp demo
struct Point {
  1: i32 x,
  2: i32 y,
}
service Echo {
  Point ping(1: Point p),
}
EOT
        extname = "thrift"
      }
      run = "thrift -r --gen cpp -out . $FIXTURE && test -f demo_types.h"
    },
  ]
}

provenance {
  read = [
    "configure.ac",                     # :23 AC_INIT 0.25.0; :89 AC_PROG_BISON(2.5); :118-146 --enable-libs; :148-503 one AX_THRIFT_LIB per language, default yes; :151 AX_BOOST_BASE; :162 AX_LIB_EVENT; :165 AX_LIB_ZLIB; :203 AX_CHECK_OPENSSL; :600-617 --enable-tests / --enable-tutorial
    "aclocal/ax_thrift_internal.m4",    # :20-23 --with-<lang>, default from the third argument (yes)
    "aclocal/ax_check_openssl.m4",      # :40-48 --with-openssl=DIR, yes/no refused; :52-62 pkg-config probe when absent
    "aclocal/ax_lib_event.m4",          # :143-156 --with-libevent[=DIR]; :146-147 `no` disables; :168 the default search path
    "aclocal/ax_lib_zlib.m4",           # :115-128 --with-zlib[=DIR]
    "Makefile.am",                      # :22-30 SUBDIRS compiler/cpp lib, test, tutorial
    "compiler/cpp/Makefile.am",         # :31 bin_PROGRAMS = thrift
    "lib/cpp/Makefile.am",              # :33-51 libthrift, thrift.pc; libthriftnb/thriftz/thriftqt5 conditional; :36,54,130-132 boost used as flags only
    "LICENSE",                          # :2-3 Apache License 2.0; :204-end subcomponent notices
    "README.md",
  ]

  consulted = [
    "the apache.org/thrift fragment this replaces",
    "https://downloads.apache.org/thrift/KEYS",
    "https://downloads.apache.org/thrift/0.25.0/thrift-0.25.0.tar.gz.sha256",
  ]

  note = <<EOT
The fragment's own build ran ./bootstrap.sh, which needs autoconf, automake
and libtool: the release TARBALL already ships configure, Makefile.in and
aclocal.m4 (checked in the 0.25.0 archive), so none of the three is needed
here and none is declared.

Two lines of the fragment were dropped as unread: `--disable-debug` (no such
option exists in configure.ac) and the PHP_PREFIX/PY_PREFIX variables, which
only matter to bindings that are off.

Signature: https://downloads.apache.org/thrift/0.25.0/thrift-0.25.0.tar.gz.asc
key 8CD87F186F06E958EFCA963D76BD340FC4B75865, Jens Geyer <jensg@apache.org>,
fingerprint read from the signature and the key found in the project's own
KEYS file; verified with `zpkb sourcepin` when the digest was recorded, not
at every build. No keyserver was asked.
EOT
}
