# gnome.org/atk — the Accessibility Toolkit: the interfaces that GTK 2/3
# widgets implement so assistive technology can read them. Retired upstream in
# favour of at-spi2-core (2.38.0 is the last release), still named by every GTK3
# consumer.
#
# ⛔ WRITTEN FROM ATK'S OWN FILES (go-zpkg/packages#431, packages#440 step 1),
# at 2.38.0, replacing a fragment that carried a build script and no source.
#
# ⭐⭐ WHAT WRITING IT FOUND: subprojects/glib.wrap is a `wrap-git` of
# https://gitlab.gnome.org/GNOME/glib.git at revision=main. atk/meson.build's
# `dependency('glib-2.0', fallback : ['glib', 'libglib_dep'])` (meson.build:98-101)
# would CLONE AND BUILD GLIB'S DEVELOPMENT BRANCH when the system glib is
# missing. The fragment's `--wrap-mode=nofallback` is what refuses that and is
# kept, with this reason attached.

summary = "ATK: the accessibility toolkit interfaces of GTK 2 and 3"

# Every compiled source reads "GNU Lesser General Public License … version 2 of
# the License, or (at your option) any later version" (atk/atkobject.c:4-8, and
# no file under atk/ says "version 2.1"); COPYING is the LGPL 2.0 text. meson.build:3
# declares `LGPL-2.1-or-later` (:3), which is more than the sources grant, so the
# sources win.
license = "LGPL-2.0-or-later"

# GNOME's odd-minor development series are not offered (see gnome.org/glib).
versions {
  url   = "https://download.gnome.org/sources/atk/cache.json"
  match = "/atk-\\d+\\.\\d*[02468]\\.\\d+\\.tar\\.xz/"
  strip = [
    "/^atk-/",
    "/\\.tar\\.xz$/",
  ]
}

dependencies = {
  "gnome.org/glib" = 2
}

distributable {
  url              = "https://download.gnome.org/sources/atk/{{version.marketing}}/atk-{{version.raw}}.tar.xz"
  strip-components = 1

  # 303952 bytes, recorded with `zpkb sourcepin --version 2.38.0`.
  #
  # ⚠ NO SIGNATURE IS PUBLISHED: the 2.38 directory has atk-2.38.0.tar.xz,
  # .sha256sum and .news. upstream's sum (ac4de2a4…0c36) and a second, independent
  # curl-and-hash both match ours; the sum comes from the same host as the
  # bytes, so this is a single-host rung, stated.
  sha256 = {
    "2.38.0" = "ac4de2a4ef4bd5665052952fe169657e65e895c5057dffb3c2a810f6191a0c36"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config"      = "^0.29"
    "gnome.org/gobject-introspection" = 1
    "gnu.org/gettext"                 = "^1"
    "mesonbuild.com"                  = "^1"
    "ninja-build.org"                 = 1
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir=lib",

      # ⛔ meson.build:5 sets buildtype=debugoptimized as the project default.
      "--buildtype=release",

      # ⛔⛔ subprojects/glib.wrap clones GLib's `main` branch (see the head of
      # this file); libffi.wrap, zlib.wrap and proxy-libintl.wrap are its
      # transitive fallbacks. Every one becomes a fatal "not found".
      "--wrap-mode=nofallback",

      # meson_options.txt:1-4 docs (gtk-doc) default false; :5-8 introspection
      # default TRUE. atk/meson.build:138 then calls gnome.generate_gir(), which
      # fails without g-ir-scanner — so the typelib the GTK3 stack loads is a
      # build dependency here, named rather than left to the default.
      "-Ddocs=false",
      "-Dintrospection=true",
    ]
  }

  script = [
    "meson setup build $ARGS",
    "meson compile -C build --jobs {{ hw.concurrency }}",
    "meson install -C build",
  ]
}

# atk is a library: no executables are installed (atk/meson.build:125 library(),
# and tests/meson.build builds five test programs that are not installed).
provides = []

test {
  fixture = <<EOT
#include <atk/atk.h>
#include <string.h>
#include <stdio.h>

int main(void)
{
	if (atk_get_major_version() != 2 || atk_get_minor_version() != 38) {
		fprintf(stderr, "atk version %u.%u\n", atk_get_major_version(), atk_get_minor_version());
		return 1;
	}
	if (strcmp(atk_role_get_name(ATK_ROLE_PUSH_BUTTON), "push button") != 0)
		return 2;
	AtkStateSet *s = atk_state_set_new();
	atk_state_set_add_state(s, ATK_STATE_FOCUSED);
	int ok = atk_state_set_contains_state(s, ATK_STATE_FOCUSED)
	      && !atk_state_set_contains_state(s, ATK_STATE_CHECKED);
	g_object_unref(s);
	return ok ? 0 : 3;
}
EOT

  script = [
    "test -f \"{{prefix}}/include/atk-1.0/atk/atk.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/atk.pc\"",
    # -Dintrospection=true, read off the installed tree.
    "test -f \"{{prefix}}/share/gir-1.0/Atk-1.0.gir\"",
    "test -f \"{{prefix}}/lib/girepository-1.0/Atk-1.0.typelib\"",
    "cc -x c $FIXTURE -x none -o t -I{{prefix}}/include/atk-1.0 $(pkg-config --cflags glib-2.0 gobject-2.0) -L{{prefix}}/lib -latk-1.0 $(pkg-config --libs glib-2.0 gobject-2.0)",
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
    "meson.build",           # :3 licence; :5 buildtype=debugoptimized; :98-101 the glib/gobject fallbacks; :112-114 subdirs atk, tests, po
    "meson_options.txt",     # :1-8 both options: docs (false) and introspection (true)
    "atk/meson.build",       # :125 the library; :138-153 generate_gir when introspection is on
    "tests/meson.build",     # five test programs, built and not installed
    "subprojects/glib.wrap", # wrap-git, revision=main
    "atk/atkobject.c",       # :4-8 the licence grant, "version 2 … or any later version"
    "COPYING",               # the LGPL 2.0 text
  ]

  consulted = [
    # Read for facts only: the recipe this one replaces.
    "go-zpkg/recipes projects/gnome.org/atk/package.hcl (the fragment)",
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory.

⚠ The introspection output is the one thing that makes this recipe depend on a
project this tree does not carry: gnome.org/gobject-introspection resolves
from the pantry. If that dependency is ever retired, -Dintrospection=false is
the single switch (meson_options.txt:5-8) and the two typelib assertions in
the test go with it.
EOT
}
