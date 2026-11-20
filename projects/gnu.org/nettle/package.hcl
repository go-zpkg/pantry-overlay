# gnu.org/nettle — GNU Nettle, a low-level cryptographic library (libnettle,
# and libhogweed for the public-key algorithms) with five small tools. This
# tree carried only a dependency on gmp for it (a fragment, go-zpkg/packages#440
# step 1); this is the whole recipe.
#
# ⛔ WRITTEN FROM NETTLE'S OWN FILES (go-zpkg/packages#431), at 3.10.2.
#
# ⭐ WHAT WRITING IT FOUND: three things configure decides by looking at the
# builder, each named below.
#   documentation  configure.ac:1143-1156 builds the manual only when `makeinfo`
#                  is found ("auto"), so the installed files differ by builder.
#   openssl        :1181-1207, found and linked into the benchmark program, which
#                  is not installed: a builder-dependent probe with no effect on
#                  the artifact, closed anyway.
#   gmp            hogweed (RSA, DSA, ECDSA, curve25519...) exists only with
#                  GMP (README:34-35); the test links libhogweed.
# 4.0 is out (ftp.gnu.org/gnu/nettle/): a new major, not pinned here; the version
# match below is the 3.x series.

summary = "GNU Nettle: low-level cryptographic library (nettle and hogweed) and tools"

# Every source read carries "either: the GNU LGPL version 3 or later, or the GNU
# GPL version 2 or later, or both in parallel" (nettle-types.h:5-20,
# tools/nettle-hash.c:7-22); COPYING.LESSERv3, COPYINGv2 and COPYINGv3 are shipped.
# NOT READ: the assembler files under each architecture directory and
# the files that README:27-29 leaves to the manual's licence section.
license = "LGPL-3.0-or-later OR GPL-2.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/nettle/"
  match = "/nettle-3\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = ["/nettle-/", "/\\.tar\\.gz/"]
}

dependencies = {
  # hogweed is built with it (see the header) and the test reads it back.
  "gnu.org/gmp" = "^6"
}

distributable {
  # 2644644 bytes. Recorded with `zpkb sourcepin --sig` (signature verified, see
  # provenance.note) and confirmed by a second, independent fetch-and-hash
  # (curl + shasum -a 256).
  url              = "https://ftp.gnu.org/gnu/nettle/nettle-{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "3.10.2" = "fe9ff51cb1f2abb5e65a6b8c10a92da0ab5ab6eaf26e7fc2b675c45f1fb519b5"
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

      # ⛔ gmp, BY DIRECTORY (configure.ac:28-42), and the public-key algorithms
      # named ON (:44-46, the default).
      "--with-include-path={{deps.gnu.org/gmp.prefix}}/include",
      "--with-lib-path={{deps.gnu.org/gmp.prefix}}/lib",
      "--enable-public-key",

      # CLOSED: the manual needs `makeinfo` (:1143-1156) and the benchmark's
      # OpenSSL glue is not installed (:1181-1207). The assembler is chosen by the
      # build ARCHITECTURE (:129 onwards), not by a tool the builder has, and the
      # fat library (:76-77, the default) dispatches on the CPU at run time.
      "--disable-documentation",
      "--disable-openssl",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# tools/Makefile.in:21: sexp-conv nettle-hash nettle-pbkdf2 nettle-lfib-stream
# pkcs1-conv.
provides = [
  "bin/nettle-hash",
  "bin/nettle-lfib-stream",
  "bin/nettle-pbkdf2",
  "bin/pkcs1-conv",
  "bin/sexp-conv",
]

test {
  fixture = <<EOT
#include <nettle/rsa.h>
#include <nettle/version.h>
#include <stdio.h>

int main(void)
{
	struct rsa_public_key pub;
	if (nettle_version_major() != NETTLE_VERSION_MAJOR || nettle_version_minor() != NETTLE_VERSION_MINOR) {
		fprintf(stderr, "library %d.%d, header %d.%d\n", nettle_version_major(), nettle_version_minor(), NETTLE_VERSION_MAJOR, NETTLE_VERSION_MINOR);
		return 1;
	}
	/* hogweed, which needs GMP: present only when the public-key algorithms were built */
	nettle_rsa_public_key_init(&pub);
	nettle_rsa_public_key_clear(&pub);
	return 0;
}
EOT

  script = [
    {
      run = <<EOT2
set -eu
# nettle-hash on a known vector (FIPS 180: SHA-256 of "abc").
printf abc > abc.txt
nettle-hash -a sha256 abc.txt > hash.txt
grep -q 'ba7816bf8f01cfea 414140de5dae2223 b00361a396177a9c b410ff61f20015ad sha256' hash.txt
nettle-hash -V | grep -q '(nettle {{version.raw}})'

# libnettle and libhogweed, linked through the installed headers.
cc -x c $FIXTURE -x none -o probe -I{{prefix}}/include -L{{prefix}}/lib -I{{deps.gnu.org/gmp.prefix}}/include -L{{deps.gnu.org/gmp.prefix}}/lib -lhogweed -lnettle -lgmp
LD_LIBRARY_PATH="{{prefix}}/lib:{{deps.gnu.org/gmp.prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:{{deps.gnu.org/gmp.prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./probe
grep -q '^Version: {{version.raw}}' {{prefix}}/lib/pkgconfig/hogweed.pc
EOT2
    },
  ]
}

provenance {
  read = [
    "configure.ac",         # :28-42 include/lib path, :44-46 public-key, :64-66 openssl, :72-74 and :1143-1156 documentation, :76-77 fat, :123-125 mini-gmp, :1181-1207 openssl probe
    "tools/Makefile.in",    # :21 the installed programs
    "README",               # :27-35 licence pointer, GMP for public key
    "nettle-types.h",       # :5-20 the dual licence notice
    "tools/nettle-hash.c",  # :7-22 the same notice
    "COPYING.LESSERv3",
    "COPYINGv2",
    "COPYINGv3",
    "https://ftp.gnu.org/gnu/nettle/",             # the release listing and the .sig beside the archive
    "https://www.lysator.liu.se/~nisse/nettle/",    # the project's page: the signing key's fingerprint
  ]

  consulted = [
    # None: the upstream recipe was not opened for this one.
  ]

  note = <<EOT
SIGNATURE VERIFIED, against the fingerprint the project's own page names.

  signature   https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz.sig
  signed at   2025-06-26T18:41:09Z
  signer      Niels Möller <nisse@lysator.liu.se>
  fingerprint 343C2FF0FBEE5EC2EDBEF399F3599FF828C67298
  fingerprint from  https://www.lysator.liu.se/~nisse/nettle/ ("Recent releases
              are signed with the following PGP key", the nettle project's page)
  key bytes   https://keys.openpgp.org/vks/v1/by-fingerprint/343C2FF0FBEE5EC2EDBEF399F3599FF828C67298,
              used ONLY as a carrier: the bytes are accepted because their
              fingerprint is the one the project's page names (zpkb
              sourcepin --fingerprint reads only that key), never because a
              keyserver returned them.

The copy of this key in ftp.gnu.org/gnu/gnu-keyring.gpg is EXPIRED at the signing
instant (zpkb: "key expired, judged at 2025-06-26T18:41:09Z"), which is why the
keyring was not used. The second, independent check is curl + `shasum -a 256` of
the archive: same digest. zpkb v0.92.0 verified it.

BUILT AND TESTED ON A MACHINE, NOT BY THE FACTORY: ./configure with --enable-public-key
and gmp passed by path, make and make install on this source, darwin/arm64 (Homebrew
gmp): installed libnettle, libhogweed (both shared and static), the five tools and
nettle.pc/hogweed.pc; `nettle-hash -a sha256` of "abc" printed the FIPS 180 vector.
--disable-documentation and --disable-openssl were not part of that run (it used the
defaults, with makeinfo and openssl absent or unused), so their effect is read from
configure.ac.

⛔ NOT BUILT BY THE FACTORY, NOT BUILT ON LINUX. No session here can run it.
EOT
}
