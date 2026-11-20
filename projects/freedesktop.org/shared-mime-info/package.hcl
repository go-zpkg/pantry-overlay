# freedesktop.org/shared-mime-info — the freedesktop.org shared MIME database
# (freedesktop.org.xml) and update-mime-database, the tool that compiles it into
# the files GIO, KDE and every desktop file chooser read.
#
# ⛔ WRITTEN FROM THE PROJECT'S OWN FILES (go-zpkg/packages#431, packages#440
# step 1), at 2.5.1, replacing a fragment that named two dependencies and
# nothing else.

summary = "The freedesktop.org shared MIME database and update-mime-database"

# GPL-2.0-or-later, from the data file and not from COPYING: COPYING is the
# GPL-2 text and says nothing about "or later", but the comment at the head of
# data/freedesktop.org.xml.in (the thing the project exists to ship) states
# "under the terms of the GNU General Public License version 2 or later", and
# src/update-mime-database.cpp:40 says only "the GNU General Public License".
license = "GPL-2.0-or-later"

versions {
  gitlab = "gitlab.freedesktop.org:xdg/shared-mime-info"
}

dependencies = {
  "gnome.org/glib"    = 2
  "gnome.org/libxml2" = "*"
  "gnu.org/gettext"   = "^1"
}

distributable {
  # ⚠ A GENERATED ARCHIVE, AND THE ONLY ONE. The release's `assets.links` is
  # empty (GitLab API, /releases): every asset is `assets.sources`, a tarball
  # GitLab generates from the tag, and no release tarball, .sha256 or .asc is
  # published beside it. A digest of it is therefore only as stable as GitLab's
  # archiver (see the lz4 recipe for what that cost elsewhere).
  url              = "https://gitlab.freedesktop.org/xdg/shared-mime-info/-/archive/{{version.raw}}/shared-mime-info-{{version.raw}}.tar.gz"
  strip-components = 1

  # 8873027 bytes, recorded with `zpkb sourcepin --version 2.5.1`. No signature
  # and no checksum file exist, so the second witness is a second, independent
  # curl-and-shasum of the same URL, which reproduced
  # ea248ea1…7539128 byte for byte. Same host, so it shows the archive is
  # stable across two requests, not who made it.
  sha256 = {
    "2.5.1" = "ea248ea157b7fa0165f4fe282c84919fa84c3f175553642f229c8f1ab7539128"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/gettext"            = "^1"
    "mesonbuild.com"             = "^1.4"
    "ninja-build.org"            = 1
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir=lib",
      "--buildtype=release",

      # ⛔ meson.build:69 and subprojects/xdgmime.wrap: the tests build a
      # subproject, and a wrap is a download. Tests are off, so none is fetched;
      # `nofallback` makes any other one fatal instead of silent.
      "--wrap-mode=nofallback",

      # ---- every option of meson_options.txt ----

      # :2 update-mimedb, default false. Left off: it runs the tool through
      # MESON_INSTALL_DESTDIR_PREFIX, which is wrong when DESTDIR is used. The
      # build script runs update-mime-database itself on the final path.
      "-Dupdate-mimedb=false",
      # :6 build-tools: update-mime-database (needs libxml2 and glib, :52-53).
      "-Dbuild-tools=true",
      # :10 build-translations -> po/meson.build, i18n.gettext needs msgfmt.
      # `true`, so a builder without gettext fails instead of shipping the
      # database without its translations (gettext is a build dependency).
      "-Dbuild-translations=true",
      # :14 build-tests: needs xmllint (:25) and the xdgmime wrap (:69).
      "-Dbuild-tests=false",
      # :18 build-spec: needs xmlto and docbook-xsl (:26); HTML not installed.
      "-Dbuild-spec=false",
    ]
  }

  script = [
    "meson setup build $ARGS",
    "meson compile -C build --jobs {{ hw.concurrency }}",
    "meson install -C build",
    # Compile the database now, as upstream's own update-mimedb option would:
    # without it share/mime holds only packages/freedesktop.org.xml.
    "\"{{prefix}}/bin/update-mime-database\" -V \"{{prefix}}/share/mime\"",
  ]
}

# src/meson.build:7-14: the one installed executable.
provides = [
  "bin/update-mime-database",
]

test {
  script = [
    "test -f \"{{prefix}}/share/pkgconfig/shared-mime-info.pc\"",
    "test -f \"{{prefix}}/share/mime/packages/freedesktop.org.xml\"",
    # The compiled database: update-mime-database wrote these, so the tool ran
    # and parsed the XML through libxml2.
    "test -s \"{{prefix}}/share/mime/mime.cache\"",
    "test -s \"{{prefix}}/share/mime/magic\"",
    "test -s \"{{prefix}}/share/mime/globs2\"",
    # A known type, with its glob, read back from what was generated.
    "grep -q 'text/x-python' \"{{prefix}}/share/mime/globs2\"",
    "grep -q 'application/pdf' \"{{prefix}}/share/mime/globs2\"",
    # Translations (data/meson.build:6-14 merge_file): a localised comment is
    # inside the merged XML.
    "grep -q 'xml:lang=\"fr\"' \"{{prefix}}/share/mime/packages/freedesktop.org.xml\"",
    # The gettext ITS rules a downstream i18n.merge_file reads (data/meson.build:16-19).
    "test -f \"{{prefix}}/share/gettext/its/shared-mime-info.its\"",
    "test -f \"{{prefix}}/share/man/man1/update-mime-database.1\"",
    # The tool is the one built: a second run over a private directory.
    {
      run = <<EOT
set -eu
mkdir -p mimedir/packages
cp "{{prefix}}/share/mime/packages/freedesktop.org.xml" mimedir/packages/
"{{prefix}}/bin/update-mime-database" mimedir
test -s mimedir/mime.cache
cmp mimedir/globs2 "{{prefix}}/share/mime/globs2"
EOT
    },
  ]
}

provenance {
  read = [
    "meson.build",                  # :2-7 meson >=0.49, C and C++17; :25-26 xmllint/xmlto; :47-57 translations and tools; :65-76 tests and the xdgmime wrap; :88-96 update-mimedb
    "meson_options.txt",            # all five options (:2-20)
    "data/meson.build",             # :3 man page; :6-14 merge_file into share/mime/packages; :16-19 its files; :21-33 spec
    "src/meson.build",              # :7-14 the update-mime-database executable
    "po/meson.build",               # :2-5 i18n.gettext
    "shared-mime-info.pc.in",       # the pc file installed under datadir/pkgconfig
    "data/freedesktop.org.xml.in",  # :63-70 the licence statement
    "src/update-mime-database.cpp", # :40 the tool's licence line
    "COPYING",                      # GPL version 2 text
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the options and line numbers
were read from the tarball (sha256 above), the digest was reproduced by a
second fetch, and `zpkb lint` was run.

⚠ pkgxdev/pantry and homebrew were not opened for this recipe.

⚠ THE TEST ASSERTS A FRENCH TRANSLATION BY GREPPING THE MERGED XML. It was
not run; if i18n.merge_file does not emit xml:lang="fr" in this form the line
is the first to adjust.
EOT
}
