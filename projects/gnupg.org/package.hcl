# gnupg — the GNU Privacy Guard: gpg, gpgsm, gpg-agent, dirmngr, scdaemon, ...
#
# WRITTEN FROM THE PROJECT'S OWN FILES at 2.4.9 (go-zpkg/packages#440). It was
# a fragment naming eleven dependencies.
#
# THIS IS THE 2.4 LINE (the stable branch). The 2.5 line lives in
# gnupg.org/v2.5 and waits for sqlite.org.
#
# TOFU AND KEYBOXD ARE ABSENT until sqlite.org exists (blocked on
# go-zpkg/artifact#238). configure.ac:942-969 makes them depend on sqlite and
# turns both off, with a warning, when it is missing; here it is turned off by
# name so that a host copy cannot change the answer.
#
# LDAP IS OFF: openldap.org is a fragment. dirmngr still builds, with TLS from
# ntbtls; it has no CRL or X.509 search through LDAP.

summary = "GNU Privacy Guard: OpenPGP and S/MIME encryption and signing (2.4 line)"

# g10/gpg.c:8-11 "either version 3 of the License, or (at your option) any
# later version".
license = "GPL-3.0-or-later"

versions {
  url   = "https://gnupg.org/ftp/gcrypt/gnupg/"
  match = "/gnupg-2\\.4\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^gnupg-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://gnupg.org/ftp/gcrypt/gnupg/gnupg-{{version.raw}}.tar.bz2"
  strip-components = 1

  # `versions` resolves 2.4.9 as the newest 2.4.x. Fetched with `zpkb
  # sourcepin` (8086407 bytes); the detached signature verified against the key
  # file gnupg.org links from its signature page, no keyserver:
  #
  #   signed by  6DAA6E64A76D2840571B4902528897B826403ADA
  #              Werner Koch (dist signing 2020)
  #   key file   https://gnupg.org/signature_key.asc
  #   fprs from  https://gnupg.org/signature_key.html
  #   signature  https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.4.9.tar.bz2.sig
  #
  # Checked when the digest was recorded, not at every build.
  sha256 = {
    "2.4.9" = "dd17ab2e9a04fd79d39d853f599cbc852062ddb9ab52a4ddeb4176fd8b302964"
  }
}

build {
  dependencies = {
    # configure.ac:58-73 NEED_GPGRT_VERSION=1.46, libgcrypt API 1 / 1.9.1,
    # libassuan API 2 / 2.5.0, ksba API 1 / 1.6.3, ntbtls API 1 / 0.2.0, npth
    # API 1 / 1.2. The pantry's libassuan 3.x is API 3, so `^2`.
    "gnupg.org/libgpg-error" = "^1"
    "gnupg.org/libgcrypt"    = "^1"
    "gnupg.org/libassuan"    = "^2"
    "gnupg.org/libksba"      = "^1"
    "gnupg.org/npth"         = "^1"

    # ntbtls is the TLS library for dirmngr (:1020-1034); its 0.x line is API 1.
    "gnupg.org/ntbtls" = "^0"

    # The program gpg-agent runs to ask for a passphrase; its path is baked in
    # through --with-pinentry-pgm (:172-176).
    "gnupg.org/pinentry" = "*"

    # GNUPG_CHECK_READLINE (:1526, m4/readline.m4:14-33) for the gpg --edit-key
    # prompt; it tries -lreadline bare first, then with termcap/curses.
    "gnu.org/readline" = "^8"

    # :1468-1487 zlib and :1493-1520 bzip2, for compressed OpenPGP packets.
    "zlib.net"             = "^1"
    "sourceware.org/bzip2" = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # Naming the staged prefixes stops the probes finding host copies
      # (m4/gpg-error.m4:24, libgcrypt.m4:32, libassuan.m4:20, ksba.m4:29,
      # npth.m4:15, ntbtls.m4:28).
      "--with-libgpg-error-prefix={{deps.gnupg.org/libgpg-error.prefix}}",
      "--with-libgcrypt-prefix={{deps.gnupg.org/libgcrypt.prefix}}",
      "--with-libassuan-prefix={{deps.gnupg.org/libassuan.prefix}}",
      "--with-libksba-prefix={{deps.gnupg.org/libksba.prefix}}",
      "--with-npth-prefix={{deps.gnupg.org/npth.prefix}}",
      "--with-ntbtls-prefix={{deps.gnupg.org/ntbtls.prefix}}",

      "--with-pinentry-pgm={{deps.gnupg.org/pinentry.prefix}}/bin/pinentry",
      "--with-readline={{deps.gnu.org/readline.prefix}}",
      "--with-zlib={{deps.zlib.net.prefix}}",
      "--with-bzip2={{deps.sourceware.org/bzip2.prefix}}",

      # TLS: with ntbtls found, :1032-1034 uses it and never reaches the
      # GnuTLS probe (:1035-1059); --disable-gnutls (:1036-1039) says so
      # outright, so a host gnutls.pc cannot be picked up.
      "--enable-ntbtls",
      "--disable-gnutls",

      # SQLite: :942-945 default yes; :947-969 TOFU and keyboxd need it. The
      # pantry has no sqlite.org yet, so both are off by name (:292-295 for
      # tofu) and the probe is skipped.
      "--disable-sqlite",
      "--disable-tofu",

      # LDAP: :1193-1196 a "no" sets gnupg_have_ldap=no and skips the probe
      # (:1198-1208). openldap.org is a fragment.
      "--disable-ldap",

      # :863-884 the CCID driver auto-detects libusb from the host; no libusb
      # recipe exists. :452-457 turns the driver off; scdaemon still builds,
      # without its internal driver (:1824-1830), and talks to readers through
      # PC/SC.
      "--disable-ccid-driver",

      # :131 GNUPG_BUILD_PROGRAM(tpm2d, yes) (acinclude.m4:123-134): the TPM
      # daemon is on by default and :1566-1625 then probes a host TSS library.
      # No TSS recipe exists, so it is off by name; --without-tss would NOT do
      # it, since :1580 refuses any other value than ibm, intel or autodetect.
      "--disable-tpm2d",

      # :130 keyboxd needs sqlite (:967-969 sets it to no without it); off by
      # name. :128 g13 is already off by default and needs encfs; :132 the
      # manual needs makeinfo.
      "--disable-keyboxd",
      "--disable-g13",
      "--disable-doc",

      # :1231-1243 sendmail is only used by gpg-wks-client; "no" skips the host
      # path probe so the build records no host program.
      "--with-mailprog=no",

      # :1297 AM_GNU_GETTEXT, external. A host libintl would otherwise be picked
      # up on macOS; translations are not built.
      "--disable-nls",

      # :1783-1787 only decides whether `make check` runs tests.
      "--disable-tests",
    ]
  }

  # Left at their defaults: :302-305 libdns (bundled dns.c, no dependency),
  # :349 zip, :358 bzip2, :366 exec, :436 card support, :459 dirmngr
  # auto-start, and :250-253 selinux and :428-430 capabilities (both default
  # no).
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# bin_PROGRAMS: sm/Makefile.am:23 gpgsm, agent/Makefile.am:21 gpg-agent,
# dirmngr/Makefile.am:34 dirmngr and dirmngr-client, tools/Makefile.am:65
# gpgconf gpg-connect-agent gpg-card. (g13 is off, :128.) gpg and gpgv are noinst_PROGRAMS (g10/Makefile.am:51-52) installed by the
# install-exec-hook (:214-244) into bindir.
provides = [
  "bin/dirmngr",
  "bin/dirmngr-client",
  "bin/gpg",
  "bin/gpg-agent",
  "bin/gpg-card",
  "bin/gpg-connect-agent",
  "bin/gpgconf",
  "bin/gpgsm",
  "bin/gpgv",
]

test {
  script = [
    "gpg --version",
    "gpgv --version",
    "gpgsm --version",
    "gpgconf --version",
    "gpg-agent --version",
    "dirmngr --version",
  ]
}

provenance {
  read = [
    "configure.ac",        # :58-78 NEED_* versions; :164-231 --with-*-pgm; :292-295 tofu; :302-305 libdns; :428-460 capabilities, card, ccid; :808-856 required libraries; :863-926 libusb; :942-976 sqlite, TOFU, keyboxd; :994-1059 npth, ntbtls, gnutls; :1193-1221 ldap; :1231-1243 mailprog; :1294-1297 gettext; :1468-1522 zlib, bzip2; :1526 readline; :1559-1625 tss; :1783-1787 tests
    "m4/readline.m4",      # :14-33 GNUPG_CHECK_READLINE
    "g10/gpg.c",           # :8-11 licence
    "g10/Makefile.am",     # :51-52 gpg, gpgv; :211-244 install hook
    "sm/Makefile.am",      # :23
    "agent/Makefile.am",   # :21-24
    "dirmngr/Makefile.am", # :34-40
    "tools/Makefile.am",   # :65-67
    "kbx/Makefile.am",     # :35-40 keyboxd, only with sqlite
    "acinclude.m4",        # :117-142 GNUPG_BUILD_PROGRAM
    "https://gnupg.org/signature_key.html",
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the source and checked by `zpkb lint` and `zpkb
versions` only. TOFU/keyboxd absent until sqlite.org exists (blocked on
go-zpkg/artifact#238). LDAP is off because openldap.org is a fragment. The
list in `provides` was read from the Makefile.am files and was not observed in
an install tree; scdaemon, gpg-wks-client and the libexec programs are left
out of it.
EOT
}
