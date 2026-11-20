# rockdaboot.github.io/libpsl — the Public Suffix List library. curl.se
# declares it now. Until this recipe, curl passed --without-libpsl, which was a
# STATED DOWNGRADE: cookies could be set on a public suffix such as `co.uk`.
# The owner's decision, 2026-11-20: « pour tcl comme x11 comme libpsl, il faut
# que ça fonctionne ».
#
# ⛔ WRITTEN FROM LIBPSL'S OWN FILES (go-zpkg/packages#431), at 0.23.3.
#
# ⭐⭐ WHY THE CLOSURE NO LONGER GROWS BY SIXTEEN. Declaring libpsl was
# measured at 77 → 93 projects. That came from upstream's recipe, not from
# libpsl: it builds with meson + ninja + python and picks ICU as the IDNA
# runtime (-Druntime=libicu), which brings unicode.org. libpsl's own tarball
# needs none of that:
#
#   - it ships an autotools `configure`;
#   - it ships the generated DAFSA data, so configure.ac:89-91 never asks for
#     python;
#   - libidn2, which this tree already has (go-zpkg/recipes#173) and which
#     curl and wget already use, is a supported runtime.

summary = "libpsl: C library to handle the Public Suffix List"

# LICENSE / COPYING: MIT. The builtin data is compiled from
# list/public_suffix_list.dat, whose lines 1-3 put it under the Mozilla Public
# License 2.0, so the MPL is in the artifact too.
license = "MIT AND MPL-2.0"

versions {
  github = "rockdaboot/libpsl"
}

dependencies = {
  # ⛔ THE IDNA RUNTIME, AND WHAT IT DRAGS IN. configure.ac:148-171: the default
  # `auto` takes libidn2 if found (:325-328), else ICU (:336-…), else libidn,
  # else NO runtime (:506) — so the library and its behaviour on
  # non-ASCII domains depend on the builder. Named below; :330-331 then makes
  # a missing libidn2 fatal.
  "gnu.org/libidn2" = "*"

  # configure.ac:508-531: with libidn2 as the runtime, libunistring is
  # link-tested (u8_tolower) and missing is FATAL (:527). libidn2 compiles in
  # its own subset, which does not help a second library, hence its own recipe.
  "gnu.org/libunistring" = "*"

  # configure.ac:52 AM_GNU_GETTEXT([external]) for the `psl` tool's messages;
  # the same treatment as gnu.org/libidn2.
  "gnu.org/gettext" = "*"
}

distributable {
  # The maintainer's release tarball (a release asset, with a .sig beside it).
  # It is NOT GitHub's generated archive, which lacks `configure` and the
  # DAFSA data.
  url              = "https://github.com/rockdaboot/libpsl/releases/download/{{version.raw}}/libpsl-{{version.raw}}.tar.gz"
  strip-components = 1

  # 7830615 bytes. VERIFIED — see provenance.note for the two hosts — and
  # confirmed by a second, independent fetch-and-hash.
  sha256 = {
    "0.23.3" = "93941f85a1e7bd593fa94f299233cb5dfc91cd144fd9a78a6ceb75001c5b03be"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    # configure.ac:276 finds libidn2 through PKG_CHECK_MODULES.
    "freedesktop.org/pkg-config" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # Named: see dependencies. `auto` would also fall through to ICU or to
      # nothing without failing.
      "--enable-runtime=libidn2",

      # The builtin list (configure.ac:175-189, already the default), from the
      # pre-generated src/suffixes_dafsa.h the tarball ships.
      "--enable-builtin",

      "--with-libintl-prefix={{deps.gnu.org/gettext.prefix}}",

      # ⛔ Refused: the install prefix searched for a libiconv the builder may
      # have. iconv comes from the C library (glibc, musl), as for
      # gnu.org/libunistring.
      "--without-libiconv-prefix",

      # gtk-doc (configure.ac:59-71) and man pages (:76-86, which need xsltproc)
      # are off by default; named so a changed default shows here.
      "--disable-gtk-doc",
      "--disable-man",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = [
  "bin/psl",
]

test {
  fixture = <<EOT
#include <libpsl.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
	const psl_ctx_t *psl = psl_builtin();
	char *lower = NULL;
	int bad = 0;

	if (psl == NULL) {
		fprintf(stderr, "no builtin list\n");
		return 1;
	}
	/* The reason curl wants it: a cookie must not be set on a public suffix. */
	if (!psl_is_public_suffix(psl, "co.uk")) { fprintf(stderr, "co.uk is not public\n"); bad = 1; }
	if (psl_is_public_suffix(psl, "example.co.uk")) { fprintf(stderr, "example.co.uk is public\n"); bad = 1; }
	if (strcmp(psl_registrable_domain(psl, "www.example.co.uk"), "example.co.uk") != 0) {
		fprintf(stderr, "wrong registrable domain\n"); bad = 1;
	}
	/* The RUNTIME: lowering a non-ASCII name needs the IDNA library. With no
	   runtime, src/psl.c:1897 leaves ret = PSL_ERR_INVALID_ARG and every
	   #if WITH_* branch after the ASCII shortcut (:1906-1921) is compiled out. */
	if (psl_str_to_utf8lower("\xc3\x84XAMPLE.DE", NULL, NULL, &lower) != PSL_SUCCESS
	    || strcmp(lower, "\xc3\xa4xample.de") != 0) {
		fprintf(stderr, "no IDNA runtime: psl_str_to_utf8lower failed\n"); bad = 1;
	}
	psl_free_string(lower);
	return bad;
}
EOT

  script = [
    "cc -x c $FIXTURE -x none -o t -I{{prefix}}/include -L{{prefix}}/lib -lpsl",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./t
EOT
    },

    # The runtime is ALSO legible in the installed .pc: configure.ac:550-552
    # writes `Requires.private: libidn2` exactly when the runtime is libidn2.
    "grep -E '^Requires.private:.*libidn2' {{prefix}}/lib/pkgconfig/libpsl.pc",

    "psl --version",
  ]
}

provenance {
  read = [
    "configure.ac",                 # :33-36 iconv and libunistring; :52 gettext; :59-86 gtk-doc and man; :89-91 python only without the DAFSA files; :148-189 runtime and builtin; :263-333 libidn2, fatal when named; :506 auto falls to none; :508-531 libunistring fatal; :549-552 the .pc
    "LICENSE",                      # MIT
    "list/public_suffix_list.dat",  # :1-3 MPL-2.0
    "src/suffixes_dafsa.h",         # shipped, 347477 bytes, so no python
    "README.md",
  ]

  consulted = [
    # Read for facts only: meson, python and `-Druntime=libicu`, which is
    # where the closure's sixteen extra projects came from. Nothing copied.
    "pkgxdev/pantry projects/rockdaboot.github.io/libpsl/package.yml",
  ]

  note = <<EOT
⭐ TWO HOSTS FOR THE KEY, AND THE REFRESH FIX MADE IT WORK.

  signature  https://github.com/rockdaboot/libpsl/releases/download/0.23.3/libpsl-0.23.3.tar.gz.sig
  signer     1CB27DBC98614B2D5841646D08302DB6A2670428 (RSA-4096), signed 2026-08-14
  identity   Tim Rühsen <tim.ruehsen@gmx.de>
  key bytes  https://github.com/rockdaboot.gpg — GitHub's account endpoint,
             not a keyserver

The same fingerprint is in https://ftp.gnu.org/gnu/gnu-keyring.gpg (he
maintains GNU wget), a second host that does not serve the tarball. That copy
is stale: verifying against it is refused, and since go-zpkg/zpkb#513 the
refusal names the cause, "THE CAUSE IS EXPIRY, NOT THE KEY OR THE BYTES". So
GNU's keyring corroborates the fingerprint and GitHub's copy carries the
current validity. That copy's self-signature is dated 2026-10-12, after the
signature, and sourcepin verified it at that instant ("judged at
2026-10-12T13:32:36Z … refreshed after it signed"). Before zpkb v0.89.0 this
signature would have been refused.

⛔ NOT BUILT. No session here can run the factory.
EOT
}
