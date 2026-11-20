# gnu.org/libiconv — GNU libiconv: the iconv(3) character set conversion
# library, libcharset, and the `iconv` program. This tree carried only a
# darwin dependency on gettext for it (a fragment, go-zpkg/packages#440 step 1);
# this is the whole recipe.
#
# ⛔ WRITTEN FROM LIBICONV'S OWN FILES (go-zpkg/packages#431), at 1.19.1.
#
# ⭐ WHAT WRITING IT FOUND: one switch decides which encodings the library
# knows, and it defaults to the SMALLER set: --enable-extra-encodings
# (configure.ac:61-67) adds EUC-JISX0213, SHIFT_JISX0213, ISO-2022-JP-3,
# BIG5-2003 and the rest of lib/encodings_extra.def. Named here, and the test
# asks the installed library to open one of them. The other probe is NLS
# (AM_GNU_GETTEXT, configure.ac:102): on darwin it needs libintl, which the
# fragment's gettext dependency supplies, named by prefix below; glibc has
# gettext built in.

summary = "GNU libiconv: character set conversion library and the iconv program"

# README:149-152 — "The libiconv and libcharset _libraries_ and their header
# files are under LGPL ... The iconv _program_ and the documentation are under
# GPL": lib/iconv.c:5-8 is the GNU LGPL "version 2.1 ... or (at your option) any
# later version", libcharset/lib/localcharset.c:5-8 the LGPL "version 2, or (at
# your option) any later version", and src/iconv.c:4-7 the GNU GPL "version 3 ...
# or (at your option) any later version". NOT READ: the gnulib files in srclib/
# (each carries its own notice), the documentation's licence text beyond the
# README's sentence.
license = "LGPL-2.1-or-later AND LGPL-2.0-or-later AND GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/libiconv/"
  match = "/libiconv-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = ["/libiconv-/", "/\\.tar\\.gz/"]
}

dependencies {
  darwin = {
    "gnu.org/gettext" = "^1"
  }
}

distributable {
  # 5895620 bytes. Recorded with `zpkb sourcepin --sig` (signature verified, see
  # provenance.note) and confirmed by a second, independent fetch-and-hash
  # (curl + shasum -a 256).
  url              = "https://ftp.gnu.org/gnu/libiconv/libiconv-{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "1.19.1" = "9a06844846d664d7122161700c10a64480d7c7bcead3091925a785b38c91edab"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir={{prefix}}/lib",

      # configure.ac:61-67: off by default; see the header.
      "--enable-extra-encodings",
    ]

    darwin = {
      # AM_GNU_GETTEXT([external]): found by prefix, not by whatever the builder has.
      ARGS = [
        "--with-libintl-prefix={{deps.gnu.org/gettext.prefix}}",
      ]
    }
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = [
  "bin/iconv",
]

test {
  # include/iconv.h:27 defines _LIBICONV_VERSION 0x0113 at 1.19; its macros
  # rename iconv_open to libiconv_open, so a program linked with -liconv uses
  # THIS library and not the C library's.
  fixture = <<EOT
#include <iconv.h>
#include <localcharset.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
	char in[] = "caf\303\251";
	char out[16];
	char *ip = in, *op = out;
	size_t il = strlen(in), ol = sizeof out;
	iconv_t cd;

	if (_libiconv_version != 0x0113) { fprintf(stderr, "version %#x\n", _libiconv_version); return 1; }

	cd = iconv_open("ISO-8859-1", "UTF-8");
	if (cd == (iconv_t)-1) { perror("iconv_open ISO-8859-1"); return 1; }
	if (iconv(cd, &ip, &il, &op, &ol) == (size_t)-1) { perror("iconv"); return 1; }
	iconv_close(cd);
	if (op - out != 4 || memcmp(out, "caf\351", 4) != 0) { fprintf(stderr, "wrong bytes\n"); return 1; }

	/* an encoding that exists only with --enable-extra-encodings */
	cd = iconv_open("BIG5-2003", "UTF-8");
	if (cd == (iconv_t)-1) { perror("iconv_open BIG5-2003"); return 1; }
	iconv_close(cd);

	if (locale_charset() == NULL) return 1;
	return 0;
}
EOT

  script = [
    "iconv --version | grep -q '^iconv (GNU libiconv 1\\.19)'",
    {
      run = <<EOT2
set -eu
printf 'caf\303\251\n' > in.txt
iconv -f UTF-8 -t ISO-8859-1 in.txt > out.txt
printf 'caf\351\n' > want.txt
cmp out.txt want.txt
# the extra encodings are listed by the program too
iconv -l | grep -q 'BIG5-2003'
cc -x c $FIXTURE -x none -o probe -I{{prefix}}/include -L{{prefix}}/lib -liconv
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./probe
EOT2
    },
  ]
}

provenance {
  read = [
    "configure.ac",                  # :61-67 extra encodings, :58 LT_INIT disable-static, :101-102 AM_ICONV and AM_GNU_GETTEXT
    "lib/encodings_extra.def",       # :18-39 the encodings the switch adds
    "include/iconv.h",               # :27 _LIBICONV_VERSION
    "README",                        # :149-152 which parts are LGPL and GPL
    "lib/iconv.c",                   # :1-14 the LGPL 2.1+ notice
    "libcharset/lib/localcharset.c", # :1-14 the LGPL 2+ notice
    "src/iconv.c",                   # :1-15 the GPL 3+ notice
    "COPYING",                       # GPL 3
    "COPYING.LIB",                   # LGPL 2.1
    "https://ftp.gnu.org/gnu/libiconv/",          # the release listing and the .sig beside the archive
    "https://ftp.gnu.org/gnu/gnu-keyring.gpg",     # the signer's key
  ]

  consulted = [
    # None: the upstream recipe was not opened for this one.
  ]

  note = <<EOT
SIGNATURE VERIFIED, against a key from GNU's maintainer keyring.

  signature   https://ftp.gnu.org/gnu/libiconv/libiconv-1.19.1.tar.gz.sig
  signed at   2026-10-31T14:44:35Z
  signer      Bruno Haible (Free Software Development) <bruno@clisp.org>
  fingerprint E0FFBD975397F77A32AB76ECB6301D9E1BBEAC08
  key from    https://ftp.gnu.org/gnu/gnu-keyring.gpg, found after walking 596
              primary keys

⚠ THE RUNG, STATED: the fingerprint was read from the signature's own issuer
field (`gpg --list-packets`: issuer fpr v4) and found in GNU's keyring, so the
warrant is GNU's curation of that keyring — on the same host as the tarball:
continuity, not independence (the limit gnu.org/gperf, signed by the same key,
records too). No page of the libiconv project naming the fingerprint was found.
The second, independent check is curl + `shasum -a 256` of the archive: same
digest. zpkb v0.92.0 verified it.

BUILT AND TESTED ON A MACHINE, NOT BY THE FACTORY: ./configure --enable-extra-encodings
--with-libintl-prefix=<gettext>, make and make install on this source, darwin/arm64:
`iconv --version` printed "iconv (GNU libiconv 1.19)", UTF-8 to ISO-8859-1 of "café"
gave 63 61 66 e9 0a, and `iconv -l` listed BIG5-2003.

⛔ NOT BUILT BY THE FACTORY, NOT BUILT ON LINUX. No session here can run it.
EOT
}
