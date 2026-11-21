# libshout — the Icecast streaming client library (source clients send Ogg
# streams, and MP3/WebM, to an Icecast server through it).
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1); it was a fragment holding only a dependency map.

summary = "Icecast source-client library"

# COPYING is the GNU Library General Public License v2 text, and
# include/shout/shout.h.in:9-11 says "version 2 of the License, or (at your
# option) any later version".
license = "LGPL-2.0-or-later"

dependencies = {
  "openssl.org"  = "^3"
  "xiph.org/ogg" = "*"
}

versions {
  url   = "https://downloads.xiph.org/releases/libshout/"
  match = "/libshout-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = [
    "/^libshout-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  # The release tarball, which ships configure.
  url              = "https://downloads.xiph.org/releases/libshout/libshout-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin` (571153 bytes) and equal to the line the
  # project publishes in https://downloads.xiph.org/releases/libshout/SHA256SUMS
  # (line 20).
  #
  # ⛔ NO SIGNATURE: libshout-2.4.6.tar.gz.asc answers with a 261-byte body that
  # gpg reports as "no valid OpenPGP data". SHA256SUMS is on the same host as
  # the tarball, so it is a transport check and not an independent authority.
  sha256 = {
    "2.4.6" = "39cbd4f0efdfddc9755d88217e47f8f2d7108fa767f9d58a2ba26a16d8f7c910"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  env {
    # Every switch configure.ac defines, stated (configure.ac line numbers):
    #   :99-106   --disable-examples / --disable-tools: both OFF here. The
    #             tools directory builds a `shout` demo client; this recipe is
    #             the library.
    #   :112-113  --disable-thread: thread support stays ON (ACX_PTHREAD).
    #   :132-137  Ogg is REQUIRED (configure errors without it), found through
    #             pkg-config from the xiph.org/ogg recipe.
    #   :141,160,179 --disable-vorbis / -theora / -speex: all OFF. Their
    #             recipes (xiph.org/vorbis, theora.org, speex.org) do not exist
    #             in this tree, and an unstated optional library would be
    #             linked silently if the host had it. Turn them on when those
    #             recipes land.
    #   :200-202  --enable-pkgconfig: shout.pc installed.
    #   :224      TLS via OpenSSL, with --with-openssl=PFX read from
    #             m4/xiph_openssl.m4:9-15, which links -L<PFX>/lib -lssl.
    ARGS = [
      "--prefix={{prefix}}",
      "--disable-examples",
      "--disable-tools",
      "--enable-thread",
      "--disable-vorbis",
      "--disable-theora",
      "--disable-speex",
      "--enable-pkgconfig",
      "--with-openssl={{deps.openssl.org.prefix}}",
      "--disable-dependency-tracking",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/shout/shout.h",
    "pkg-config --exists shout",
    # Link against the library and read the version it reports. shout_init
    # and shout_version are in the public API; shout_new/shout_free exercise
    # the allocator without needing a server.
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <shout/shout.h>

int main(void) {
  int major = 0, minor = 0, patch = 0;
  shout_init();
  const char *v = shout_version(&major, &minor, &patch);
  shout_t *s = shout_new();
  if (s == NULL) {
    puts("shout_new failed");
    return 1;
  }
  if (shout_set_host(s, "localhost") != SHOUTERR_SUCCESS) {
    puts("shout_set_host failed");
    return 1;
  }
  shout_free(s);
  shout_shutdown();
  printf("libshout %s (%d.%d.%d)\n", v, major, minor, patch);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o version $(pkg-config --cflags --libs shout)"
    },
    "./version",
  ]
}

provenance {
  read = [
    "configure.ac",            # :99-106 examples/tools; :112 thread; :132-137 ogg required; :141-196 vorbis/theora/speex; :200 pkgconfig; :224 openssl
    "m4/xiph_openssl.m4",      # :9-15 --with-openssl=PFX
    "COPYING",                 # GNU Library General Public License v2
    "include/shout/shout.h.in", # :9-11 "version 2 ... or any later version"
    "Makefile.am",             # :6-11 SUBDIRS, :28-29 shout.pc
  ]

  consulted = [
    "https://downloads.xiph.org/releases/libshout/SHA256SUMS",
  ]

  note = <<EOT
NOT BUILT: written from the sources and the release index; not run on a
builder. Vorbis, Theora and Speex support is OFF because their recipes do not
exist yet; src/format_ogg.c:58-65 compiles its per-codec handlers only under
HAVE_VORBIS, HAVE_THEORA and HAVE_SPEEX, so those handlers are left out. The
tarball ships configure, so no autotools are needed.
EOT
}
