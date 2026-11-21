# harfbuzz.org — HarfBuzz: the OpenType text shaping engine (libharfbuzz,
# libharfbuzz-subset, libharfbuzz-icu, libharfbuzz-gobject) and its utilities.
#
# ⛔ WRITTEN FROM THE RELEASE SOURCE TARBALL'S OWN FILES (go-zpkg/packages#440), at
# 15.2.0, as a dependency of tectonic-typesetting.github.io. Meson, from the
# stored `harfbuzz-15.2.0.tar.xz` (a release asset: the generated ragel output is
# in it, so ragel_subproject stays off).
#
# meson_options.txt, EVERY option, named below (default in brackets):
#   glib enabled       [auto] util/meson.build:44 builds NO utility without it.
#   gobject enabled    [auto] util/meson.build:158 hb-info links libharfbuzz-gobject.
#   introspection disabled [auto] no gobject-introspection recipe is used here.
#   cairo disabled     [auto] no cairo recipe exists in this tree. COST: no hb-view
#                      (util/meson.build:45 builds it only with cairo).
#   chafa disabled     [auto] no recipe; terminal-graphics output of hb-view/raster.
#   png enabled        [auto] libpng.org, in this tree.
#   zlib enabled       [auto] zlib.net, in this tree.
#   icu enabled        [auto] unicode.org (ICU), meson.build:124 looks up icu-uc.
#   graphite disabled  [disabled] deprecated alias of graphite2, stated.
#   graphite2 enabled  [disabled] graphite.sil.org, meson.build:118.
#   freetype enabled   [auto] freetype.org, meson.build:115.
#   fontations, gdi, directwrite, coretext, harfrust, kbts, wasm  disabled
#                      [disabled] stated. COST: no CoreText shaper on macOS.
#   raster, vector, gpu, subset enabled [enabled] stated.
#   gpu_demo disabled  [auto] needs GLEW, GLFW and GL.
#   tests disabled     [enabled] not built.
#   docs disabled      [auto] gtk-doc.   doc_tests false [false].
#   utilities enabled  [enabled].        benchmark disabled [disabled].
#   icu_builtin false  [false]: ICU stays the separate libharfbuzz-icu module.
#   with_libstdcxx false [false]. experimental_api false [false].
#   ragel_subproject false [false].
#   fuzzer_ldflags     left unset: it is only read by the fuzzer binaries.
#   cmakepackagedir    left unset: meson.build:428-429 resolves '' to
#                      <libdir>/cmake.

summary = "HarfBuzz: the OpenType text shaping engine and its utilities"

# COPYING:1 "the so-called 'Old MIT' license" (SPDX MIT, the HarfBuzz-old-MIT
# text); subdirectories carry their own COPYING for the parts under others.
license = "MIT"

versions {
  github = "harfbuzz/harfbuzz"
  ignore = ["/rc/"]
}

dependencies = {
  "freetype.org"      = "*"
  "graphite.sil.org"  = "*"
  "unicode.org"       = "*"
  "libpng.org"        = "*"
  "zlib.net"          = "*"
  "gnome.org/glib"    = "*"

  # glib-2.0.pc and gobject-2.0.pc list pcre2 and libffi in Requires.private,
  # and pkg-config resolves those even for --cflags, so their .pc directories
  # must be on PKG_CONFIG_PATH. They are glib's own dependencies
  # (projects/gnome.org/glib/package.hcl:43,45), named here so the paths exist.
  "pcre.org/v2"           = 10
  "sourceware.org/libffi" = 3
}

distributable {
  url              = "https://github.com/harfbuzz/harfbuzz/releases/download/{{version.raw}}/harfbuzz-{{version.raw}}.tar.xz"
  strip-components = 1

  # 20761992 bytes, fetched with `zpkb sourcepin`. The release assets are the
  # tarball and two win32/win64 zips: NO checksum file and NO signature is
  # published. The second witness is therefore a second independent fetch (curl
  # --fail, a separate download from zpkb's own fetcher), whose shasum -a 256
  # is the same digest.
  sha256 = {
    "15.2.0" = "e2ec49090744383cdbe7df808c1cedaafba06a97be8dc4211fe546ba585f12cb"
  }
}

build {
  dependencies = {
    "mesonbuild.com"             = "*"
    "ninja-build.org"            = "*"
    # src/meson.build:1432 runs gen-harfbuzz-world.py and :467 gen-ragel-artifacts.py
    # through find_program: a python 3 is a build input.
    "python.org"                 = "^3"
    "freedesktop.org/pkg-config" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir={{prefix}}/lib",
      "--buildtype=release",
      "--wrap-mode=nofallback",
      "-Dglib=enabled",
      "-Dgobject=enabled",
      "-Dintrospection=disabled",
      "-Dcairo=disabled",
      "-Dchafa=disabled",
      "-Dpng=enabled",
      "-Dzlib=enabled",
      "-Dicu=enabled",
      "-Dgraphite=disabled",
      "-Dgraphite2=enabled",
      "-Dfreetype=enabled",
      "-Dfontations=disabled",
      "-Dgdi=disabled",
      "-Ddirectwrite=disabled",
      "-Dcoretext=disabled",
      "-Dharfrust=disabled",
      "-Dkbts=disabled",
      "-Dwasm=disabled",
      "-Draster=enabled",
      "-Dvector=enabled",
      "-Dgpu=enabled",
      "-Dgpu_demo=disabled",
      "-Dsubset=enabled",
      "-Dtests=disabled",
      "-Ddocs=disabled",
      "-Ddoc_tests=false",
      "-Dutilities=enabled",
      "-Dbenchmark=disabled",
      "-Dicu_builtin=false",
      "-Dwith_libstdcxx=false",
      "-Dexperimental_api=false",
      "-Dragel_subproject=false",
    ]

    PKG_CONFIG_PATH = "{{deps.freetype.org.prefix}}/lib/pkgconfig:{{deps.graphite.sil.org.prefix}}/lib/pkgconfig:{{deps.unicode.org.prefix}}/lib/pkgconfig:{{deps.libpng.org.prefix}}/lib/pkgconfig:{{deps.zlib.net.prefix}}/lib/pkgconfig:{{deps.gnome.org/glib.prefix}}/lib/pkgconfig:{{deps.pcre.org/v2.prefix}}/lib/pkgconfig:{{deps.sourceware.org/libffi.prefix}}/lib/pkgconfig"
    LDFLAGS        = "-Wl,-rpath,{{prefix}}/lib -Wl,-rpath,{{deps.freetype.org.prefix}}/lib -Wl,-rpath,{{deps.graphite.sil.org.prefix}}/lib -Wl,-rpath,{{deps.unicode.org.prefix}}/lib -Wl,-rpath,{{deps.libpng.org.prefix}}/lib -Wl,-rpath,{{deps.zlib.net.prefix}}/lib -Wl,-rpath,{{deps.gnome.org/glib.prefix}}/lib"
  }

  script = [
    "meson setup build $ARGS",
    "meson compile -C build",
    "meson install -C build",
  ]
}

# util/meson.build `install: true` executables, all under the HAVE_GLIB gate
# (:44): hb-shape :70-75, hb-vector :80-85, hb-raster :93-98, hb-info :155-160,
# hb-subset :165-170. hb-view needs cairo (:45, off) and hb-gpu needs the demo
# deps (:230, gpu_demo off), so neither is installed; the *-all programs are
# `install: false`.
provides = [
  "bin/hb-info",
  "bin/hb-raster",
  "bin/hb-shape",
  "bin/hb-subset",
  "bin/hb-vector",
]

test {
  dependencies = {
    "gnu.org/gcc"                = "*"
    "freedesktop.org/pkg-config" = "*"
  }

  script = [
    "test -f {{prefix}}/include/harfbuzz/hb.h",
    "pkg-config --exists harfbuzz harfbuzz-subset harfbuzz-icu",
    "test \"$(pkg-config --modversion harfbuzz)\" = \"{{version.raw}}\"",
    "hb-shape --version",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <hb.h>
#include <hb-ot.h>

int main(void) {
  hb_buffer_t *buf = hb_buffer_create();
  hb_buffer_add_utf8(buf, "fi", -1, 0, -1);
  hb_buffer_guess_segment_properties(buf);
  if (hb_buffer_get_length(buf) != 2) {
    puts("buffer length");
    return 1;
  }
  hb_buffer_destroy(buf);
  printf("harfbuzz %s\n", hb_version_string());
  return strcmp(hb_version_string(), "{{version.raw}}") == 0 ? 0 : 1;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o hbcheck $(pkg-config --cflags --libs harfbuzz)"
    },
    "./hbcheck",
  ]
}

provenance {
  read = [
    "meson_options.txt",     # every option, :2-74
    "meson.build",           # :3 version; :115-124 dependency lookups; :125 icu >= 75.1 vs cpp_std; :428-429 cmakepackagedir
    "util/meson.build",      # :44 HAVE_GLIB gate; :45 hb-view needs cairo; :70, :80, :93, :155, :165 the installed utilities, :111-151 the install: false ones
    "src/meson.build",       # :456-475 ragel only to develop (generated sources ship); :1428-1432 gen-harfbuzz-world.py via find_program; :1098-1133 harfbuzz-subset and harfbuzz-icu pkgconfig files
    "COPYING",               # :1 "Old MIT"
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the test
block has been run, on either platform.

The source has no published checksum or signature; its second witness is an
independent second download with the same sha256. The
PKG_CONFIG_PATH names the pkgconfig directories of the declared dependencies,
including glib's pcre2 and libffi; zlib reaches glib too. That line is the
first to check on a run, as is whether the glib recipe installs gobject-2.0.pc
and glib-mkenums.

The gnome.org/glib, unicode.org and graphite.sil.org dependencies are
unconstrained ("*"): meson.build wants glib >= 2.30, icu >= 49 and graphite2
>= 1.2, and the tree's recipes are all newer; the tectonic fragment's ^71 on ICU
is not carried over. ICU 79.1 is >= 75.1, so meson.build:125-128 adds -std=c++17
by itself. Both pkg-config names (harfbuzz-subset, harfbuzz-icu) are generated
at src/meson.build:1098 and :1133.
EOT
}
