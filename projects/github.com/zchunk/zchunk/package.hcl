# github.com/zchunk/zchunk — zchunk, a compressed file format built to be
# delta-downloaded: the zck, unzck, zckdl, zck_gen_zdict, zck_read_header and
# zck_delta_size tools, and libzck.
#
# ⛔ A FRAGMENT UNTIL NOW: three dependency lines and nothing else. This is the
# WHOLE recipe, written from zchunk's own files (go-zpkg/packages#440 step 1),
# at 1.5.5.

summary = "zchunk: a compressed file format that can be downloaded as a delta"

# LICENSE:1 "BSD 2-Clause License".
license = "BSD-2-Clause"

# meson.build:62-70. argp is not in every libc: on darwin, freebsd and windows
# the build ALWAYS asks for the separate library (`find_library('argp')`, else
# `dependency('argp-standalone')`), and on linux it falls back to the same
# dependency when the C library has no argp.h. This registry has no
# argp-standalone, so darwin cannot build; linux is kept, on the C library's own
# argp (glibc).
platforms = ["linux"]

versions {
  github = "zchunk/zchunk"
}

dependencies = {
  # meson.build:25 `dependency('libzstd')`, option with-zstd.
  "facebook.com/zstd" = "^1"
  # meson.build:39 `dependency('libcurl')`, option with-curl: the zckdl tool.
  "curl.se" = "^8"
  # meson.build:46 `dependency('openssl')`, option with-openssl: the checksum
  # backend (ZCHUNK_OPENSSL; < 3.0.0 selects the deprecated API, :50-52).
  "openssl.org" = "^3"
}

distributable {
  # GitHub's archive of the tag 1.5.5: the project publishes no release assets
  # (`gh release list` is empty; it has tags only). 1.5.5 is the newest tag
  # `zpkb versions` resolves.
  url              = "https://github.com/zchunk/zchunk/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 1519791 bytes, recorded with `zpkb sourcepin`; a second, independent fetch
  # (curl, then shasum -a 256) gave the same digest.
  #
  # ⚠ ONE HOST, NO SIGNATURE: the project publishes neither a checksum file nor
  # a signature, and the digest records GitHub's generated archive.
  sha256 = {
    "1.5.5" = "2ab8ef54475aa2b2c0120fc6ae6d0788e0c3d4d4b671985edc6a19c8096a02cc"
  }
}

build {
  dependencies = {
    "mesonbuild.com"             = "^1.4"
    "ninja-build.org"            = 1
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir=lib",
      "--buildtype=release",
      # meson.build:23-26 name fallbacks to a zstd subproject (subprojects/).
      # A wrap is a download: refuse every fallback instead of fetching one.
      "--wrap-mode=nofallback",

      # ---- every option of meson_options.txt ----

      # :1-3 are `feature` options defaulting to auto, which silently links what
      # the host has. Each is named, and `enabled` makes a missing library fail.
      "-Dwith-zstd=enabled",
      "-Dwith-openssl=enabled",
      "-Dwith-curl=enabled",
      # :4 coverity, default false: a static-analysis build, left off.
      "-Dcoverity=false",
      # :5 docs, default true: installs the six prebuilt man pages of doc/
      # (meson.build:87-96); nothing is generated, so it stays on.
      "-Ddocs=true",
      # :6 tests, default true: builds test/ (meson.build:74-76), which is not
      # installed. Off.
      "-Dtests=false",
    ]
  }

  script = [
    "meson setup build $ARGS",
    "meson compile -C build --jobs {{ hw.concurrency }}",
    "meson install -C build",
  ]
}

# src/meson.build:13-66: the six installed executables.
provides = [
  "bin/zck",
  "bin/unzck",
  "bin/zckdl",
  "bin/zck_gen_zdict",
  "bin/zck_read_header",
  "bin/zck_delta_size",
]

test {
  script = [
    # meson.build:78-85: pkg_mod.generate(filebase 'zck').
    "test -f \"{{prefix}}/lib/pkgconfig/zck.pc\"",
    "test -f \"{{prefix}}/include/zck.h\"",
    {
      # A round trip through the tools just built: compress, read the header
      # back, decompress, compare.
      run = <<EOT
set -eu
printf 'zchunk round trip %s\n' 1 2 3 4 5 6 7 8 9 10 > in.txt
zck -o in.txt.zck in.txt
test -s in.txt.zck
zck_read_header in.txt.zck > header.txt
test -s header.txt
unzck -c in.txt.zck > out.txt
cmp in.txt out.txt
EOT
    },
  ]
}

provenance {
  read = [
    "meson.build",         # :3 version 1.5.5; :22-33 zstd; :35-40 curl; :42-53 openssl; :62-70 argp; :74-76 tests; :78-85 pkgconfig; :87-96 man pages
    "meson_options.txt",   # :1-6 with-zstd, with-openssl, with-curl, coverity, docs, tests
    "src/meson.build",     # :13-66 the six executables; zckdl alone needs curl
    "LICENSE",             # :1 BSD 2-Clause License
    "README.md",           # :61-85 zstd dictionaries; zck_gen_zdict calls the zstd binary
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT, NOT TESTED on either platform. The first factory run is this
file's test; in particular the round trip's flags (zck -o, src/zck.c:53;
unzck -c, src/unzck.c:55) were read from the source, not run.

⚠ linux ONLY: darwin needs argp-standalone, which this registry does not have
(meson.build:62-67). On a linux built against musl the same fallback fires and
the build fails for the same reason; the factory's C library decides.

zck_gen_zdict shells out to the zstd binary at run time (README.md:85), which is
not a declared dependency: only libzstd is linked.
EOT
}
