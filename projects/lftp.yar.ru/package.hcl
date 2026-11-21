# lftp.yar.ru — lftp, the sophisticated command-line file transfer program (FTP,
# FTPS, HTTP, SFTP, FISH, BitTorrent). This tree carried only a dependency list for
# it (a fragment, go-zpkg/packages#440 step 1); this is the whole recipe.
#
# ⛔ WRITTEN FROM LFTP'S OWN FILES, at 4.9.3.
#
# ⭐⭐ WHAT WRITING IT FOUND: lftp's TLS library is chosen by a DEFAULT THAT NEEDS A
# PACKAGE NOBODY HERE PROVIDES.
#   configure.ac:282-283  `--without-gnutls` defaults to gnutls=yes, found through
#                         pkg-config (:295-302); a miss is silent (no TLS at all).
#   configure.ac:284-294  `--with-openssl[=DIR]` defaults to NO, and a yes turns
#                         gnutls off (:289, :293).
# gnutls.org has no recipe in this tree, so the build asks for OpenSSL BY DIRECTORY
# and gnutls off, and the test reads `ftps` back from `lftp --version`.
# The other probes, each named on or off below:
#   readline   m4/lftp_lib_readline.m4:47-114  `--with-readline=DIR`; configure.ac
#              :277-280 makes a miss FATAL.
#   expat      m4/ax_lib_expat.m4:52-121  `--with-expat=DIR`; a miss is silent
#              (configure.ac:316-319 only defines HAVE_LIBEXPAT when found) and costs
#              the BitTorrent/WebDAV XML parsing.
#   zlib       m4/ax_check_zlib.m4:74-90  `--with-zlib=DIR`; a miss is FATAL (:313).
#   libidn2    m4/lftp.m4:317-337  `--with-libidn2=DIR`; a miss is a WARNING.
#   socks, dnssec-local-validation, modules: all default off (configure.ac:159-170,
#              :220-223, :322-323); named off below.

summary = "lftp: sophisticated command-line file transfer program (FTP, FTPS, HTTP, SFTP, torrent)"

# COPYING is the GNU GPL; README:163-178 says "version 3 of the License, or (at your
# option) any later version". README:71-73 notes the OpenSSL advertising clause.
license = "GPL-3.0-or-later"

versions {
  url = "https://lftp.yar.ru/ftp/"

  # The directory lists lftp-X.Y.Z.tar.xz, .tar.gz, .tar.bz2 and their signatures:
  # the .tar.xz is the one pinned.
  match = "/lftp-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = ["/lftp-/", "/\\.tar\\.xz/"]
}

dependencies = {
  "gnu.org/gettext"              = "*"
  "gnu.org/libidn2"              = "*"
  "gnu.org/readline"             = "*"
  "invisible-island.net/ncurses" = "*"
  "libexpat.github.io"           = "*"
  linux = {
    "gnu.org/gcc/libstdcxx" = 14
  }
  "openssl.org" = "^3"
  "zlib.net"    = "*"
}

distributable {
  # 1872104 bytes. NO SIGNATURE WAS VERIFIED, AND THAT IS WHAT IS RECORDED HERE: the
  # release carries lftp-4.9.3.tar.xz.asc, whose packet names issuer fingerprint
  # C027FA3148652A5513036413A824BB69F2A99A18, but that key is not obtainable without
  # a keyserver (the site publishes none) and no keyserver is asked. The second
  # witness is an independent fetch: NetBSD's pkgsrc distfiles mirror
  # (ftp.netbsd.org/pub/pkgsrc/distfiles/) served the same bytes, same SHA-256.
  url              = "https://lftp.yar.ru/ftp/lftp-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "4.9.3" = "96e7199d7935be33cf6b1161e955b2aab40ab77ecdf2a19cea4fc1193f457edc"
  }
}

build {
  dependencies = {
    "gnu.org/gettext" = "*"
    "gnu.org/make"    = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ TLS: OpenSSL by directory, gnutls off (see the header).
      "--with-openssl={{deps.openssl.org.prefix}}",
      "--without-gnutls",

      # ON, by directory (each is a silent or fatal probe, see the header).
      "--with-readline={{deps.gnu.org/readline.prefix}}",
      "--with-expat={{deps.libexpat.github.io.prefix}}",
      "--with-zlib={{deps.zlib.net.prefix}}",
      "--with-libidn2={{deps.gnu.org/libidn2.prefix}}",

      # ⛔ OFF: socks libraries (configure.ac:159-170) are not provided here;
      # DNSSEC validation needs dnssec-tools' libval (:322-345); modules would make
      # the protocols dlopen'd files (:220-233).
      "--without-socks",
      "--without-dnssec-local-validation",
      "--without-modules",
    ]

    # ⛔ The sources say `#include <readline/readline.h>` (src/lftp_rl.c:24-25,
    # src/complete.cc:50) while m4/lftp_lib_readline.m4:105-109 gives the compiler
    # `-I<prefix>/include/readline`, which does not answer that path: on macOS the
    # SDK's libedit readline/readline.h answered instead and the build failed in
    # lftp_rl.c (add_history_time, rl_expand_prompt, ... undeclared). So the include
    # directory itself comes first. The same for OpenSSL: src/lftp_ssl.h:27 includes
    # <openssl/ssl.h> in FileAccess.cc, a unit that is not given OPENSSL_CPPFLAGS.
    CPPFLAGS = "-I{{deps.gnu.org/readline.prefix}}/include -I{{deps.openssl.org.prefix}}/include -I{{deps.invisible-island.net/ncurses.prefix}}/include -I{{deps.gnu.org/gettext.prefix}}/include"
    LDFLAGS  = "-L{{deps.openssl.org.prefix}}/lib -L{{deps.invisible-island.net/ncurses.prefix}}/lib -L{{deps.gnu.org/gettext.prefix}}/lib"

    linux = {
      LDFLAGS = "-L{{deps.openssl.org.prefix}}/lib -L{{deps.invisible-island.net/ncurses.prefix}}/lib -L{{deps.gnu.org/gettext.prefix}}/lib -Wl,-rpath,{{deps.invisible-island.net/ncurses.prefix}}/lib -Wl,-rpath,{{deps.gnu.org/readline.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.libexpat.github.io.prefix}}/lib -Wl,-rpath,{{deps.zlib.net.prefix}}/lib -Wl,-rpath,{{deps.gnu.org/libidn2.prefix}}/lib"
    }
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = [
  "bin/lftp",
  "bin/lftpget",
]

test {
  script = [
    {
      run = <<EOT
set -eu
"{{prefix}}/bin/lftp" --version > version.txt 2>&1
grep -q 'LFTP | Version {{version.raw}} ' version.txt
# the library list is the only place the choices show: each probe that falls back
# silently (expat configure.ac:316-319, libidn2 m4/lftp.m4:333) would drop its name
grep -q 'OpenSSL 3' version.txt
grep -q 'Expat' version.txt
grep -q 'idn2' version.txt
grep -q 'Readline' version.txt
"{{prefix}}/bin/lftp" -c 'help' > help.txt 2>&1
grep -q 'mirror' help.txt
test -x "{{prefix}}/bin/lftpget"
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                  # :282-305 gnutls/openssl, :276-280 readline, :307-319 zlib, expat, :159-170 socks, :220-233 modules, :322-345 dnssec
    "m4/ssl.m4",                     # :1-42 the OpenSSL probe, by directory
    "m4/lftp_lib_readline.m4",       # :47-114 --with-readline
    "m4/ax_lib_expat.m4",            # :52-121 --with-expat
    "m4/ax_check_zlib.m4",           # :74-90 --with-zlib
    "m4/lftp.m4",                    # :317-337 libidn2
    "README",                        # :71-73 OpenSSL notice, :163-178 the licence
    "COPYING",                       # GNU GPL
  ]

  consulted = []

  note = <<EOT
NO SIGNATURE WAS VERIFIED: lftp-4.9.3.tar.xz.asc names issuer fingerprint
C027FA3148652A5513036413A824BB69F2A99A18, and the key is not obtainable without a
keyserver (none is asked). The pin is a SHA-256 computed by fetching from
lftp.yar.ru and agreed by a second fetch from NetBSD's pkgsrc distfiles mirror
(96e7199d... both).

BUILT AND TESTED ON A MACHINE, NOT BY THE FACTORY: configure, make and make install
of this source, darwin/arm64, with Homebrew's openssl 3, readline, ncurses, gettext
and libidn2 by directory, and the macOS SDK's expat and zlib exposed through a
directory holding only their headers. `lftp --version` printed "Libraries used:
Expat, idn2, OpenSSL 3.6.5, Readline 8.3, zlib"; config.h had USE_OPENSSL,
HAVE_LIBEXPAT and LIBIDN2 defined and USE_GNUTLS undefined. The first two attempts
failed (libedit's readline.h picked, then openssl/ssl.h missing); the CPPFLAGS above
are the fix.

⛔ NOT BUILT BY THE FACTORY, NOT BUILT ON LINUX.
EOT
}
