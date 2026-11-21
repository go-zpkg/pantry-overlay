# darwinsys.com/file — file(1) and libmagic, the file-type identifier of Ian
# Darwin and Christos Zoulas. This tree carried only a dependency list for it (a
# fragment, go-zpkg/packages#440 step 1); this is the whole recipe. Many projects
# depend on it (it is the base `file`), so every choice is pinned below.
#
# ⛔ WRITTEN FROM FILE'S OWN FILES (go-zpkg/packages#431), at 5.48.
#
# ⭐ WHAT WRITING IT FOUND: configure.ac probes SEVEN optional libraries and seccomp
# and links whichever the build machine has, silently:
#   zlib      configure.ac:215-217  AC_CHECK_LIB(z, gzopen)
#   bzlib     :218-220              AC_CHECK_LIB(bz2, ...)
#   xzlib     :221-223              AC_CHECK_LIB(lzma, ...)
#   zstdlib   :224-226, lzlib :227-229, lrziplib :230-232
#   seccomp   :234-236, landlock :237-239 (a header probe, linux)
# `--enable-X` makes a missing library FATAL (:248-293); the default would simply
# build without it. So the three libraries this tree has are `--enable`d, and the
# rest are `--disable`d so the result is the same on every builder.

summary = "file(1) and libmagic: identify a file by its contents"

# COPYING:2-3 "Copyright (c) Ian F. Darwin ... maintained 1994- Christos Zoulas",
# its terms are the two-clause BSD (conditions 1 and 2, then the disclaimer).
# NOT READ: every file of magic/Magdir (the pattern database; each carries the
# same project licence by COPYING, individual files were not opened).
license = "BSD-2-Clause"

versions {
  url   = "https://astron.com/pub/file/"
  match = "/file-\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/file-/", "/\\.tar\\.gz/"]
}

dependencies = {
  "sourceware.org/bzip2" = "^1"
  "tukaani.org/xz"       = "^5"
  "zlib.net"             = "*"
}

distributable {
  # 2693209 bytes. NO SIGNATURE WAS VERIFIED, AND THAT IS WHAT IS RECORDED HERE: the
  # release carries a detached file-5.48.tar.gz.asc (issuer fingerprint
  # BE04995BA8F90ED0C0C176C471112AB16CB33B3A, read from its packet), but the project
  # publishes the public key only through a keyserver (README.md:151-154 says
  # "gpg --keyserver ... --recv-keys"), and no keyserver is asked. The second witness
  # is an independent fetch from another host: MacPorts' distfile mirror
  # (distfiles.macports.org/file/) served the same bytes (see provenance.note).
  url              = "https://astron.com/pub/file/file-{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "5.48" = "ed14656883b23a364b4057c05595d93252da9bc473d30106519519d0da141283"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ ON, AND FATAL WHEN MISSING (configure.ac:248-271), so `file -z` can look
      # inside gzip, bzip2 and xz. The libraries are found by AC_CHECK_LIB, which
      # has no DIR option: CPPFLAGS and LDFLAGS below carry the declared prefixes.
      "--enable-zlib",
      "--enable-bzlib",
      "--enable-xzlib",

      # ⛔ OFF: libraries this tree does not provide, and which a builder might
      # have (:224-232). zstd, lzip and lrzip streams are then reported by name only.
      "--disable-zstdlib",
      "--disable-lzlib",
      "--disable-lrziplib",

      # ⛔ OFF: the two sandboxes. seccomp links a builder's libseccomp (:234-236)
      # and landlock is on when the builder's kernel headers have it (:237-239);
      # either would change what the binary may do from builder to builder.
      "--disable-libseccomp",
      "--disable-landlock",
    ]

    CPPFLAGS = "-I{{deps.zlib.net.prefix}}/include -I{{deps.sourceware.org/bzip2.prefix}}/include -I{{deps.tukaani.org/xz.prefix}}/include"
    LDFLAGS  = "-L{{deps.zlib.net.prefix}}/lib -L{{deps.sourceware.org/bzip2.prefix}}/lib -L{{deps.tukaani.org/xz.prefix}}/lib"

    # An autotools install carries no run path; libmagic and the declared
    # libraries must find each other.
    linux = {
      LDFLAGS = "-L{{deps.zlib.net.prefix}}/lib -L{{deps.sourceware.org/bzip2.prefix}}/lib -L{{deps.tukaani.org/xz.prefix}}/lib -Wl,-rpath,{{prefix}}/lib -Wl,-rpath,{{deps.zlib.net.prefix}}/lib -Wl,-rpath,{{deps.sourceware.org/bzip2.prefix}}/lib -Wl,-rpath,{{deps.tukaani.org/xz.prefix}}/lib"
    }
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# src/Makefile.am:5 bin_PROGRAMS = file; the library, magic.h and libmagic.pc come from
# Makefile.am:10-11 and src/Makefile.am.
provides = [
  "bin/file",
]

test {
  dependencies = {
    "sourceware.org/bzip2" = "*"
    "tukaani.org/xz"       = "*"
  }

  script = [
    "test -f {{prefix}}/include/magic.h",
    "test -f {{prefix}}/lib/pkgconfig/libmagic.pc",
    # share/misc: Makefile.am / configure.ac:104 `pkgdatadir = $(datadir)/misc`.
    "test -s {{prefix}}/share/misc/magic.mgc",
    {
      run = <<EOT
set -eu
FILE="{{prefix}}/bin/file"
"$FILE" --version | head -1 | grep -q '^file-{{version.raw}}$'
printf 'hello world text\n' > t.txt
gzip -k t.txt
bzip2 -k t.txt
xz -k t.txt
# Each decompressor was compiled in (configure.ac:253-271): `-z` reports the
# compression AND the text inside. Without the library the inside is not read.
"$FILE" -z t.txt.gz | grep -q 'ASCII text (gzip compressed data'
"$FILE" -z t.txt.bz2 | grep -q 'ASCII text (bzip2 compressed data'
"$FILE" -z t.txt.xz | grep -q 'ASCII text (XZ compressed data'
[ "$("$FILE" -b --mime-type t.txt)" = "text/plain" ]
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac", # :9-76 the --enable/--disable switches, :104 pkgdatadir, :215-239 the library probes, :247-295 the --enable fatal checks
    "COPYING",      # :2-3 authors, then the two-clause BSD
    "Makefile.am",  # :10-11 libmagic.pc
    "src/Makefile.am", # :5 bin_PROGRAMS = file
    "README.md",    # :142-154 gpg: the key comes from a keyserver
  ]

  consulted = []

  note = <<EOT
NO SIGNATURE VERIFIED. The tarball's detached signature names the key BE04995BA8F90ED0C0C176C471112AB16CB33B3A,
but the project publishes no key file, only a keyserver instruction (README.md:151-154),
and no keyserver was asked (zpkb sourcepin --sig requires a key file).

SECOND WITNESS, A SECOND INDEPENDENT FETCH: `zpkb sourcepin` of
https://astron.com/pub/file/file-5.48.tar.gz gave 2693209 bytes, sha256 ed146568...,
and a `curl` of https://distfiles.macports.org/file/file-5.48.tar.gz (another host)
gave the same digest.

BUILT AND TESTED ON A MACHINE, NOT BY THE FACTORY: configure, make and make install
of this source, darwin/arm64, with Homebrew's xz and the SDK's zlib and bzip2, all the
switches above. config.h came out with ZLIBSUPPORT, BZLIBSUPPORT, XZLIBSUPPORT and no
zstd, lzip, lrzip or seccomp, and `file -z` read the inside of a .gz, .bz2 and .xz
file. The installed set is bin/file, include/magic.h, lib/libmagic and
lib/pkgconfig/libmagic.pc, share/misc/magic.mgc.

⛔ NOT BUILT BY THE FACTORY, NOT BUILT ON LINUX.
EOT
}
