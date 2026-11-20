# freedesktop.org/xdg-user-dirs — the tool that creates and looks up the
# well-known per-user directories (Desktop, Downloads, Documents…), and the
# `xdg-user-dir` shell function that reads them.
#
# ⛔ WRITTEN FROM XDG-USER-DIRS' OWN FILES (go-zpkg/packages#431, packages#440
# step 1), at 0.18, replacing a two-line fragment.
#
# ⭐ WHAT WRITING IT FOUND: configure.ac:68-77 makes DOCUMENTATION DEFAULT ON
# and fatal without xsltproc, and the tarball carries the man pages as DocBook
# XML only (man/*.xml, no pre-built *.1). So a plain `./configure` either fails
# on a builder without xsltproc or builds man pages from whatever DocBook
# stylesheets that builder happens to have.

summary = "xdg-user-dirs: manage well-known user directories (Desktop, Documents…)"

# COPYING is the GNU GPL version 2 text. ⚠ NO SOURCE FILE CARRIES A NOTICE
# NAMING A VERSION: xdg-user-dirs-update.c opens with `#include <config.h>`, and
# neither README nor AUTHORS says "or later". Nothing grants more than the
# text COPYING contains, so `GPL-2.0-only`. xdg-user-dir-lookup.c:2-3 says it is
# NOT under the GPL but MIT "to encourage reuse by cut-and-paste"; it is a
# noinst program (Makefile.am:39-43), built for the tree's own use and not
# installed, so MIT is not part of what this recipe ships.
license = "GPL-2.0-only"

versions {
  url   = "https://user-dirs.freedesktop.org/releases/"
  match = "/xdg-user-dirs-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = [
    "/^xdg-user-dirs-/",
    "/\\.tar\\.gz$/",
  ]
}

# libintl/iconv are the C library's on glibc; only macOS needs gettext at run
# time (the shape gnome.org/libxml2 records for iconv). The build-time
# `msgfmt` comes from gettext on every platform, below.
dependencies = {
  darwin = {
    "gnu.org/gettext" = "^1"
  }
}

distributable {
  url              = "https://user-dirs.freedesktop.org/releases/xdg-user-dirs-{{version.raw}}.tar.gz"
  strip-components = 1

  # 273556 bytes, recorded with `zpkb sourcepin --version 0.18`.
  #
  # ⚠ NO SIGNATURE AND NO CHECKSUM FILE: releases/ lists only the tarballs
  # (0.4 … 0.18). The digest is the bytes this host served, re-fetched a second
  # time and identical; nothing upstream attests it. The weakest rung, stated.
  sha256 = {
    "0.18" = "ec6f06d7495cdba37a732039f9b5e1578bcb296576fde0da40edb2f52220df3c"
  }
}

build {
  dependencies = {
    "gnu.org/gettext" = "^1"
    "gnu.org/make"    = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # Makefile.am:19-23 puts user-dirs.conf, user-dirs.defaults and the
      # autostart entry under $(sysconfdir)/xdg, and the binary compiles that
      # path in as XDGCONFDIR (:11, read at xdg-user-dirs-update.c:408). Left
      # to the default it is /usr/local/etc, outside the prefix.
      "--sysconfdir={{prefix}}/etc",

      # ⛔ configure.ac:68-77: documentation defaults to YES and is FATAL without
      # xsltproc; man/ holds DocBook XML only. Refused.
      "--disable-documentation",

      # configure.ac:28-37 `--enable-more-warnings` defaults to yes only when a
      # CVSVERSION file exists (a git checkout) and then adds -Werror; a tarball
      # has none. Named so a compiler's new warning cannot fail the build.
      "--disable-more-warnings",

      # ⛔ AM_ICONV (configure.ac:17) also searches the install prefix for a
      # libiconv, so a builder that has one there links it. Iconv comes from
      # the C library.
      "--without-libiconv-prefix",

      # configure.ac:23 AM_GNU_GETTEXT([external]): NLS stays on and the .mo
      # files are installed; the test reads one back. (`external` makes a
      # missing libintl silently turn NLS off, which is why the test checks.)
      "--enable-nls",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Makefile.am:27-29 bin_PROGRAMS xdg-user-dirs-update; :31-33 bin_SCRIPTS
# xdg-user-dir. ⚠ The latter is `#!/bin/sh` (xdg-user-dir:1), so it is not
# promised in `provides`, the convention gnome.org/libxml2 records for
# xml2-config.
provides = [
  "bin/xdg-user-dirs-update",
]

test {
  script = [
    "test -f \"{{prefix}}/etc/xdg/user-dirs.defaults\"",
    "test -f \"{{prefix}}/etc/xdg/user-dirs.conf\"",
    "test -f \"{{prefix}}/etc/xdg/autostart/xdg-user-dirs.desktop\"",

    # configure.ac:23 / po/LINGUAS: the French catalogue is installed iff NLS
    # was really on.
    "test -f \"{{prefix}}/share/locale/fr/LC_MESSAGES/xdg-user-dirs.mo\"",

    # Documentation was refused: no man page may appear.
    {
      run = <<EOT
if ls "{{prefix}}"/share/man/man*/xdg-user-dir* >/dev/null 2>&1; then
  echo "man pages were installed — --disable-documentation was dropped" >&2
  exit 1
fi
EOT
    },

    # ⛔ THE COMPILED-IN XDGCONFDIR, READ BACK: with XDG_CONFIG_DIRS unset the
    # program must find {{prefix}}/etc/xdg/user-dirs.defaults, whose
    # DOWNLOAD=Downloads (user-dirs.defaults:6) it writes into the dummy file.
    {
      run = <<EOT
set -eu
mkdir -p home cfg
unset XDG_CONFIG_DIRS
HOME="$PWD/home" XDG_CONFIG_HOME="$PWD/cfg" LANG=C LC_ALL=C \
  "{{prefix}}/bin/xdg-user-dirs-update" --dummy-output "$PWD/out.dirs"
grep -q 'XDG_DOWNLOAD_DIR="\$HOME/Downloads"' out.dirs
grep -q 'XDG_DESKTOP_DIR="\$HOME/Desktop"' out.dirs
EOT
    },

    # The lookup script, over the file just written.
    {
      run = <<EOT
set -eu
cp out.dirs cfg/user-dirs.dirs
test "$(HOME="$PWD/home" XDG_CONFIG_HOME="$PWD/cfg" "{{prefix}}/bin/xdg-user-dir" DOWNLOAD)" = "$PWD/home/Downloads"
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                # :17 AM_ICONV; :23 AM_GNU_GETTEXT([external]); :28-37 more-warnings; :68-77 documentation default yes, xsltproc fatal
    "Makefile.am",                 # :11 XDGCONFDIR; :19-23 the xdg directory; :27-33 programs and script; :39-43 noinst lookup program
    "xdg-user-dirs-update.c",      # :408 XDGCONFDIR read; :1055-1064 --help, --force, --dummy-output, --set
    "xdg-user-dir",                # :1 #!/bin/sh
    "xdg-user-dir-lookup.c",       # :2-3 "not licenced under the GPL … MIT"
    "user-dirs.defaults",          # :6 DOWNLOAD=Downloads
    "COPYING",                     # the GPL version 2 text
    "man/",                        # DocBook XML only
    "po/LINGUAS",                  # fr is catalogued
  ]

  consulted = [
    "go-zpkg/recipes projects/freedesktop.org/xdg-user-dirs/package.hcl (the fragment)",
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the options and line numbers
were read from the tarball and `zpkb lint` was run.

⚠ gnu.org/libiconv, which the fragment declared, is gone: with
--without-libiconv-prefix the C library's iconv is used on glibc, and macOS
ships one. The fragment's gettext stays, as a build dependency everywhere and a
run-time one on darwin.
EOT
}
