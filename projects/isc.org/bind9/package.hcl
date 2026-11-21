# BIND 9 — ISC's DNS server (named), resolver tools (dig, host, nslookup, delv),
# nsupdate, rndc and the DNSSEC utilities.
#
# ⛔ WRITTEN FROM BIND'S OWN FILES at 9.20.31 (go-zpkg/packages#440 step 1).
# It was a fragment: dependencies and a build script, but no versions and no
# distributable, so it could not resolve alone.
#
# THE FRAGMENT'S BUILD WAS REWRITTEN, not kept, for three reasons read from
# configure.ac of 9.20.31:
#
#   - it pulled meson, cmake and ninja for the >=9.21.10 branch. 9.21.x is the
#     ODD, development line: ISC's stable lines are the even minors (9.18,
#     9.20), and this recipe resolves only those, so every version it can
#     resolve is autotools and none of the three is needed;
#   - it pulled liblmdb and jemalloc, both optional: `--without-lmdb`
#     (configure.ac:864) and `--without-jemalloc` (:1331) are real options, so
#     both are declared OFF rather than built. Dropping lmdb also drops the
#     patchelf fix-up that existed only to repair its DT_NEEDED entry;
#   - `--with-openssl=` is not an option of this configure at all (OpenSSL is
#     found through pkg-config, :670).

summary = "ISC BIND 9 DNS server, dig, nsupdate and the DNSSEC tools"

# COPYRIGHT:3-5 "This Source Code Form is subject to the terms of the Mozilla
# Public License, v. 2.0"; LICENSE:1 "Mozilla Public License, version 2.0".
license = "MPL-2.0"

versions {
  # ISC's download directory has one directory per release. Only the EVEN
  # minors are stable (9.18, 9.20, 9.22, ...); 9.19, 9.21 and the like are the
  # development lines and are not resolved. 9.21.10 and later also switched to
  # meson, which this recipe does not carry.
  url   = "https://downloads.isc.org/isc/bind9/"
  match = "/href=\"9\\.(18|2[02468])\\.\\d+\\/\"/"
  strip = [
    "/^href=\"/",
    "/\\/\"$/",
  ]
}

distributable {
  url              = "https://downloads.isc.org/isc/bind9/{{version.raw}}/bind-{{version.raw}}.tar.xz"
  strip-components = 1

  # 9.20.31: 6019280 bytes. Beside the tarball ISC publishes only an .asc, no
  # checksum file, so the second witness is the signature, verified:
  #
  #   zpkb sourcepin --sig auto --key-source https://www.isc.org/pgpkey/ \
  #     --fingerprint 706B6C28620E76F91D11F7DF510A642A06C52CEC --version 9.20.31
  #
  #   - signer Michał Kępień, signed 2026-11-09T14:03:02Z;
  #   - the key file is https://www.isc.org/docs/isc-keyblock.asc (7 keys);
  #   - the fingerprint comes from a DIFFERENT page, https://www.isc.org/pgpkey/,
  #     which lists ISC's signing fingerprints, so key and fingerprint are not
  #     both taken from one place.
  sha256 = {
    "9.20.31" = "9bfecd503ec79209d321053689c794da9f8dba993a24e9cd6bd7aa87cdf4122f"
  }
}

dependencies = {
  "github.com/json-c/json-c" = "^0.19"
  "gnome.org/libxml2"        = "^2.13"
  "gnu.org/libidn2"          = "^2"
  "gnu.org/readline"         = "^8"
  linux = {
    "kernel.org/libcap" = "^2"
  }
  "liburcu.org" = "^0.15"
  "libuv.org"   = "^1"
  "nghttp2.org" = "^1"
  "openssl.org" = "^3"
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  # configure.ac finds every library through PKG_CONFIG_PATH and refuses a
  # path for libxml2 (:914), json-c (:934) and nghttp2 (:627): "adjust
  # PKG_CONFIG_PATH instead". The build environment is closed, so the path is
  # built from the declared dependencies.
  script = <<EOT
export PKG_CONFIG_PATH="{{deps.libuv.org.prefix}}/lib/pkgconfig:{{deps.liburcu.org.prefix}}/lib/pkgconfig:{{deps.openssl.org.prefix}}/lib/pkgconfig:{{deps.openssl.org.prefix}}/lib64/pkgconfig:{{deps.github.com/json-c/json-c.prefix}}/lib/pkgconfig:{{deps.gnome.org/libxml2.prefix}}/lib/pkgconfig:{{deps.gnu.org/libidn2.prefix}}/lib/pkgconfig:{{deps.gnu.org/readline.prefix}}/lib/pkgconfig:{{deps.nghttp2.org.prefix}}/lib/pkgconfig"
./configure $ARGS
make --jobs {{ hw.concurrency }}
make install
EOT

  # Every optional library is NAMED, so no outcome depends on what the builder
  # happens to have installed:
  #   ON  json-c (:922), libxml2 (:902, statistics channel), libidn2 (:1282,
  #       default is no), readline (:1025), DoH through nghttp2 (:610-627);
  #   OFF jemalloc (:1331), lmdb (:864), GeoIP (:512, default yes), GSSAPI
  #       (:797, default auto), zlib (:946, HTTP compression, default auto).
  # liburcu is mandatory (:241) and OpenSSL is mandatory (:670).
  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--with-json-c=yes",
      "--with-libxml2=yes",
      "--with-libidn2=yes",
      "--with-readline=readline",
      "--enable-doh",
      "--with-libnghttp2=yes",
      "--without-jemalloc",
      "--without-lmdb",
      "--disable-geoip",
      "--without-gssapi",
      "--without-zlib",
    ]
  }
}

# bin/*/Makefile.am: bin_PROGRAMS (dig host nslookup delv nsupdate
# named-checkconf named-checkzone) and sbin_PROGRAMS (named rndc rndc-confgen
# tsig-keygen).
provides = [
  "bin/delv",
  "bin/dig",
  "bin/host",
  "bin/named-checkconf",
  "bin/named-checkzone",
  "bin/nslookup",
  "bin/nsupdate",
  "sbin/named",
  "sbin/rndc",
  "sbin/rndc-confgen",
  "sbin/tsig-keygen",
]

test {
  script = [
    "named -V | grep -F 'BIND {{version.raw}}'",
    "dig -v 2>&1 | grep -F '{{version.raw}}'",
    "named -V | grep -F 'json-c'",
    "named -V | grep -F 'libxml2'",
  ]
}

provenance {
  read = [
    "configure.ac",  # :211-244 liburcu mandatory; :610-627 DoH/nghttp2; :864 lmdb; :902-914 libxml2; :922-934 json-c; :1025 readline; :1282 libidn2; :1331 jemalloc; :1071-1074 libcap on Linux
    "COPYRIGHT",     # :3-5 MPL-2.0
    "LICENSE",       # :1 Mozilla Public License, version 2.0
    "bin/dig/Makefile.am",  # :24 bin_PROGRAMS = dig host nslookup
    "bin/named/Makefile.am", # :37 sbin_PROGRAMS = named
  ]

  consulted = [
    "https://downloads.isc.org/isc/bind9/",
    "https://www.isc.org/pgpkey/",
    "https://www.isc.org/docs/isc-keyblock.asc",
  ]

  note = <<EOT
Written, not converted: the fragment had no versions or distributable.

Signature (sourcepin, 9.20.31): made by Michał Kępień, 2026-11-09T14:03:02Z,
fingerprint 706B6C28620E76F91D11F7DF510A642A06C52CEC, listed on
https://www.isc.org/pgpkey/; key file https://www.isc.org/docs/isc-keyblock.asc.

Dependencies declared OFF from the project's own options instead of being
written as recipes: jemalloc.net (--without-jemalloc), openldap.org/liblmdb
(--without-lmdb; upstream publishes no stored release asset anyway) and
mesonbuild.com (only the development 9.21.10+ line needs it, and this recipe
resolves the stable even minors only).

⛔ THE BUILD AND THE TEST BLOCK WERE NOT RUN IN THIS SESSION. The configure
options were read from configure.ac, not exercised. Stated rather than implied.
EOT
}
