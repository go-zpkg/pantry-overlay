# pinentry — the small programs gpg-agent runs to ask for a passphrase.
#
# WRITTEN FROM THE PROJECT'S OWN FILES at 1.3.3 (go-zpkg/packages#440). There
# was no recipe; gnupg.org names it as a dependency.
#
# ONLY THE TERMINAL FRONT ENDS ARE BUILT: pinentry-tty and pinentry-curses.
# Every GUI one (gtk2, gnome3, qt6, qt5, qt4, tqt, fltk, efl, emacs) and the
# libsecret cache are switched off by name, so no desktop library of the host
# can be picked up by detection.

summary = "Passphrase entry programs for GnuPG (tty and curses front ends)"

# pinentry/pinentry.h:18 "SPDX-License-Identifier: GPL-2.0+" and :7-9 "version
# 2 of the License, or (at your option) any later version".
license = "GPL-2.0-or-later"

versions {
  url   = "https://gnupg.org/ftp/gcrypt/pinentry/"
  match = "/pinentry-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^pinentry-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://gnupg.org/ftp/gcrypt/pinentry/pinentry-{{version.raw}}.tar.bz2"
  strip-components = 1

  # `versions` resolves 1.3.3 as the newest. Fetched with `zpkb sourcepin`
  # (620687 bytes); the detached signature verified against the key file
  # gnupg.org links from its signature page, no keyserver:
  #
  #   signed by  6DAA6E64A76D2840571B4902528897B826403ADA
  #              Werner Koch (dist signing 2020)
  #   key file   https://gnupg.org/signature_key.asc
  #   fprs from  https://gnupg.org/signature_key.html
  #   signature  https://gnupg.org/ftp/gcrypt/pinentry/pinentry-1.3.3.tar.bz2.sig
  #
  # Checked when the digest was recorded, not at every build.
  sha256 = {
    "1.3.3" = "c2970f16d6afb66ecddfca767d743936c86239bff936eed7fd7597a678414b63"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"

    # configure.ac:239 NEED_GPG_ERROR_VERSION=1.16 and :255-256
    # NEED_LIBASSUAN_API=2 with 2.1.0: both mandatory (:875, :886 are their
    # errors). API 2 is the libassuan 2.x line, so `^2`, not `*`.
    "gnupg.org/libgpg-error" = "^1"
    "gnupg.org/libassuan"    = "^2"

    # m4/curses.m4:34-35 asks pkg-config for ncursesw, then ncurses, before
    # falling back to -lncursesw / -lncurses. The pantry's ncurses installs
    # both .pc files (--enable-pc-files), so the first probe answers.
    "invisible-island.net/ncurses" = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # Naming the staged prefixes stops the probes finding host copies
      # (m4/gpg-error.m4, m4/libassuan.m4).
      "--with-libgpg-error-prefix={{deps.gnupg.org/libgpg-error.prefix}}",
      "--with-libassuan-prefix={{deps.gnupg.org/libassuan.prefix}}",

      # The two front ends that are built. With "yes" a missing curses
      # library is an error (:299-305), not a silent skip (default is
      # "maybe", :277, :326).
      "--enable-pinentry-curses",
      "--enable-pinentry-tty",

      # :278-297 fallback-curses only makes the GUI pinentries fall back to
      # curses when X is absent. There is no GUI one here.
      "--disable-fallback-curses",

      # Every GUI front end, each default "maybe" (:436, :440, :572, :624,
      # :698, :780, :407) except emacs and tqt, which default to no (:355,
      # :735) and are stated anyway.
      "--disable-pinentry-gtk2",
      "--disable-pinentry-gnome3",
      "--disable-pinentry-qt",
      "--disable-pinentry-qt5",
      "--disable-pinentry-qt4",
      "--disable-pinentry-tqt",
      "--disable-pinentry-fltk",
      "--disable-pinentry-efl",
      "--disable-pinentry-emacs",
      "--disable-inside-emacs",

      # :488-505 caches the passphrase through libsecret when pkg-config
      # finds libsecret-1 (default "maybe"), which would link a desktop
      # service. Off.
      "--disable-libsecret",

      # :922 builds the manual with makeinfo unless disabled.
      "--disable-doc",
    ]
  }

  # :340 AM_ICONV is required for the curses build (:341-347) and is found in
  # the C library on glibc and macOS, so libiconv is not named here.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# tty/Makefile.am:22 pinentry-tty, curses/Makefile.am:22 pinentry-curses, and
# Makefile.am:120-128 links `pinentry` to $(PINENTRY_DEFAULT), which
# configure.ac:828-833 sets to pinentry-curses when it is built.
provides = [
  "bin/pinentry",
  "bin/pinentry-curses",
  "bin/pinentry-tty",
]

test {
  script = [
    "pinentry-tty --version",
    "pinentry-curses --version",
    "pinentry --version",
    "test \"$(readlink {{prefix}}/bin/pinentry)\" = pinentry-curses",
  ]
}

provenance {
  read = [
    "configure.ac",         # :239 NEED_GPG_ERROR_VERSION; :255-256 NEED_LIBASSUAN_API; :275-318 curses; :324-332 tty; :340-347 iconv; :353-398 emacs; :405-429 efl; :434-483 gtk2/gnome3; :488-512 libsecret; :570-624 qt5/qt6; :696 qt4; :733 tqt; :778-810 fltk; :816-833 PINENTRY_DEFAULT; :922 doc
    "m4/curses.m4",         # :31-37 ncursesw/ncurses through pkg-config
    "Makefile.am",          # :36-108 one conditional per front end; :120-128 the pinentry link
    "tty/Makefile.am",      # :22 bin_PROGRAMS = pinentry-tty
    "curses/Makefile.am",   # :22 bin_PROGRAMS = pinentry-curses
    "pinentry/pinentry.h",  # :7-18 licence, SPDX GPL-2.0+
    "https://gnupg.org/signature_key.html",
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the source and checked by `zpkb lint` and `zpkb
versions` only. The `pinentry` link target (pinentry-curses) was read from
configure.ac:828-829 and Makefile.am:128, not observed.
EOT
}
