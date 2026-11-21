# gnupg 2.5 — the GNU Privacy Guard development line: gpg, gpgsm, gpg-agent,
# dirmngr, keyboxd, scdaemon, ...
#
# WRITTEN FROM THE PROJECT'S OWN FILES at 2.5.24 (go-zpkg/packages#440). It was
# a fragment naming thirteen dependencies. It follows the whole 2.4 recipe
# (gnupg.org/package.hcl) and differs from it in three ways:
#
#   * SQLITE IS ON, so TOFU and keyboxd are built. configure.ac:927-957 makes
#     both depend on sqlite >= 3.27 (:80), found through pkg-config
#     (:934); sqlite.org is now a whole recipe.
#   * libassuan is API 3 (:65-66) and libgcrypt 1.12 (:62-63).
#   * libgpg-error must be 1.56 or newer (:60).
#
# LDAP IS OFF: openldap.org is a fragment. dirmngr still builds, with TLS from
# ntbtls; it has no CRL or X.509 search through LDAP. GnuTLS (named by the old
# fragment) is not used: ntbtls is the TLS library (:1009-1020).

summary = "GNU Privacy Guard: OpenPGP and S/MIME encryption and signing (2.5 line)"

# g10/gpg.c:8-11 "either version 3 of the License, or (at your option) any
# later version".
license = "GPL-3.0-or-later"

versions {
  url   = "https://gnupg.org/ftp/gcrypt/gnupg/"
  match = "/gnupg-2\\.5\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^gnupg-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://gnupg.org/ftp/gcrypt/gnupg/gnupg-{{version.raw}}.tar.bz2"
  strip-components = 1

  # `versions` resolves 2.5.24 as the newest 2.5.x (there is no 2.5.15). Fetched
  # with `zpkb sourcepin` (8431157 bytes); the detached signature verified
  # against the key file gnupg.org links from its signature page, no keyserver:
  #
  #   signed by  6DAA6E64A76D2840571B4902528897B826403ADA
  #              Werner Koch (dist signing 2020)
  #   signed at  2026-09-23T11:40:27Z
  #   also       AC8E115BF73E2D8D47FA9908E98E9B2D19C6C8BD, a second signature
  #              (2026-09-24, notation manu=2,2.5+1.12,2,2); both fingerprints
  #              are listed on the signature page
  #   key file   https://gnupg.org/signature_key.asc
  #   fprs from  https://gnupg.org/signature_key.html
  #   signature  https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.5.24.tar.bz2.sig
  #
  # Checked when the digest was recorded, not at every build.
  sha256 = {
    "2.5.24" = "bf149d01a2b9fcc0e4589b8ae8697d3d5c557ea48ed95a3fa55dd3b1187e6039"
  }
}

build {
  dependencies = {
    # configure.ac:60-75 NEED_GPGRT_VERSION=1.56, libgcrypt API 1 / 1.12.0,
    # libassuan API 3 / 3.0.0, ksba API 1 / 1.6.3, ntbtls API 1 / 0.2.0, npth
    # API 1 / 1.2.
    "gnupg.org/libgpg-error" = ">=1.56"
    "gnupg.org/libgcrypt"    = "^1.12"
    "gnupg.org/libassuan"    = "^3"
    "gnupg.org/libksba"      = "^1"
    "gnupg.org/npth"         = "^1"

    # ntbtls is the TLS library for dirmngr (:1009-1020); its 0.x line is API 1.
    "gnupg.org/ntbtls" = "^0"

    # The program gpg-agent runs to ask for a passphrase; its path is baked in
    # through --with-pinentry-pgm (:174-182).
    "gnupg.org/pinentry" = "*"

    # GNUPG_CHECK_READLINE (m4/readline.m4) for the gpg --edit-key prompt.
    "gnu.org/readline" = "^8"

    # :1458 zlib and :1483 bzip2, for compressed OpenPGP packets.
    "zlib.net"             = "^1"
    "sourceware.org/bzip2" = "*"

    # :927-957 TOFU and keyboxd; NEED_SQLITE_VERSION=3.27 (:80), probed with
    # PKG_CHECK_MODULES([SQLITE3], [sqlite3 >= 3.27]) (:934).
    "sqlite.org" = "^3"

    # The PKG_CHECK_MODULES probe above runs pkg-config.
    "freedesktop.org/pkg-config" = "^0.29"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # Naming the staged prefixes stops the probes finding host copies
      # (m4/gpg-error.m4, libgcrypt.m4, libassuan.m4, ksba.m4, npth.m4,
      # ntbtls.m4).
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

      # TLS: with ntbtls found, :1017-1019 uses it and never reaches the GnuTLS
      # probe (:1021-1040); --disable-gnutls says so outright, so a host
      # gnutls.pc cannot be picked up.
      "--enable-ntbtls",
      "--disable-gnutls",

      # SQLite, TOFU and keyboxd are ON (defaults, :927-930, :282, :132); named
      # so that a later change of default cannot turn them off silently.
      "--enable-sqlite",
      "--enable-tofu",
      "--enable-keyboxd",

      # LDAP: :1178 a "no" skips the probe. openldap.org is a fragment.
      "--disable-ldap",

      # :442 the CCID driver auto-detects libusb from the host; no libusb
      # recipe exists. scdaemon still builds, without its internal driver, and
      # talks to readers through PC/SC.
      "--disable-ccid-driver",

      # :133 GNUPG_BUILD_PROGRAM(tpm2d, yes): the TPM daemon is on by default
      # and :1546 then probes a host TSS library. No TSS recipe exists, so it is
      # off by name; --without-tss would NOT do it.
      "--disable-tpm2d",

      # :130 g13 is already off by default and needs encfs; :134 the manual
      # needs makeinfo.
      "--disable-g13",
      "--disable-doc",

      # :1216 sendmail is only used by gpg-wks-client; "no" skips the host path
      # probe so the build records no host program.
      "--with-mailprog=no",

      # AM_GNU_GETTEXT, external. A host libintl would otherwise be picked up
      # on macOS; translations are not built.
      "--disable-nls",

      # :1772 only decides whether `make check` runs tests.
      "--disable-tests",
    ]
  }

  # Left at their defaults: :292 libdns (bundled dns.c, no dependency), :339
  # zip, :348 bzip2, :356 exec, :426 card support, :449 dirmngr auto-start, and
  # :240 selinux and :418 capabilities (both default no).
  #
  # PKG_CONFIG_PATH is given in the script: the probe at :934 reads sqlite3.pc
  # from the staged prefix, and pkg-config's own default path is not the
  # sandbox's.
  script = <<EOT
export PKG_CONFIG_PATH="{{deps.sqlite.org.prefix}}/lib/pkgconfig"
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# bin_PROGRAMS: sm/Makefile.am gpgsm, agent/Makefile.am gpg-agent,
# dirmngr/Makefile.am dirmngr and dirmngr-client, tools/Makefile.am:72
# gpgconf gpg-connect-agent gpg-card, kbx/Makefile.am:35 kbxutil. keyboxd is
# a libexec program (kbx/Makefile.am:38). gpg and gpgv are noinst_PROGRAMS
# installed by the install-exec-hook into bindir.
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
  "bin/kbxutil",
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
    "configure.ac",        # :60-80 NEED_* versions; :126-140 GNUPG_BUILD_PROGRAM; :166-231 --with-*-pgm; :240-292 selinux, tofu, libdns; :418-449 capabilities, card, ccid; :927-957 sqlite, TOFU, keyboxd; :979 npth; :1009-1040 ntbtls, gnutls; :1178 ldap; :1216 mailprog; :1458-1483 zlib, bzip2; :1546 tss; :1772 tests
    "m4/readline.m4",      # GNUPG_CHECK_READLINE
    "g10/gpg.c",           # :8-11 licence
    "sm/Makefile.am",
    "agent/Makefile.am",
    "dirmngr/Makefile.am",
    "tools/Makefile.am",   # :72-88 bin_PROGRAMS
    "kbx/Makefile.am",     # :35-40 kbxutil, keyboxd (libexec), only with sqlite
    "https://gnupg.org/signature_key.html",
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the source and checked by `zpkb lint` and `zpkb
versions` only. LDAP is off because openldap.org is a fragment. sqlite.org's
pkg-config file (sqlite3.pc) was not observed in an install tree, only assumed
from the amalgamation's autoconf. The list in `provides` was read from the
Makefile.am files and was not observed in an install tree; scdaemon,
gpg-wks-client, gpgtar and the libexec programs are left out of it.
EOT
}
