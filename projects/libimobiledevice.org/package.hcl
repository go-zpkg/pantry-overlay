# libimobiledevice.org — libimobiledevice, the library that talks to Apple iOS
# devices over usbmuxd, and the 21 command line tools built on it. This tree
# carried only a dependency list for it (a fragment, go-zpkg/packages#440 step
# 1); this is the whole recipe.
#
# ⛔ WRITTEN FROM LIBIMOBILEDEVICE'S OWN FILES (go-zpkg/packages#431), at 1.4.0.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#  1. The fragment's libtasn1 dependency is DEAD for this build. configure.ac:271-286
#     asks for libtasn1 only in the GnuTLS branch, and common/userpref.c:61 includes
#     <libtasn1.h> only under HAVE_GNUTLS. With the OpenSSL backend nothing reads it.
#  2. Two switches in configure.ac do the OPPOSITE of what they say. AC_ARG_ENABLE
#     and AC_ARG_WITH run their "given" branch for ANY value:
#       --disable-debug / --enable-debug  both reach `no_debug_code=false` (:304-308):
#                      the debug code is built. The upstream recipe passed
#                      `--disable-debug` AND `--enable-debug`; it got debug code twice.
#       --with-readline / --without-readline  both reach `check_libreadline=false`
#                      (:48-52): readline is OFF either way. Only passing nothing probes.
#  3. SSL is picked by `use_*` defaults (:174-196): OpenSSL unless mbedtls/gnutls is
#     asked for; a missing OpenSSL is fatal (:228-229) only when the backend is
#     OpenSSL, which it is by default. Named below.
#  4. Python bindings are probed (:129-170): a builder with Cython 3 and libplist's
#     Cython headers gets bindings, one without does not. Refused below.

summary = "libimobiledevice: communicate with iOS devices over usbmuxd (library and tools)"

# COPYING is the GNU GPL version 2 and COPYING.LESSER the GNU LGPL version 2.1;
# every file of src/ common/ include/ and all tools but one carry "GNU Lesser
# General Public License ... version 2.1 ... or (at your option) any later
# version" (e.g. tools/idevicedate.c:6-10), and tools/idevicesetlocation.c:6-12
# carries the GNU GPL "version 2 ... or any later version". Compiled in, wireless
# pairing (configure.ac:296-302, on by default) adds 3rd_party/ed25519 (zlib
# licence, per its README.md; its LICENSE file is NOT in the tarball) and
# 3rd_party/libsrp6a-sha512 (the Stanford SRP notice at srp.c:2-27, a permissive
# licence with a keep-the-notice clause and no SPDX identifier; its LICENSE file is
# not in the tarball either).
license = "LGPL-2.1-or-later AND GPL-2.0-or-later AND Zlib AND LicenseRef-Stanford-SRP"

versions {
  github = "libimobiledevice/libimobiledevice"
}

dependencies = {
  "libimobiledevice.org/libimobiledevice-glue" = "^1.3"
  "libimobiledevice.org/libplist"              = "^2.4"
  "libimobiledevice.org/libtatsu"              = "^1"
  "libimobiledevice.org/libusbmuxd"            = "^2"
  "openssl.org"                                = "^3"
}

distributable {
  # The release asset: it carries the generated `configure` and .tarball-version
  # (git-version-gen, configure.ac:5), which GitHub's archive of the tag does not.
  # 714628 bytes. Recorded with `zpkb sourcepin` and confirmed by a second,
  # independent fetch-and-hash (curl + shasum -a 256). See provenance.note.
  url              = "https://github.com/libimobiledevice/libimobiledevice/releases/download/{{version.raw}}/libimobiledevice-{{version.raw}}.tar.bz2"
  strip-components = 1

  sha256 = {
    "1.4.0" = "23cc0077e221c7d991bd0eb02150a0d49199bcca1ddf059edccee9ffd914939d"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir={{prefix}}/lib",

      # ⛔ SSL, NAMED (configure.ac:174-196, :225-234). The default is already
      # OpenSSL; mbedtls and gnutls are named off so a future default is visible.
      "--with-openssl",
      "--without-mbedtls",
      "--without-gnutls",

      # REFUSED: the Cython bindings (:129-170, probed from the builder's Python).
      "--without-cython",

      # REFUSED: readline for afcclient (:48-59). `--with-readline` is also off
      # (see the header), so this is the only way to say it. afcclient has no line
      # editing as a result.
      "--without-readline",

      # Wireless pairing (:296-302) is ON by default; named so it stays on. It is
      # what compiles 3rd_party/ed25519 and libsrp6a-sha512.
      "--enable-wireless-pairing",

      # NOT passed: --enable-debug and --disable-debug (both BUILD the debug code,
      # see the header). Without either, STRIP_DEBUG_CODE is defined (:309-311).
    ]

    # ⛔ pkg-config sees ONLY the declared dependencies (the five PKG_CHECK_MODULES
    # at :44-47 and :227): a libplist, libusbmuxd, libtatsu or OpenSSL of the
    # builder's own cannot be picked up instead.
    PKG_CONFIG_LIBDIR = "{{deps.openssl.org.prefix}}/lib/pkgconfig:{{deps.libimobiledevice.org/libplist.prefix}}/lib/pkgconfig:{{deps.libimobiledevice.org/libusbmuxd.prefix}}/lib/pkgconfig:{{deps.libimobiledevice.org/libimobiledevice-glue.prefix}}/lib/pkgconfig:{{deps.libimobiledevice.org/libtatsu.prefix}}/lib/pkgconfig"
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# tools/Makefile.am:17-38, bin_PROGRAMS: the twenty-one tools, all installed.
provides = [
  "bin/afcclient",
  "bin/idevice_id",
  "bin/idevicebackup",
  "bin/idevicebackup2",
  "bin/idevicebtlogger",
  "bin/idevicecrashreport",
  "bin/idevicedate",
  "bin/idevicedebug",
  "bin/idevicedebugserverproxy",
  "bin/idevicediagnostics",
  "bin/ideviceenterrecovery",
  "bin/ideviceimagemounter",
  "bin/ideviceinfo",
  "bin/idevicename",
  "bin/idevicenotificationproxy",
  "bin/idevicepair",
  "bin/ideviceprovision",
  "bin/idevicescreenshot",
  "bin/idevicesetlocation",
  "bin/idevicesyslog",
  "bin/idevicedevmodectl",
]

test {
  # No device is attached to a builder, so what is read off the installed artifact
  # is what the build chose: the SSL provider the library names for pkg-config,
  # the exact version, every tool answering --version, and a program linked
  # against the shared library that calls into it.
  fixture = <<EOT
#include <libimobiledevice/libimobiledevice.h>
#include <stdio.h>

int main(void)
{
	idevice_info_t *devs = NULL;
	int n = 0;
	idevice_set_debug_level(0);
	idevice_error_t e = idevice_get_device_list_extended(&devs, &n);
	/* no usbmuxd on a builder: success with an empty list, or "no device" */
	if (e != IDEVICE_E_SUCCESS && e != IDEVICE_E_NO_DEVICE) {
		fprintf(stderr, "unexpected error %d\n", (int)e);
		return 1;
	}
	if (devs) idevice_device_list_extended_free(devs);
	return 0;
}
EOT

  script = [
    {
      run = <<EOT
set -eu
export PKG_CONFIG_LIBDIR="{{prefix}}/lib/pkgconfig:{{deps.openssl.org.prefix}}/lib/pkgconfig:{{deps.libimobiledevice.org/libplist.prefix}}/lib/pkgconfig:{{deps.libimobiledevice.org/libusbmuxd.prefix}}/lib/pkgconfig:{{deps.libimobiledevice.org/libimobiledevice-glue.prefix}}/lib/pkgconfig:{{deps.libimobiledevice.org/libtatsu.prefix}}/lib/pkgconfig"

# The SSL backend, as the library's own .pc names it (configure.ac:225-237,
# src/libimobiledevice-1.0.pc.in:12): OpenSSL, and none of the others.
pkg-config --exact-version={{version.raw}} libimobiledevice-1.0
requires="$(pkg-config --print-requires-private libimobiledevice-1.0)"
case "$requires" in *openssl*) ;; *) echo "no openssl in: $requires" >&2; exit 1;; esac
case "$requires" in *gnutls*|*mbedtls*|*tasn1*) echo "another TLS library in: $requires" >&2; exit 1;; esac

# Every tool prints "<name> <version>" for --version (tools/idevicedate.c:131).
for t in afcclient idevice_id idevicebackup idevicebackup2 idevicebtlogger \
  idevicecrashreport idevicedate idevicedebug idevicedebugserverproxy \
  idevicediagnostics ideviceenterrecovery ideviceimagemounter ideviceinfo \
  idevicename idevicenotificationproxy idevicepair ideviceprovision \
  idevicescreenshot idevicesetlocation idevicesyslog idevicedevmodectl; do
  out="$("{{prefix}}/bin/$t" --version)" || { echo "$t --version failed" >&2; exit 1; }
  case "$out" in "$t {{version.raw}}"*) ;; *) echo "$t printed '$out'" >&2; exit 1;; esac
done

# Link and call the shared library through its .pc.
cc -x c $FIXTURE -x none -o probe $(pkg-config --cflags libimobiledevice-1.0) $(pkg-config --libs libimobiledevice-1.0)
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./probe
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                    # :27-47 minimum versions and PKG_CHECK_MODULES, :48-59 readline, :129-172 cython, :174-294 SSL backend, :296-302 wireless pairing, :304-314 debug
    "Makefile.am",                     # :3 SUBDIRS
    "src/Makefile.am",                 # the library's sources and what it links
    "common/Makefile.am",              # internalcommon
    "common/userpref.c",               # :55-65 libtasn1.h only under HAVE_GNUTLS
    "tools/Makefile.am",               # :17-38 the twenty-one tools
    "tools/idevicedate.c",             # :6-10 LGPL notice, :71, :131 --version
    "tools/idevicesetlocation.c",      # :6-12 GPL notice
    "src/libimobiledevice-1.0.pc.in",  # :12 Requires.private with @ssl_requires@
    "include/libimobiledevice/libimobiledevice.h", # :53-56 error codes
    "3rd_party/README.md",             # the bundled ed25519 and libsrp6a-sha512, their sources
    "3rd_party/ed25519/README.md",     # zlib licence
    "3rd_party/libsrp6a-sha512/srp.c", # :2-27 Stanford SRP notice
    "COPYING",                         # GPL 2
    "COPYING.LESSER",                  # LGPL 2.1
  ]

  consulted = [
    # Read for facts only: URL shape and that the tool list is long. Its
    # `sed -i` on common/utils.h applies to <1.3.1 only; `--disable-debug` plus
    # `--enable-debug` and libtasn1 were NOT taken, for the reasons above.
    "pkgxdev/pantry projects/libimobiledevice.org/package.yml",
  ]

  note = <<EOT
⚠ THE RUNG IS A SINGLE HOST, STATED. The project publishes no checksum file and no
signature; the annotated tag 1.4.0 (ea579c1a, 2025-10-10) is unsigned (GitHub:
"unsigned"). The digest records the release asset, fetched twice independently
(builder fetcher via `zpkb sourcepin`, and curl + shasum -a 256), same answer.

⚠ The tarball lacks 3rd_party/ed25519/LICENSE and 3rd_party/libsrp6a-sha512/LICENSE
that 3rd_party/README.md promises; the two licences above are read from the READMEs
and the source header, not from a licence file.

⛔ NOT BUILT. Its four dependencies (libplist, libimobiledevice-glue, libusbmuxd,
libtatsu) have no recipe in this tree and none was available here, so neither
configure nor make was run; every claim above is from reading the files. The test
is written against the outputs those files define (tools/idevicedate.c:131,
src/libimobiledevice-1.0.pc.in:12) and has not been run.
EOT
}
