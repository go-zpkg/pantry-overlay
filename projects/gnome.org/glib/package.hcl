# gnome.org/glib — the low-level core library under GTK and GNOME: data
# structures, the main loop, GObject, GModule and GIO, with the tools that
# compile schemas and resources. The 2.x series.
#
# ⛔ WRITTEN FROM GLIB'S OWN FILES (go-zpkg/packages#431, packages#440 step 1),
# at 2.90.1, replacing a five-line fragment that named dependencies and
# nothing else.
#
# ⭐⭐ WHAT WRITING IT FOUND: glib probes the build machine for eleven optional
# things and the fragment had no `build` block at all, so every one of them was
# decided by whoever ran the factory. Two of them can also reach the network:
# `sysprof` and `libffi`/`pcre2`/`zlib` each carry a wrap fallback that meson
# follows when the system copy is missing. Every `-D` option in meson.options
# is named below, with the line that probes it.

summary = "GLib: the core library of GTK and GNOME (GObject, GModule, GIO)"

# README.md names no licence; meson.build:2 and the SPDX headers do. Every file
# in the compiled directories (glib/ gio/ gobject/ gmodule/ girepository/ and
# the vendored subprojects/gvdb) is `LGPL-2.1-or-later`, except gio/xdgmime/*,
# which is "LGPL-2.1-or-later or AFL-2.0" (xdgmime.c, a choice, so the
# expression stays LGPL-2.1-or-later). The GPL/MIT/Apache/MPL texts in LICENSES/
# belong to tests, scripts and docs that are not installed. Measured with
# `grep -rlE "SPDX-License-Identifier: .*(AFL|Apache|CC0|GPL-2.0-or-later|
# LGPL-2.1-only|LLVM|MIT|MPL|BSD)"` over those directories: only two test
# generators and xdgmime match.
license = "LGPL-2.1-or-later"

# ⛔ THE INDEX HOLDS EVERY SERIES, AND HALF OF THEM ARE DEVELOPMENT SNAPSHOTS.
# cache.json lists 2.79.x next to 2.78.x; GNOME's odd minor is unstable. The
# match keeps only an EVEN minor (the last digit of the series is 0/2/4/6/8),
# so 2.90.1 is stable and 2.79.3 is not.
versions {
  url   = "https://download.gnome.org/sources/glib/cache.json"
  match = "/glib-2\\.\\d*[02468]\\.\\d+\\.tar\\.xz/"
  strip = [
    "/^glib-/",
    "/\\.tar\\.xz$/",
  ]
}

dependencies = {
  "pcre.org/v2"           = 10
  "python.org"            = 3
  "sourceware.org/libffi" = 3
  "zlib.net"              = "*"

  # ⚠ libintl: meson.build:2321-2357 takes it from libc when libc has ngettext
  # (glibc), and otherwise falls back to the proxy-libintl wrap. macOS has none,
  # so gettext is a runtime dependency there only (the shape gnome.org/libxml2
  # records for iconv).
  darwin = {
    "gnu.org/gettext" = "^1"
  }
}

distributable {
  url              = "https://download.gnome.org/sources/glib/{{version.marketing}}/glib-{{version.raw}}.tar.xz"
  strip-components = 1

  # 5871112 bytes, recorded with `zpkb sourcepin --version 2.90.1`.
  #
  # ⚠ NO SIGNATURE IS PUBLISHED. The 2.90 directory offers glib-2.90.1.tar.xz,
  # .sha256sum and .news, and no .asc/.sig. upstream's own sha256sum
  # (93c941aa…e396) and a second, independent curl-and-hash both reproduce our
  # digest — but the sum is served by the host that serves the bytes, so it
  # establishes that we fetched what they published, not who published it. A
  # single-host rung, stated.
  sha256 = {
    "2.90.1" = "93c941aa17d5eb1d53fe838365f29a8b4e539c222a256d974ec8f30fc413e396"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/gettext"            = "^1"
    "mesonbuild.com"             = "^1.4" # meson.build:4 meson_version '>= 1.4.0'
    "ninja-build.org"            = 1
    "python.org"                 = 3 # meson.build:2518-2531, '>=3.7'
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir=lib",
      "--buildtype=release",

      # ⛔⛔ THE NETWORK. meson.build:2276 (pcre2), :2302 (libffi), :2304 (zlib),
      # :2353 (proxy-libintl) and glib/meson.build:34-46 (sysprof) each name a
      # wrap in subprojects/ that meson DOWNLOADS and builds when the system
      # copy is missing. A missing dependency would therefore become a silent
      # network fetch of different code. `nofallback` makes each of them fatal.
      # (subprojects/gvdb is vendored in the tarball, so :2298 still works.)
      "--wrap-mode=nofallback",

      # ---- every option of meson.options, in file order ----

      # :25 selinux, auto -> meson.build:2393, Linux only.
      "-Dselinux=disabled",
      # :30 xattr, boolean true -> :2399-2417; ERRORS when no getxattr exists.
      "-Dxattr=true",
      # :35 libmount, auto -> :2374, Linux only (util-linux's libmount).
      "-Dlibmount=disabled",
      # :46 man-pages, auto -> :2855 find_program rst2man. Refused: a man page
      # that exists on one builder and not another.
      "-Dman-pages=disabled",
      # :52 dtrace and :58 systemtap, auto -> :2632-2688, find_program('dtrace')
      # and sys/sdt.h. Refused: tracing probes in the library.
      "-Ddtrace=disabled",
      "-Dsystemtap=disabled",
      # :69 sysprof, auto -> glib/meson.build:34, with a wrap fallback.
      "-Dsysprof=disabled",
      # :75 documentation (needs gi-docgen, docs/reference/meson.build:2).
      "-Ddocumentation=false",
      # :86 bsymbolic_functions, :117 glib_debug, :123 glib_assert, :129
      # glib_checks: the upstream defaults, named so a flip is a diff here.
      "-Dbsymbolic_functions=true",
      "-Dglib_debug=enabled",
      "-Dglib_assert=true",
      "-Dglib_checks=true",
      # :91 force_posix_threads only changes Windows.
      "-Dforce_posix_threads=false",
      # :96 tests, :101 installed_tests: the Clar-like test programs are not
      # installed and take as long as the library itself.
      "-Dtests=false",
      "-Dinstalled_tests=false",
      # :106 nls, auto -> :2829 find_program('xgettext'). Named `enabled`, so a
      # builder without gettext tools FAILS instead of producing a library with
      # no translations (gnu.org/gettext is a build dependency above).
      "-Dnls=enabled",
      # :112 oss_fuzz is a build environment marker, disabled.
      "-Doss_fuzz=disabled",
      # :135 libelf, auto -> gio/meson.build:1004-1020, gresource's ELF
      # resource support. `disabled` makes :1011 find_library NOT FOUND.
      "-Dlibelf=disabled",
      # :140 multiarch: installs helpers in per-architecture directories.
      "-Dmultiarch=false",
      # :149 introspection, auto -> :2711-2713. DISABLED, and necessarily: the
      # scanner (gobject-introspection) itself depends on glib, so the first
      # build cannot have it.
      "-Dintrospection=disabled",
      # :155 file_monitor_backend, auto -> gio/meson.build:827-836: inotify if
      # sys/inotify.h and inotify_init1 exist, else kqueue if kqueue/kevent
      # exist, else NO monitor backend at all. A platform choice with no
      # optional library behind it, left at auto and READ BACK by the test.
      "-Dfile_monitor_backend=auto",

      # NOT passed: :1 runtime_libdir (deprecated), :40 man and :80 gtk_doc
      # (deprecated aliases of man-pages/documentation), :7 charsetalias_dir,
      # :12 gio_module_dir, :20 runtime_dir, :64 tapset_install_dir and :145
      # gir_dir_prefix (paths whose empty default derives from libdir/prefix).
    ]
  }

  script = [
    "meson setup build $ARGS",
    "meson compile -C build --jobs {{ hw.concurrency }}",
    "meson install -C build",
  ]
}

# gio/meson.build:1056 gio, :1064 gresource, :1071 gio-querymodules, :1080
# glib-compile-schemas, :1089 glib-compile-resources, :1111 gsettings, :1128
# gdbus; gobject/meson.build:90-91 glib-genmarshal and glib-mkenums, :179
# gobject-query; glib/meson.build:534 gtester; gio/gdbus-2.0/codegen/meson.build:40
# gdbus-codegen. ⚠ gio-querymodules lives in `multiarch_bindir`, which is bindir
# unless -Dmultiarch (meson.build:134-142), so it is bin/ here.
provides = [
  "bin/gdbus",
  "bin/gdbus-codegen",
  "bin/gio",
  "bin/gio-querymodules",
  "bin/glib-compile-resources",
  "bin/glib-compile-schemas",
  "bin/glib-genmarshal",
  "bin/glib-mkenums",
  "bin/gobject-query",
  "bin/gresource",
  "bin/gsettings",
  "bin/gtester",
]

test {
  # Each assertion reads an outcome off the INSTALLED library: PCRE2 through
  # GRegex, libffi through the generic closure marshaller (the only
  # ffi_call under gobject/ and gio/ is in gobject/gclosure.c), zlib through GZlibCompressor,
  # and the file-monitor backend through its registered GIO extension name.
  fixture = <<EOT
#include <glib.h>
#include <glib-object.h>
#include <gio/gio.h>
#include <string.h>
#include <stdio.h>

static int add(int a, int b, gpointer data)
{
	return a + b;
}

static int fail(const char *what)
{
	fprintf(stderr, "FAIL: %s\n", what);
	return 1;
}

int main(void)
{
	/* 1. PCRE2 (meson.build:2260): a capture group out of GRegex. */
	GMatchInfo *mi = NULL;
	GRegex *re = g_regex_new("(\\d+)-(\\d+)", 0, 0, NULL);
	if (re == NULL || !g_regex_match(re, "ab 12-34", 0, &mi))
		return fail("regex");
	gchar *g2 = g_match_info_fetch(mi, 2);
	if (strcmp(g2, "34") != 0)
		return fail("regex group");
	g_free(g2);
	g_match_info_free(mi);
	g_regex_unref(re);

	/* 2. libffi (meson.build:2302): the generic marshaller calls through it. */
	GClosure *c = g_cclosure_new(G_CALLBACK(add), NULL, NULL);
	g_closure_ref(c);
	g_closure_sink(c);
	g_closure_set_marshal(c, g_cclosure_marshal_generic);
	GValue params[2] = { G_VALUE_INIT, G_VALUE_INIT };
	GValue ret = G_VALUE_INIT;
	g_value_init(&params[0], G_TYPE_INT);
	g_value_init(&params[1], G_TYPE_INT);
	g_value_init(&ret, G_TYPE_INT);
	g_value_set_int(&params[0], 3);
	g_value_set_int(&params[1], 4);
	g_closure_invoke(c, &ret, 2, params, NULL);
	if (g_value_get_int(&ret) != 7)
		return fail("libffi closure");
	g_closure_unref(c);

	/* 3. zlib (meson.build:2304): gzip round trip through GIO. */
	char src[1000], packed[4096], back[1100];
	memset(src, 'x', sizeof src);
	gsize rd = 0, wr = 0, rd2 = 0, wr2 = 0;
	GError *err = NULL;
	GConverter *z = G_CONVERTER(g_zlib_compressor_new(G_ZLIB_COMPRESSOR_FORMAT_GZIP, -1));
	if (g_converter_convert(z, src, sizeof src, packed, sizeof packed,
	                        G_CONVERTER_INPUT_AT_END, &rd, &wr, &err) != G_CONVERTER_FINISHED
	    || wr == 0 || wr >= sizeof src)
		return fail("gzip compress");
	g_object_unref(z);
	GConverter *u = G_CONVERTER(g_zlib_decompressor_new(G_ZLIB_COMPRESSOR_FORMAT_GZIP));
	if (g_converter_convert(u, packed, wr, back, sizeof back,
	                        G_CONVERTER_INPUT_AT_END, &rd2, &wr2, &err) != G_CONVERTER_FINISHED
	    || wr2 != sizeof src || memcmp(src, back, sizeof src) != 0)
		return fail("gzip decompress");
	g_object_unref(u);

	/* 4. file monitor backend (gio/meson.build:827-836). */
	GFile *dot = g_file_new_for_path(".");
	GFileMonitor *m = g_file_monitor_directory(dot, G_FILE_MONITOR_NONE, NULL, &err);
	if (m == NULL)
		return fail("file monitor");
	GIOExtensionPoint *ep = g_io_extension_point_lookup("gio-local-file-monitor");
	if (ep == NULL
	    || (g_io_extension_point_get_extension_by_name(ep, "inotify") == NULL
	        && g_io_extension_point_get_extension_by_name(ep, "kqueue") == NULL))
		return fail("no inotify or kqueue file monitor backend registered");
	g_object_unref(m);
	g_object_unref(dot);
	return 0;
}
EOT

  script = [
    "test -f \"{{prefix}}/include/glib-2.0/glib.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/gio-2.0.pc\"",
    "cc -x c $FIXTURE -x none -o t -I{{prefix}}/include/glib-2.0 -I{{prefix}}/lib/glib-2.0/include -L{{prefix}}/lib -lgio-2.0 -lgobject-2.0 -lglib-2.0",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./t
EOT
    },

    # The tools run, and the schema compiler really compiles.
    "\"{{prefix}}/bin/gio\" version | grep -q {{version.raw}}",
    "\"{{prefix}}/bin/glib-compile-schemas\" --version",
    "\"{{prefix}}/bin/glib-compile-resources\" --version",
    "\"{{prefix}}/bin/gdbus-codegen\" --help > /dev/null",

    # ⛔ -Dselinux/-Dlibmount/-Dlibelf/-Dsysprof=disabled, read off the build:
    # none of those libraries may be linked into the installed objects. ldd
    # exists on glibc only; elsewhere the options themselves are the contract.
    {
      run = <<EOT
set -eu
if command -v ldd >/dev/null 2>&1; then
  for f in "{{prefix}}"/lib/libgio-2.0.so.0 "{{prefix}}"/lib/libglib-2.0.so.0 "{{prefix}}/bin/gresource"; do
    if ldd "$f" 2>/dev/null | grep -E 'libmount|libselinux|libelf|libsysprof' >&2; then
      echo "$f links a library an option disabled" >&2
      exit 1
    fi
  done
fi
EOT
    },
  ]
}

provenance {
  read = [
    "meson.options",              # all 29 options (:1-155): the type, default and `deprecated` of each, which is what the -D list above is built from
    "meson.build",                # :4 meson 1.4; :2260-2304 pcre2/gvdb/libffi/zlib and their wrap fallbacks; :2321-2357 libintl; :2374 libmount; :2393 selinux; :2399-2417 xattr; :2632-2688 dtrace/systemtap; :2711-2713 introspection; :2829 nls; :2855-2863 rst2man/rst2html5
    "glib/meson.build",           # :34-46 sysprof with its wrap fallback; :534 gtester
    "gio/meson.build",            # :827-836 file monitor auto; :1004-1020 libelf; :1056-1128 the installed executables; :938-952 gio-2.0.pc variables
    "gobject/meson.build",        # :90-91 glib-genmarshal, glib-mkenums; :179 gobject-query
    "gio/gdbus-2.0/codegen/meson.build", # :40 gdbus-codegen installed to bindir
    "gio/inotify/ginotifyfilemonitor.c",  # :43-44 the extension name "inotify" the test looks up
    "gio/kqueue/gkqueuefilemonitor.c",    # :100-102 the extension name "kqueue"
    "subprojects/gvdb.wrap",      # gvdb is a directory in the tarball, so no download
    "LICENSES",                   # the texts the SPDX headers cite
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the options and line numbers
were read from the tarball (sha256 above), the digest was confirmed by
upstream's sha256sum and a second fetch, and `zpkb lint` was run.

⚠ pkgxdev/pantry was not opened for this recipe.

⚠ TWO CHOICES TO REVISIT WHEN A FACTORY RUNS IT. `-Dman-pages=disabled` drops
the man pages, which a Linux distribution would keep; they need rst2man, a
Python tool this tree has no recipe for. And `introspection=disabled` is
forced by a cycle, not a preference: gobject-introspection builds against this
library, so the typelibs for GLib's own namespaces are produced by a later
recipe.
EOT
}
