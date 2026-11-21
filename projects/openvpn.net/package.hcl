# OpenVPN — the community VPN daemon (the `openvpn` program and two plug-ins).
#
# ⛔ WRITTEN FROM OPENVPN'S OWN FILES at 2.7.9 (go-zpkg/packages#440 step 1),
# replacing a fragment that named four dependencies and nothing else. Two of
# them are dropped, and the reasons are read from configure.ac:
#
#   - libnl (github.com/thom311/libnl) is only wanted by DATA CHANNEL OFFLOAD
#     (configure.ac:692-716). This recipe passes --disable-dco, which is the
#     choice that removes it; DCO also needs the ovpn kernel module at run time.
#   - net-tools (sourceforge.net/net-tools) is not used on Linux: configure.ac
#     builds its own netlink route code there (sitnl) and only the legacy
#     `--enable-iproute2` and non-Linux paths shell out. The fragment's entry
#     was a guess, not a requirement.
#
# libcap-ng IS required on Linux (configure.ac:756-769: PKG_CHECK_MODULES then
# AC_MSG_ERROR), and a recipe for it (github.com/stevegrubb/libcap-ng) is added
# beside this one.

summary = "OpenVPN community edition: a TLS VPN daemon with LZ4/LZO compression"

# COPYING:20 "OpenVPN is distributed under the GPL license version 2", followed
# by special exceptions for linking with OpenSSL (:22-32), with Apache-2.0
# libraries (:34-74) and with LZO (:76-). The exceptions are additions to the
# GPL-2.0-only grant, not a different license.
license = "GPL-2.0-only"

versions {
  github = "OpenVPN/openvpn"
}

dependencies = {
  # Required on Linux and nowhere else: configure.ac:756-769.
  linux = {
    "github.com/stevegrubb/libcap-ng" = "^0.9"
  }
  "lz4.org"           = "^1.9"
  "oberhumer.com/lzo" = "^2.10"
  "openssl.org"       = "^3"
}

distributable {
  # A STORED release asset of the GitHub release v2.7.9, next to its .asc. It is
  # a `make dist` tarball: it ships `configure`, so no autotools run.
  url              = "https://github.com/OpenVPN/openvpn/releases/download/v{{version.raw}}/openvpn-{{version.raw}}.tar.gz"
  strip-components = 1

  # 2.7.9: 2128894 bytes. Three witnesses besides the fetch that recorded it:
  #
  #   - GitHub's recorded asset digest for the release asset is
  #     sha256:c42a6ed8…daacb1, the digest below;
  #   - swupdate.openvpn.net/community/releases/openvpn-2.7.9.tar.gz, the
  #     project's own download host, serves a file of the SAME length (2128894);
  #   - openvpn-2.7.9.tar.gz.asc verifies with gpg: "Good signature" from a
  #     subkey (33DA 8C9E AE0E AE8C 7317 2C10 822F 6DF0 96D0 4874) of the
  #     primary key F554 A368 7412 CFFE BDEF E0A3 12F5 F7B4 2F2B 01E7.
  #
  # ⚠ THE KEY CAME FROM keys.openpgp.org BY FINGERPRINT, and the project prints
  # no fingerprint on any page read here, so the key's identity rests on that
  # keyserver. Fleet rules forbid a keyserver as a `zpkb sourcepin` key source,
  # so the signature is NOT recorded as a keyed pin: the pin below is a plain
  # sha256, and the gpg result is a witness, not a proof of who signed.
  sha256 = {
    "2.7.9" = "c42a6ed892ddfe2d6e3317a5040f19bec5827564affb2fe3f2b3904a94daacb1"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  # configure.ac finds lz4 (:1043-1044 `liblz4 >= 1.7.1`), lzo (:991-1003
  # `lzo2`), libcap-ng (:758) and OpenSSL (:778-780 `openssl >= 1.1.0`) through
  # pkg-config, and the build environment is closed, so the search path is built
  # from the declared dependencies.
  script = <<EOT
export PKG_CONFIG_PATH="{{deps.lz4.org.prefix}}/lib/pkgconfig:{{deps.oberhumer.com/lzo.prefix}}/lib/pkgconfig:{{deps.openssl.org.prefix}}/lib/pkgconfig:{{deps.openssl.org.prefix}}/lib64/pkgconfig:{{deps.github.com/stevegrubb/libcap-ng.prefix}}/lib/pkgconfig"
./configure $ARGS
make --jobs {{ hw.concurrency }}
make install
EOT

  # Every optional feature of configure.ac:57-289 is NAMED, so no outcome
  # depends on what the builder happens to have installed. Defaults are marked.
  env {
    ARGS = [
      "--prefix={{prefix}}",

      # Crypto and compression.
      "--with-crypto-library=openssl",      # :260-270, default openssl
      "--with-openssl-engine=auto",         # :279-289, default auto: only for OpenSSL < 3.0
      "--enable-lzo",                       # :57-62, default yes; needs lzo2 (:1190)
      "--enable-lz4",                       # :64-69, default yes; needs liblz4 >= 1.7.1
      "--disable-comp-stub",                # :71-76, default no; excludes lzo and lz4 (:1195-1197)
      "--enable-ofb-cfb",                   # :78-83, default yes

      # Protocol features, all at their defaults.
      "--enable-dns-updown-by-default",     # :85-90
      "--enable-ntlm",                      # :92-97
      "--enable-plugins",                   # :99-104
      "--enable-management",                # :106-111
      "--enable-fragment",                  # :120-125
      "--enable-port-share",                # :127-132
      "--enable-debug",                     # :134-139, default yes; gremlin and verb 7+
      "--disable-small",                    # :141-146, default no
      "--disable-async-push",               # :235-240, default no

      # Kernel and platform offloads: OFF, so libnl, iproute2, systemd and
      # SELinux are not needed.
      "--disable-dco",                      # :148-166, default auto on Linux; needs libnl and the ovpn module
      "--disable-iproute2",                 # :168-173, default no
      "--disable-systemd",                  # :228-233, default no
      "--disable-selinux",                  # :221-226, default no

      # Smart cards: OFF (needs libpkcs11-helper >= 1.11, :1203-1208).
      "--disable-pkcs11",                   # :113-118, default no

      # Plug-ins. auth-pam is OFF (default yes) because it needs libpam
      # (:1268-1274); down-root has no dependency and is kept.
      "--disable-plugin-auth-pam",          # :175-186
      "--enable-plugin-down-root",          # :188-198
      "--disable-pam-dlopen",               # :200-205, default no

      # Debugging options, all off, and no memory checker.
      "--disable-pedantic",                 # :207-212
      "--disable-werror",                   # :214-219
      "--with-mem-check=no",                # :248-258

      # The unit tests need cmocka (:1360-1364); off so the build does not
      # depend on whether cmocka happens to be installed.
      "--disable-unit-tests",               # :1351-1357
    ]
  }
}

# src/openvpn/Makefile.am:42 `sbin_PROGRAMS = openvpn`. The two plug-ins
# (src/plugins/down-root/Makefile.am:15) are shared objects under
# lib/openvpn/plugins, not programs.
provides = [
  "sbin/openvpn",
]

test {
  # `openvpn --version` prints the banner and exits with status 1, so its exit
  # status says nothing; the banner does.
  script = [
    "{{prefix}}/sbin/openvpn --version > openvpn-version.txt || true",
    "grep -q \"^OpenVPN {{version.raw}} \" openvpn-version.txt",
    "ls {{prefix}}/lib/openvpn/plugins/openvpn-plugin-down-root.* > /dev/null",
  ]
}

provenance {
  read = [
    "configure.ac",   # :57-289 every option; :692-716 DCO needs libnl; :756-769 libcap-ng on Linux; :991-1003 lzo2; :1043-1044 liblz4; :1195-1197 comp-stub; :1351-1364 unit tests and cmocka
    "version.m4",     # :4-8 PRODUCT_VERSION is MAJOR.MINOR.PATCH
    "COPYING",        # :20 GPL version 2; :22-32 OpenSSL exception; :34-74 Apache-2.0 exception; :76- LZO exception
    "src/openvpn/Makefile.am",                 # :42 sbin_PROGRAMS = openvpn
    "src/plugins/down-root/Makefile.am",       # :15 plugin_LTLIBRARIES
    "src/plugins/auth-pam/Makefile.am",        # :16 plugin_LTLIBRARIES (not built here)
  ]

  consulted = [
    "https://github.com/OpenVPN/openvpn/releases/tag/v2.7.9",
    "https://swupdate.openvpn.net/community/releases/",
  ]

  note = <<EOT
Rewritten from a fragment: the fragment's four dependencies were re-derived from
configure.ac rather than kept (libnl and net-tools dropped, libcap-ng added).

  asset digest  sha256:c42a6ed892ddfe2d6e3317a5040f19bec5827564affb2fe3f2b3904a94daacb1
                (GitHub's record, equal to the pin)
  signature     openvpn-2.7.9.tar.gz.asc, gpg: Good signature, subkey
                33DA8C9EAE0EAE8C73172C10822F6DF096D04874 of primary
                F554A3687412CFFEBDEFE0A312F5F7B42F2B01E7
  key source    keys.openpgp.org by fingerprint (a keyserver: no keyed pin is
                recorded, and the project prints no fingerprint)

⛔ THE BUILD AND THE TEST BLOCK WERE NOT RUN IN THIS SESSION. Stated rather than
implied. Two readings are unexercised: that every `--enable-X`/`--disable-X`
spelling above is accepted as written (they follow the AC_ARG_ENABLE names), and
that `openvpn --version` prints a line beginning "OpenVPN 2.7.9 " (src/openvpn/
options.c:72 builds title_string from PACKAGE_STRING and :4950 prints it; the
product name PACKAGE_STRING carries comes from version.m4, not opened past its
version lines).
The libcap-ng pkg-config path is built only for Linux builds' benefit; whether a
dependency declared under `linux` renders on macOS is checked by lint, not run.
EOT
}
