# gnome.org/librsvg — the SVG renderer GNOME uses for icons: a Rust library with
# a C API (`librsvg-2.0`), the `rsvg-convert` tool, and optional GObject
# introspection and a gdk-pixbuf loader.
#
# ⛔ WRITTEN FROM LIBRSVG'S OWN FILES (go-zpkg/packages#431, packages#440 step
# 1), at 2.63.4, replacing a fragment that listed five dependencies and no
# build.
#
# ⭐⭐ WHAT WRITING IT FOUND: three of the four output formats of rsvg-convert
# are optional at BUILD time and nothing says so at run time.
# rsvg_convert/Cargo.toml:15-18 declares cairo-pdf, cairo-ps and cairo-svg as
# `optional = true` system-deps, and :63-67 turns each into a cfg
# (`system_deps_have_cairo_pdf` …). A cairo built without PDF support yields an
# rsvg-convert that simply has no `-f pdf`. The test therefore RUNS each format.

summary = "librsvg: SVG rendering library (Rust, C API) and rsvg-convert"

# Cargo.toml:9 `license = "LGPL-2.1-or-later"` is the workspace licence, shared by
# rsvg, librsvg-c and rsvg_convert (each has `license.workspace = true`), and
# COPYING.LIB is the LGPL text. The binary also COMPILES IN crates.io
# dependencies pinned by Cargo.lock; deny.toml:41-51 is what the project's own
# `cargo deny check licenses` ALLOWS them to be: ISC, MIT, NCSA, BSD-3-Clause,
# Unicode-3.0, Apache-2.0 (with or without the LLVM exception) and MPL-2.0. That
# is the project's enforced ceiling, not an audit of the lockfile's actual
# contents, and it is what the expression lists.
license = "LGPL-2.1-or-later AND MIT AND Apache-2.0 AND ISC AND BSD-3-Clause AND NCSA AND Unicode-3.0 AND MPL-2.0"

# GNOME's index covers every series; this one began its meson-wrapped-cargo
# build in the 2.6x line, which is the first this recipe was read against.
versions {
  url   = "https://download.gnome.org/sources/librsvg/cache.json"
  match = "/librsvg-2\\.([6-9]\\d)\\.\\d+\\.tar\\.xz/"
  strip = [
    "/^librsvg-/",
    "/\\.tar\\.xz$/",
  ]
}

# gettext is no longer named: no meson.build in this tree mentions gettext or
# intl, so the fragment's dependency on it was dead weight. harfbuzz and
# freetype2 are required by meson.build:81-108 and arrive through pango and
# cairo, which carry them in their own .pc files.
dependencies = {
  "cairographics.org"    = "^1.18"
  "gnome.org/gdk-pixbuf" = 2
  "gnome.org/glib"       = 2
  "gnome.org/libxml2"    = 2
  "gnome.org/pango"      = 1
}

distributable {
  url              = "https://download.gnome.org/sources/librsvg/{{version.marketing}}/librsvg-{{version.raw}}.tar.xz"
  strip-components = 1

  # 6823168 bytes, recorded with `zpkb sourcepin --version 2.63.4`.
  #
  # ⚠ NO SIGNATURE IS PUBLISHED: the 2.63 directory has the tarball, a
  # .sha256sum and a .news. upstream's sum (31f07d93…6e8f) and a second,
  # independent curl-and-hash both match ours; the sum is served by the host
  # that serves the bytes, so this is a single-host rung, stated.
  #
  # ⚠ THE TARBALL DOES NOT VENDOR ITS CRATES. Cargo.lock is present and
  # meson/cargo_wrapper.py:148,161 passes `--locked`, so every crate is fetched
  # from crates.io at build time at the version and checksum the lockfile pins.
  # The same shape as the other cargo recipes in this tree (crates.io/zellij).
  sha256 = {
    "2.63.4" = "31f07d9350dad3f8964fd613c31309ac160fdef13dfac59df6fd082de78d6e8f"
  }
}

build {
  dependencies = {
    "github.com/lu-zero/cargo-c"      = ">=0.10.10" # meson.build:25 cargo_cbuild_version, :28 the program
    "freedesktop.org/pkg-config"      = "^0.29"
    "gnome.org/gobject-introspection" = 1
    "mesonbuild.com"                  = "^1"
    "ninja-build.org"                 = 1
    "python.org"                      = 3 # meson.build:49 find_installation(), run by the cargo wrapper
    "rust-lang.org"                   = ">=1.92" # meson.build:24 msrv
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir=lib",
      "--buildtype=release",

      # No subprojects/ directory exists in this tarball, so the `fallback:`
      # names at meson.build:70-121 have nothing to fall back to; named so that
      # a future tarball which adds wraps cannot start fetching them.
      "--wrap-mode=nofallback",

      # ---- every option of meson_options.txt, in file order ----

      # :3 introspection, auto. `enabled`: meson.build:129-131 and :159-161
      # make a missing gobject-introspection fatal instead of silently
      # dropping the GIR/typelib that GTK-side consumers load.
      "-Dintrospection=enabled",
      # :9 pixbuf, auto -> meson.build:95-99 gdk-pixbuf-2.0, which also
      # adds the `pixbuf` cargo feature (:515 pixbuf_feature_args). `enabled`,
      # because gnome.org/gdk-pixbuf is a dependency above and the C API grows
      # rsvg_handle_get_pixbuf with it.
      "-Dpixbuf=enabled",
      # :16 rsvg-convert, enabled (meson.build:165, :526).
      "-Drsvg-convert=enabled",
      # :23 pixbuf-loader, DISABLED by default and kept so: it installs into
      # gdk-pixbuf's own module directory and needs gdk-pixbuf-query-loaders.
      "-Dpixbuf-loader=disabled",
      # :30 docs, auto -> meson.build:123-127 rst2man and gi-docgen.
      # Refused: documentation that exists on one builder and not another.
      "-Ddocs=disabled",
      # :36 vala, auto -> :132-134 the vapigen compiler. Refused: no
      # recipe in this tree provides Vala.
      "-Dvala=disabled",
      # :42 tests (meson.build:171, :523): the C test programs and the cargo test suites are not
      # installed and the latter downloads every dev-dependency too.
      "-Dtests=false",
      # :48 triplet and :58 rustc-version: cross-building knobs (meson.build:224-236,
      # rustc-version Windows only), left at their empty defaults.
      # :53 avif, auto -> meson.build:77-80 dav1d via pkg-config, and with it
      # the `avif` cargo feature (:507). Refused: this tree has no dav1d, and
      # an `auto` here would change rsvg's accepted image formats with the
      # builder's disk.
      "-Davif=disabled",
    ]
  }

  script = [
    "meson setup build $ARGS",
    "meson compile -C build --jobs {{ hw.concurrency }}",
    "meson install -C build",
  ]
}

# rsvg_convert/meson.build:23-24 installs rsvg-convert to bindir; the library,
# header and librsvg-2.0.pc come from librsvg-c.
provides = [
  "bin/rsvg-convert",
]

test {
  fixture = <<EOT
#include <librsvg/rsvg.h>
#include <cairo.h>
#include <string.h>
#include <stdio.h>

static const char svg[] =
	"<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'>"
	"<rect width='4' height='4' fill='#ff0000'/></svg>";

int main(void)
{
	GError *err = NULL;
	RsvgHandle *h = rsvg_handle_new_from_data((const guint8 *)svg, strlen(svg), &err);
	if (h == NULL) {
		fprintf(stderr, "parse: %s\n", err->message);
		return 1;
	}
	cairo_surface_t *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 4, 4);
	cairo_t *cr = cairo_create(s);
	RsvgRectangle vp = { 0, 0, 4, 4 };
	if (!rsvg_handle_render_document(h, cr, &vp, &err)) {
		fprintf(stderr, "render: %s\n", err->message);
		return 2;
	}
	cairo_surface_flush(s);
	const unsigned char *px = cairo_image_surface_get_data(s);
	/* ARGB32 is native-endian; the red channel of a solid red fill is 0xff and the others 0 */
	guint32 v = *(const guint32 *)px;
	cairo_destroy(cr);
	cairo_surface_destroy(s);
	g_object_unref(h);
	return v == 0xffff0000u ? 0 : 3;
}
EOT

  script = [
    "test -f \"{{prefix}}/include/librsvg-2.0/librsvg/rsvg.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/librsvg-2.0.pc\"",
    # -Dintrospection=enabled, read off the installed tree.
    "test -f \"{{prefix}}/lib/girepository-1.0/Rsvg-2.0.typelib\"",
    {
      run = <<EOT
set -eu
export PKG_CONFIG_PATH="{{prefix}}/lib/pkgconfig:$${PKG_CONFIG_PATH:-}"
cc -x c $FIXTURE -x none -o t $(pkg-config --cflags --libs librsvg-2.0 cairo)
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./t
EOT
    },

    # ⛔⛔ EACH OUTPUT FORMAT, RUN. A cairo without cairo-pdf/ps/svg leaves
    # rsvg_convert/Cargo.toml:15-18 unsatisfied and the format absent.
    {
      run = <<EOT
set -eu
export LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}"
printf "<svg xmlns='http://www.w3.org/2000/svg' width='8' height='8'><rect width='8' height='8' fill='blue'/></svg>" > in.svg
"{{prefix}}/bin/rsvg-convert" --version
"{{prefix}}/bin/rsvg-convert" -f png -o out.png in.svg
"{{prefix}}/bin/rsvg-convert" -f pdf -o out.pdf in.svg
"{{prefix}}/bin/rsvg-convert" -f ps -o out.ps in.svg
"{{prefix}}/bin/rsvg-convert" -f svg -o out.svg in.svg
grep -q 'PNG' out.png
grep -q '^%PDF' out.pdf
grep -q '^%!PS' out.ps
grep -q '<svg' out.svg
EOT
    },
  ]
}

provenance {
  read = [
    "meson.build",              # :24-30 msrv 1.92.0 and the cargo/cargo-cbuild/rustc programs; :68-134 every dependency and its fallback; :159-171 how introspection/pixbuf-loader/docs/tests gate; :520-532 the subdirs
    "meson_options.txt",        # all ten options, :3-58
    "Cargo.toml",               # :9 licence, :15 rust-version
    "deny.toml",                # :41-51 the licences the dependency graph is allowed to carry
    "meson/cargo_wrapper.py",   # :148 and :161 `--locked`, :124-130 the avif/pixbuf features
    "rsvg_convert/Cargo.toml",  # :15-18 cairo-pdf/ps/svg optional, :63-67 their cfgs
    "rsvg_convert/meson.build", # :23-24 rsvg-convert installed to bindir
    "librsvg-c/meson.build",    # the library and its pkg-config file
    "COPYING.LIB",
  ]

  consulted = [
    "go-zpkg/recipes projects/gnome.org/librsvg/package.hcl (the fragment)",
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the options and line numbers
were read from the tarball, the digest was confirmed by upstream's sha256sum and
a second fetch, and `zpkb lint` was run.

⚠ github.com/lu-zero/cargo-c is still a FRAGMENT of this tree (lint lists it):
`cargo-cbuild` is a hard requirement (meson.build:28), so this recipe resolves
it from the pantry underneath, like gnome.org/gobject-introspection. If neither can be had, the whole project is
unbuildable; there is no switch that removes them.

⚠ gnome.org/pango, gnome.org/gdk-pixbuf and cairographics.org are likewise
unwritten here; this recipe pins nothing about HOW they were built, only that
cairo carries the PDF, PostScript and SVG surfaces and the test proves it.
EOT
}
