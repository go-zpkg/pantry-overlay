# libevent.org — an event notification library: event loops over epoll, kqueue,
# poll and select, plus buffered I/O, DNS and an HTTP server on top.
#
# ⛔ WRITTEN FROM LIBEVENT'S OWN FILES (go-zpkg/packages#440 step 1), at 2.1.13.
# The previous file was a fragment holding one dependency line.

summary = "Libevent: an event notification library with buffered I/O, DNS and HTTP"

# LICENSE:1-2 states it plainly: "the 3-clause (or "modified") BSD license". The
# file then licenses three parts under other terms, and only those that are
# COMPILED into the library on a Unix build are counted:
#
#   ISC   arc4random.c, LICENSE:57-73 — headed "the 'OpenBSD' license", whose text
#         (permission to use, copy, modify and distribute with or without fee) is
#         the ISC licence.
#
# NOT added: the MIT text at LICENSE:77-, which covers "the Windows timer code"
# derived from libutp (WIN32-Code), and win32select.c — neither is built here.
license = "BSD-3-Clause AND ISC"

# The release tags are `release-2.1.13-stable`, and the 2.2 line is only
# published as `alpha` so far: `zpkb versions` lists 2.1.13 first once the
# prefix and the stage suffix are stripped and the pre-releases ignored.
versions {
  github = "libevent/libevent"
  strip  = ["/^release-/", "/-stable$/"]
  ignore = ["/alpha|beta|rc/"]
}

dependencies = {
  # Named on in the build below: --enable-openssl is the default and, when
  # pkg-config finds nothing, configure STOPS (m4/libevent_openssl.m4:50-53), so a
  # missing OpenSSL is a refusal and never a silent no-TLS build.
  "openssl.org" = "^3"
}

distributable {
  # ⛔ THE STORED RELEASE ASSET, not the generated archive of the tag: the
  # release uploads libevent-2.1.13-stable.tar.gz and its .asc. Unlike the tag
  # archive it carries the generated ./configure, so no autotools are needed.
  url              = "https://github.com/libevent/libevent/releases/download/release-{{version.raw}}-stable/libevent-{{version.raw}}-stable.tar.gz"
  strip-components = 1

  # 1126525 bytes, fetched with `zpkb sourcepin`'s own fetcher and hashed again
  # by shasum -a 256.
  #
  # Corroborated by a THIRD PARTY's record: homebrew-core's API
  # (formulae.brew.sh/api/formula/libevent.json, stable 2.1.13) records the same
  # digest for the same URL. Not by a signature: see provenance.note for why the
  # published .asc could not be verified.
  sha256 = {
    "2.1.13" = "f7e9383b8c0baa81b687e5b5eecc01beefaf1b19b64151d95ed61647fe7a315c"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/make"               = "*"
  }

  # Every switch is read from configure.ac:75-115. The ones that matter:
  #   --enable-openssl       :92-94 default yes, FATAL when absent, so OpenSSL is a
  #                          fact of the artifact and libevent_openssl is built.
  #   --enable-thread-support  :86-88 default yes (pthreads, libevent_pthreads).
  #   --disable-samples      :104-106 the sample/ programs are not installed.
  #   --disable-libevent-regress  :101-103 the regression suite is only a
  #                          `make check` matter; it is also the only user of
  #                          zlib (:185-201, the HAVE_LIBZ probe), so with it off
  #                          a zlib on the builder cannot be picked up.
  #   --disable-doxygen-doc  Doxygen is an optional tool probed by
  #                          DX_INIT_DOXYGEN (:1001); off, so a builder's doxygen
  #                          does not change what is installed.
  # The last three keep the build independent of the host.
  script = [
    "./configure --prefix={{prefix}} --enable-shared --enable-static --enable-openssl --enable-thread-support --enable-debug-mode --enable-malloc-replacement --disable-samples --disable-libevent-regress --disable-doxygen-doc",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

# Makefile.am:100 `dist_bin_SCRIPTS = event_rpcgen.py`: the one program.
provides = [
  "bin/event_rpcgen.py",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/event2/event.h",
    # The five .pc files configure.ac:1006 generates: core, extra, the OpenSSL
    # and pthreads add-ons and the umbrella. openssl and pthreads existing is
    # the proof the two switches above took effect.
    "pkg-config --exists libevent libevent_core libevent_extra libevent_openssl libevent_pthreads",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <event2/event.h>
#include <event2/thread.h>
#include <event2/bufferevent_ssl.h>

int main(void) {
  /* header and library must agree: a disagreement is how a build picks up a
     system libevent instead of the one it just made. */
  if (strcmp(event_get_version(), LIBEVENT_VERSION) != 0) {
    printf("header %s but library %s\n", LIBEVENT_VERSION, event_get_version());
    return 1;
  }
  if (evthread_use_pthreads() != 0) {
    puts("pthreads support missing");
    return 1;
  }
  struct event_base *base = event_base_new();
  if (!base) {
    puts("event_base_new failed");
    return 1;
  }
  printf("libevent %s, method %s, openssl symbol %p\n", event_get_version(),
         event_base_get_method(base), (void *)bufferevent_openssl_socket_new);
  event_base_free(base);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o evtest $(pkg-config --cflags --libs libevent libevent_openssl libevent_pthreads)"
    },
    "./evtest",
  ]
}

provenance {
  read = [
    "README.md",                  # build instructions: ./configure && make && make install
    "configure.ac",               # :8 version; :75-115 every --enable/--disable switch; :185-201 zlib probe; :1001 doxygen; :1006 the five .pc files
    "m4/libevent_openssl.m4",     # :4-61 openssl via pkg-config, :50-53 a hard error when missing
    "Makefile.am",                # :100 dist_bin_SCRIPTS event_rpcgen.py; :163 pkgconfig_DATA
    "CMakeLists.txt",             # :44 EVENT__LIBRARY_TYPE, :66 version from git, :843-844 OpenSSL REQUIRED
    "LICENSE",                    # :1-2 BSD-3-Clause; :57-73 the OpenBSD (ISC) arc4random text; :77- the MIT Windows timer
  ]

  consulted = [
    "formulae.brew.sh/api/formula/libevent.json (checksum only)",
  ]

  note = <<EOT
⚠ THE SECOND WITNESS IS A THIRD PARTY'S DIGEST, NOT A SIGNATURE, AND WHY. The
release asset has a detached .asc (833 bytes), made 2026-07-01 by the subkey
7A02B3521DC75C542BA015456AFEE6D49E92B601, which is the signing subkey of
Nick Mathewson's key 2133BC600AB133E1D826D173FE43009C4607B1FB (fingerprint
stated on his own page, www.freehaven.net/~nickm/, and the subkey listed in the
Tor project's tor-commits message and a Gentoo-held copy of the key). Every
copy of that key that could be reached without a keyserver had EXPIRED before
the signature was made (the page's own public_key.asc: 2020-09-16; the Gentoo
copy: 2025-10-04), and `zpkb sourcepin --sig auto` refuses with "key expired,
judged at 2026-07-01T12:17:13Z" — the correct refusal, so nothing is pinned
from it. libevent.org publishes no checksum. Revisit when the maintainer
publishes an extended key.

libevent.org's download page and the Debian packaging (debian/upstream/
signing-key.asc) name a different maintainer's key, 9E3AC83A27974B84D1B3401D
B86086848EF8686D (Azat Khuzhin), which did not sign 2.1.13.

Why autotools and not CMake: both ship in the tarball; configure.ac states every
switch as --enable/--disable with its default, while CMakeLists.txt:66 takes the
version through event_fuzzy_version_from_git(), a git-derived step this
recipe does not need to trust on a tarball. The CMake build was not tried.

⛔ NOT BUILT. No session here can run the factory.
EOT
}
