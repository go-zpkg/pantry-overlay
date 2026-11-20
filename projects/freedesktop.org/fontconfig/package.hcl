# freedesktop.org/fontconfig — font configuration and matching. libXft links it
# (libXft configure.ac:73 `fontconfig >= 2.5.92`, xft.pc.in
# `Requires.private: fontconfig`), and Tk 8.6.18 unix/configure.in:457-533 and
# Tk 9.0.4 unix/configure.ac:346-422 link libXft for antialiased fonts, so the
# Tk build of go-zpkg/recipes#167 needs it. Until now this was a FRAGMENT: nine
# lines of dependencies and nothing that said where the source comes from.
#
# ⛔ WRITTEN FROM FONTCONFIG'S OWN FILES (go-zpkg/packages#431), at 2.16.0.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. THE FRAGMENT DECLARED A LIBRARY IT DOES NOT USE AND OMITTED TWO THAT IT
#      NEEDS. It declared gnome.org/libxml2, which fontconfig links only with
#      `--enable-libxml2` (configure.ac:417-439, default off: expat is the
#      parser). It declared bzip2 and zlib, which fontconfig never names: they
#      reach it through freetype2.pc. And it omitted gnu.org/gperf, run at
#      configure time (:216-234, fatal when the len type cannot be determined)
#      and at build time to generate fcobjshash.h, and python, which
#      AM_PATH_PYTHON([3]) requires (:56) and conf.d/Makefile.am:114 runs at
#      INSTALL time (link_confs.py).
#   2. NO SIGNATURE EXISTS. The release directory holds the archive and one
#      `.sha256sum`; see provenance.note for what the pin rests on.
#   3. NLS IS A SILENT DETECTION: AM_GNU_GETTEXT([external]) (:113-114) turns
#      itself off when libintl is not found, without failing — the same trap
#      gnu.org/libidn2 records. It is pinned with --with-libintl-prefix and the
#      test asserts a message catalogue was installed.
#   4. `make install` RUNS fc-cache (--enable-cache-build, configure:1601)
#      against whatever fonts the BUILDER has, writing caches into the prefix.
#      Off, so an artifact does not contain the builder's font list.
#   5. json-c is detected (:444) and only gates the test suite
#      (test/Makefile.am:106); no switch disables it and nothing installed
#      depends on it.

summary = "Fontconfig: font configuration and customization library"

# COPYING:3-12 — "Copyright © 2000-2007 Keith Packard … Permission to use, copy,
# modify, distribute, and sell this software and its documentation for any
# purpose is hereby granted without fee … the name of the author(s) not be used
# in advertising": HPND-sell-variant. COPYING also quotes the licences of
# individual files:
#   :40-71   src/fcatomic.h — "Permission is hereby granted, without written
#            agreement and without license or royalty fees … provided that the
#            above copyright notice and the following two paragraphs appear":
#            the HarfBuzz licence, which SPDX has no identifier for;
#   :75-97   src/fcfoundry.h — "Permission is hereby granted, free of charge":
#            MIT;
#   :100-    src/fcmd5.h — "This code is in the public domain": no SPDX
#            identifier. The rest of COPYING (to :200) was not read.
license = "HPND-sell-variant AND MIT AND LicenseRef-fontconfig-fcatomic-harfbuzz AND LicenseRef-fontconfig-fcmd5-public-domain"

versions {
  url   = "https://www.freedesktop.org/software/fontconfig/release/"
  match = "/fontconfig-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = ["/fontconfig-/", "/\\.tar\\.xz/"]
}

dependencies = {
  # configure.ac:312 `freetype2 >= 21.0.15`, fatal; fontconfig.pc `Requires`.
  "freetype.org"       = "^2"
  # configure.ac:352-404: expat is the parser unless --enable-libxml2; a missing
  # expat.h is fatal (:396-397). fontconfig.pc `Requires.private: expat`.
  "libexpat.github.io" = "^2"
  # finding 3
  "gnu.org/gettext"    = "*"
}

distributable {
  # 1294156 bytes. Recorded with `zpkb sourcepin` and confirmed twice, by hosts
  # other than the one that served the pin: curl + shasum on the same URL, on
  # the GitLab package registry's copy of the same release, and the
  # `.sha256sum` beside the archive all gave the same digest.
  url              = "https://www.freedesktop.org/software/fontconfig/release/fontconfig-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "2.16.0" = "6a33dc555cc9ba8b10caf7695878ef134eeb36d0af366041f639b1da9b6ed220"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gperf"              = "*"
    "gnu.org/make"               = "*"
    "python.org"                 = "^3"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # The configuration lives inside the prefix, not in the builder's /etc and
      # /var: fonts.conf (confdir = sysconfdir/fonts) and the cache directory
      # (configure.ac:591, localstatedir/cache/fontconfig).
      "--sysconfdir={{prefix}}/etc",
      "--localstatedir={{prefix}}/var",

      # ⛔ finding 1: the XML parser, named. expat is the default and libxml2 an
      # alternative (configure:1597); the fragment declared the wrong one.
      "--disable-libxml2",

      # configure.ac:239-241, default off: iconv only for non-Unicode SFNT names.
      "--disable-iconv",

      # ⛔ finding 3, pinned to the declared gettext.
      "--with-libintl-prefix={{deps.gnu.org/gettext.prefix}}",

      # ⛔ finding 4, and the documentation (configure:1598-1601): docs default
      # on, docbook2html auto-detected (:746).
      "--disable-cache-build",
      "--disable-docs",
      "--disable-docbook",

      # configure:1584 `--enable-static … [default=no]`, stated.
      "--disable-static",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# The nine tools: fc-cache fc-cat fc-conflist fc-list fc-match fc-pattern
# fc-query fc-scan fc-validate (the pantry's list, each confirmed in a scratch
# install's bin/).
provides = [
  "bin/fc-cache",
  "bin/fc-cat",
  "bin/fc-conflist",
  "bin/fc-list",
  "bin/fc-match",
  "bin/fc-pattern",
  "bin/fc-query",
  "bin/fc-scan",
  "bin/fc-validate",
]

test {
  script = [
    "fc-match --version | grep -q '^fontconfig version {{version.raw}}'",
    "test -f \"{{prefix}}/etc/fonts/fonts.conf\"",
    "test -f \"{{prefix}}/lib/pkgconfig/fontconfig.pc\"",

    # ⛔ finding 1, read off the artifact: the .pc names freetype2 publicly and
    # expat privately, and no libxml2.
    "grep -q '^Requires:.*freetype2' \"{{prefix}}/lib/pkgconfig/fontconfig.pc\"",
    "grep -q '^Requires.private:.*expat' \"{{prefix}}/lib/pkgconfig/fontconfig.pc\"",
    "! grep -q 'libxml-2.0' \"{{prefix}}/lib/pkgconfig/fontconfig.pc\"",

    # ⛔ finding 3: at least one message catalogue was installed, which only
    # happens when libintl was found.
    {
      run = <<EOT
set -eu
n=0
for f in "{{prefix}}"/share/locale/*/LC_MESSAGES/fontconfig.mo; do
  test -e "$f" && n=$((n+1))
done
test "$n" -ge 1 || { echo "no fontconfig.mo installed: NLS was silently disabled" >&2; exit 1; }
EOT
    },

    # ⛔ finding 4: no cache was built at install time.
    {
      run = <<EOT
set -eu
if test -d "{{prefix}}/var/cache/fontconfig" && test -n "$(ls -A "{{prefix}}/var/cache/fontconfig")"; then
  echo "fc-cache ran during the build and baked the builder's fonts into the prefix" >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",    # :56 python; :113-114 gettext; :216-234 gperf; :239-307 iconv; :312 freetype2; :339-412 expat; :417-439 libxml2; :444 json-c; :454-577 sub-pixel, hinting, fonts dirs; :582-624 cache and config dirs; :741-790 docbook, docs, cache-build
    "configure",       # :1574-1651 every switch and its default
    "Makefile.am",     # (conf.d, doc, test) conf.d/Makefile.am:114 link_confs.py at install; test/Makefile.am:106 json-c
    "COPYING",         # :3-12 the main notice; :40-117 the per-file notices cited
    "https://www.freedesktop.org/software/fontconfig/release/", # the archive and its .sha256sum
    "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.16.0/fontconfig-2.16.0.tar.xz", # the second host's copy
    "https://sourceforge.net/projects/tcl/files/Tcl/", # Tk 8.6.18 and 9.0.4 sources, read for the consumer's need
  ]

  consulted = [
    # Read for facts only: the URL shapes, the dependency list, the nine tools
    # and that it builds with gperf and python. Nothing copied; the sed that
    # rewrites cachedir to a relative path is NOT carried.
    "pkgxdev/pantry projects/freedesktop.org/fontconfig/package.yml",
  ]

  note = <<EOT
⚠ UNSIGNED. THE PIN IS A DIGEST THAT TWO HOSTS AGREE ON, NOT A SIGNATURE.

The release directory https://www.freedesktop.org/software/fontconfig/release/
holds fontconfig-2.16.0.tar.xz and fontconfig-2.16.0.tar.xz.sha256sum, and no
.sig or .asc. The digest

  6a33dc555cc9ba8b10caf7695878ef134eeb36d0af366041f639b1da9b6ed220

was obtained three ways: the builder's fetcher (`zpkb sourcepin`), curl and
shasum on the same URL, and the same bytes from the GitLab package registry
(gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/…).
Both URLs are freedesktop.org infrastructure, so this is agreement between two
paths to one operator, not independent authorship. Nothing was checked against a
signed git tag.

⛔ NOT BUILT here as the factory would. A scratch build on darwin with these
arguments (the machine's own freetype, expat, gperf and gettext, not the recipes
this one declares) configured, built and
installed: nine tools, fonts.conf, `fc-match --version` printing 2.16.0, and
message catalogues installed. The `.pc` showed `Requires: freetype2 >=
21.0.15` and `Requires.private: expat`.
EOT
}
