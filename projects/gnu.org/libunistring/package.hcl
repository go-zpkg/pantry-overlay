# gnu.org/libunistring — Unicode string functions for C. Written because
# rockdaboot.github.io/libpsl requires it: with the libidn2 runtime, libpsl's
# configure.ac:522-528 link-tests u8_tolower and stops if it is missing. It was
# also one of the soname providers `zpkb closure -implicit` named as "no recipe
# declares it".
#
# ⛔ WRITTEN FROM LIBUNISTRING'S OWN FILES (go-zpkg/packages#431), at 1.5.
#
# gnu.org/libidn2 and gnu.org/gettext keep compiling in their OWN bundled
# subsets (--with-included-libunistring). That is unchanged here: this recipe
# is the full library for a consumer that cannot bundle one.

summary = "GNU libunistring: Unicode string functions for C"

# README:48-54: the library and headers are "the GNU LGPLv3+ or the GNU
# GPLv2+". README:66: "The documentation is under another license", and
# doc/libunistring.texi:116-131 says which: the GNU FDL 1.2 or later "with no
# Invariant Sections, with no Front-Cover Text, and with no Back-Cover Texts",
# or the GPL 3 or later. The manual is installed (doc/Makefile.am:38
# info_TEXINFOS, :68 install-data-local: install-html), so it is in the
# expression.
license = "(LGPL-3.0-or-later OR GPL-2.0-or-later) AND (GFDL-1.2-no-invariants-or-later OR GPL-3.0-or-later)"

versions {
  url   = "https://ftp.gnu.org/gnu/libunistring/"
  match = "/libunistring-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = ["/libunistring-/", "/\\.tar\\.xz/"]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/libunistring/libunistring-{{version.raw}}.tar.xz"
  strip-components = 1

  # 2856424 bytes. ⭐ A TWO-HOST CHAIN, the same as gnu.org/gettext's (also
  # Bruno Haible's):
  #
  #   signed by    E0FFBD975397F77A32AB76ECB6301D9E1BBEAC08 (Ed25519), 2026-10-17
  #                Bruno Haible (Free Software Development) <bruno@clisp.org>
  #   fingerprint  https://www.haible.de/bruno/gpgkeys.html lines 12-13
  #   key bytes    https://www.haible.de/bruno/gpgkey-1BBEAC08.asc
  #   tarball      ftp.gnu.org
  #
  # VERIFIED with `zpkb sourcepin --sig auto --fingerprint …` (v0.89.0), and
  # confirmed by a second, independent fetch-and-hash.
  sha256 = {
    "1.5" = "fe89007a8a414ae4790b816b86859e877d3ab135db3c37f06541ff7e85ac344b"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ ICONV: DEPENDENCIES says GNU libiconv is "Not needed on systems with
      # glibc", and AM_ICONV prefers the C library's iconv when it works. But
      # without this flag it ALSO searches the install prefix's include and lib
      # directories for a libiconv (configure:4595-4596), so a builder that has
      # one there links it. Refused: iconv comes from the C library.
      "--without-libiconv-prefix",

      # Named rather than probed: configure:4564 offers isoc, posix, isoc+posix
      # or windows, and the thread API is part of the library's ABI.
      "--enable-threads=posix",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

test {
  fixture = <<EOT
#include <unistr.h>
#include <unicase.h>
#include <string.h>
#include <stdio.h>

int main(void)
{
	/* "ÄÖÜ" in UTF-8, lowered by the full Unicode case mapping. */
	const uint8_t in[] = "\xc3\x84\xc3\x96\xc3\x9c";
	uint8_t buf[16];
	size_t len = sizeof buf;
	uint8_t *out = u8_tolower(in, sizeof in - 1, NULL, NULL, buf, &len);
	if (out == NULL || len != 6 || memcmp(out, "\xc3\xa4\xc3\xb6\xc3\xbc", 6) != 0) {
		fprintf(stderr, "u8_tolower gave %zu bytes\n", len);
		return 1;
	}
	return u8_strlen(in) == 6 ? 0 : 1;
}
EOT

  script = [
    "test -f \"{{prefix}}/include/unistr.h\"",
    "cc -x c $FIXTURE -x none -o t -I{{prefix}}/include -L{{prefix}}/lib -lunistring",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./t
EOT
    },
  ]
}

provenance {
  read = [
    "DEPENDENCIES",             # libiconv "Not needed on systems with glibc"; no other runtime dependency
    "README",                   # :48-54 the dual licence, :66 the documentation's
    "doc/libunistring.texi",    # :116-131 the manual's dual licence
    "doc/Makefile.am",          # :38 the info manual, :68 the HTML, both installed
    "configure",                # :4564 --enable-threads, :4595-4596 the libiconv prefix search
    "https://www.haible.de/bruno/gpgkeys.html", # :12-13 the fingerprint
  ]

  consulted = [
    # The same key chain, already written down for gettext in this tree.
    "go-zpkg/recipes projects/gnu.org/gettext/package.hcl (provenance.note)",
  ]

  note = <<EOT
The chain is the one gnu.org/gettext records, and the strongest kind this
pantry has: the fingerprint and the key bytes come from the maintainer's own
site, the tarball and the signature from ftp.gnu.org. Whoever controls one
host cannot forge what the other vouches for.

⛔ NOT BUILT. No session here can run the factory.
EOT
}
