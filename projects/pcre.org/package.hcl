# pcre.org — PCRE 8.x ("PCRE1"), the original Perl-compatible regular
# expression library, with pcregrep and pcretest. Written whole from PCRE's own
# files at 8.45 (go-zpkg/packages#440 step 1); there was no recipe for it.
#
# ⛔ END OF LIFE, AND SAID BY THE PROJECT. 8.45 is the last release of the 8.x
# series; the project moved to PCRE2 (projects/pcre.org/v2 in this tree). It
# exists here because recipes still name "pcre.org" = ^8 (openresty.org, and
# github.com/10gic/vanitygen-plusplus whose code includes <pcre.h> and is not
# ported to PCRE2). It is the 8.x line at the path `pcre.org`, beside the 10.x
# line at `pcre.org/v2`; the two install different headers and libraries
# (libpcre vs libpcre2-8), so they do not collide.
#
# ⚠ THE VERSIONS ARE A FIXED LIST, NOT A LISTING: the project's home moved off
# its own server (the ftp.pcre.org host did not answer when this was written)
# and the sourceforge mirror is a download redirector, not an enumeration, and
# 8.45 is final. `versions` therefore names the one release.
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "PCRE 8.x (end of life): Perl-compatible regular expressions, with pcregrep and pcretest"

# LICENCE:7 "Release 8 of PCRE is distributed under the terms of the "BSD"
# licence, as specified below." The three-clause text (University of Cambridge,
# Zoltan Herczeg's JIT, and the Google C++ wrapper) is in LICENCE.
license = "BSD-3-Clause"

versions = ["8.45"]

distributable {
  url              = "https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-{{version.raw}}.tar.bz2/download"
  strip-components = 1

  # 1578809 bytes, recorded with `zpkb sourcepin` (v0.97.0) from the sourceforge
  # URL above. Second witness: an INDEPENDENT fetch from a different host,
  # https://ftp.exim.org/pub/pcre/pcre-8.45.tar.bz2 (exim.org mirrors the
  # project's directory), shasum -a 256: the same digest.
  #
  # ⛔ A SIGNATURE EXISTS AND IS NOT USED. The release has pcre-8.45.tar.bz2.sig
  # (310 bytes, fetched from sourceforge), but no public key for it is
  # published by the project anywhere this tree reads (a keyserver is not read),
  # so it could not be checked and is not offered as proof.
  sha256 = {
    "8.45" = "4dae6fdcd2bb0bb6c37b5f97c33c2be954da743985369cddac3546e3218bffb8"
  }
}

dependencies = {
  # pcregrep reads .gz and .bz2 only through these two, and the switches below
  # ask for both.
  "zlib.net"             = "^1"
  "sourceware.org/bzip2" = "^1"
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    linux = {
      # `--enable-cpp` (configure.ac:146, on by default) builds libpcrecpp with
      # a C++ compiler.
      "gnu.org/gcc" = "*"
    }
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # Every optional feature is named (configure.ac:124-279), because each
      # `unset`/`no` default is resolved by configure from the build host's
      # probes or from the lines below, and a recipe that is silent publishes
      # whatever the host happens to have.

      # 8-bit library on (default, configure.ac:124-127), 16- and 32-bit off by
      # default (:130-142); consumers of 8.x in this tree use the 8-bit one, and
      # libpcre16/32 are what a downstream opts into, so they are on.
      "--enable-pcre8",
      "--enable-pcre16",
      "--enable-pcre32",

      # C++ wrapper (libpcrecpp), on by default (:146-150): kept on.
      "--enable-cpp",

      # ⛔ JIT is OFF by default (:152-156) and `auto` is a HARDWARE probe
      # (:158-171, SLJIT_CONFIG_AUTO against the building machine), which
      # would publish a different artifact per builder. The bare flag is `yes`
      # and deterministic. pcregrep uses it when present (:173-177, default yes).
      "--enable-jit",

      # UTF-8/16/32 and Unicode properties are OFF by default (:185-201).
      # Without them \p{L} and (*UTF8) do not work, which is what consumers
      # expect of a regex library; `--enable-unicode-properties` implies
      # `--enable-utf`, both named.
      "--enable-utf",
      "--enable-unicode-properties",

      # pcregrep's compressed-file support, off by default (:251-261); naming
      # them is what asks for the feature (whether 8.45's configure refuses or
      # silently downgrades when the library is missing was not read).
      "--enable-pcregrep-libz",
      "--enable-pcregrep-libbz2",

      # pcretest's line editing: both off by default (:269-279), named off so a
      # readline or libedit on the build host is not linked.
      "--disable-pcretest-libedit",
      "--disable-pcretest-libreadline",

      # Static AND shared libraries is libtool's default; not changed.
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",

    # ⛔ `pcre-config` BAKES THE BUILD PREFIX IN (pcre-config.in:3 is
    # `prefix=@prefix@`), the same shape as pcre.org/v2's pcre2-config, and a
    # store path baked in is refused by `zpkb bakedpaths`. It is rewritten to
    # its own location, as that recipe does.
    {
      run               = <<EOT
sed -i.bak -e 's|^prefix=.*|prefix=$(cd "$(dirname "$0")/.." \&\& pwd)|' pcre-config
rm -f pcre-config.bak
EOT
      working-directory = "{{prefix}}/bin"
    },
  ]
}

# pcre-config (Makefile.am:195 bin_SCRIPTS) is installed and NOT promised, for
# the reason pcre.org/v2 gives: it is a /bin/sh script (pcre-config.in:1). The
# two programs are Makefile.am:493 `bin_PROGRAMS += pcretest` and :520
# `bin_PROGRAMS += pcregrep`.
provides = [
  "bin/pcregrep",
  "bin/pcretest",
]

test {
  script = [
    "test -f \"{{prefix}}/include/pcre.h\"",
    "test -f \"{{prefix}}/include/pcrecpp.h\"",
    {
      run = <<EOT
set -eu
for l in pcre pcre16 pcre32 pcreposix pcrecpp; do
  ls "{{prefix}}"/lib/lib$l.* >/dev/null || { echo "lib$l missing" >&2; exit 1; }
  test -f "{{prefix}}/lib/pkgconfig/lib$l.pc"
done
EOT
    },

    # The build options asserted on BEHAVIOUR, from `pcretest -C <option>`
    # (pcretest.c:3209-3279): each prints 1 or 0 and exits with that value, so
    # `|| true` keeps the 1 from ending the script and the output is compared.
    {
      run = <<EOT
set -eu
for o in pcre8 pcre16 pcre32 utf ucp jit; do
  R="$("{{prefix}}/bin/pcretest" -C $o || true)"
  if [ "$R" != "1" ]; then echo "pcretest -C $o printed '$R', not 1" >&2; exit 1; fi
done
EOT
    },

    # It has to match and it has to refuse.
    {
      run = <<EOT
set -eu
printf 'the quick brown fox\n' > subject.txt
"{{prefix}}/bin/pcregrep" 'qu\w+k' subject.txt > /dev/null
if "{{prefix}}/bin/pcregrep" 'zzz\d+' subject.txt > /dev/null 2>&1; then
  echo "pcregrep matched a pattern that is not there" >&2
  exit 1
fi
# Unicode properties are not optional for consumers.
printf 'héllo\n' > utf.txt
"{{prefix}}/bin/pcregrep" -u '\p{L}+' utf.txt > /dev/null
EOT
    },
  ]
}

provenance {
  read = [
    "LICENCE",         # :7 "Release 8 of PCRE is distributed under the terms of the "BSD" licence"; copyright holders Cambridge, Herczeg
    "configure.ac",    # :124-279 every AC_ARG_ENABLE/WITH and its default; :158-171 jit=auto is a hardware probe
    "Makefile.am",     # :195 bin_SCRIPTS = pcre-config; :225-448 the five libraries; :493 pcretest, :520 pcregrep; :666-674 the .pc files
    "pcre-config.in",  # :1 #!/bin/sh; :3 prefix=@prefix@
    "pcretest.c",      # :3209-3279 `-C pcre8|pcre16|pcre32|utf|ucp|jit` print 1/0 and exit with it
  ]

  consulted = [
    "pcre.org/v2 in this tree",  # the pcre-config rewrite and the dependency pair, copied
  ]

  note = <<EOT
⚠ THE SOURCE RUNG: two independent hosts agree on the digest (sourceforge and
ftp.exim.org). The release signature could not be checked for want of a
published key, and is not used.

⚠ THE FIXED VERSION LIST is a decision, stated in the header.

⚠ SELECTED BY READING, NOT TRIED: that 8.45's generated configure accepts every
switch named above (they were read from configure.ac, not from the generated
script); that libpcrecpp builds with the toolchain of this tree; that pcre-config
is rewritten correctly by the sed copied from pcre.org/v2.

⛔ NOT BUILT by the factory, and not by hand. Lint only. The first factory run is
this file's test.
EOT
}
