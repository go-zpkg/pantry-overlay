# ldns — NLnet Labs' DNS programming library, and `drill`, the dig-alike built
# on it.
#
# ⛔ WRITTEN FROM LDNS'S OWN FILES at 1.9.2 (go-zpkg/packages#440 step 1). It
# was a three-line fragment declaring openssl.org and nothing else.

summary = "DNS programming library and the drill tool"

# LICENSE is the three-clause BSD text, "Copyright (c) 2005,2006, NLnetLabs":
# two retention/reproduction clauses and "Neither the name of NLnetLabs …".
license = "BSD-3-Clause"

versions {
  url   = "https://www.nlnetlabs.nl/downloads/ldns/"
  match = "/ldns-\\d+\\.\\d+\\.\\d+\\.tar\\.gz\"/"
  strip = [
    "/^ldns-/",
    "/\\.tar\\.gz\"$/",
  ]
}

distributable {
  url              = "https://www.nlnetlabs.nl/downloads/ldns/ldns-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.9.2: 1308193 bytes, signed 2026-06-10. Two witnesses, both from the
  # author and neither from this recipe's own fetch:
  #
  #   - ldns-1.9.2.tar.gz.sha256 beside the tarball on the same download page
  #     says b524fa21994b6e834200ceb8c27f1b84bda5982fe35706f058196c079db94d5d,
  #     which is the digest below;
  #   - ldns-1.9.2.tar.gz.asc is made by 2310 1869 0C4D 903E F419 146A A144 323D
  #     EAAC DF45, "NLnet Labs releases signing key G2". That fingerprint is
  #     PUBLISHED on https://nlnetlabs.nl/signing-keys, which is a page and not
  #     the key file, and the key itself was downloaded from
  #     https://nlnetlabs.nl/downloads/keys/releases-g2.asc and its fingerprint
  #     compared with the page's. No keyserver was asked.
  sha256 = {
    "1.9.2" = "b524fa21994b6e834200ceb8c27f1b84bda5982fe35706f058196c079db94d5d"
  }
}

build {
  dependencies = {
    "openssl.org" = "^3"
  }

  # ⛔ --with-ssl IS PASSED, NOT LEFT TO DETECTION. `configure.ac:356` is
  # ACX_WITH_SSL_OPTIONAL, whose argument defaults to "yes" (acx_nlnetlabs.m4
  # :843-845) — "look in the usual places" — so a builder with some other
  # libssl in /usr would link THAT one and the recipe would say nothing.
  #
  # --with-drill and --with-examples are both OFF by default
  # (`configure.ac:160-161` and `:184-185`, `with_drill="no"`,
  # `with_examples="no"`): without them the build is the library alone and
  # installs neither drill nor any ldns-* tool. They are the reason most
  # consumers want this package, so they are turned on.
  #
  # Left at their defaults, each for a stated reason: pyldns, pyldnsx and
  # DNS::LDNS are off (`:241-242`, `:327`) and need swig, python and perl;
  # --disable-gost and the draft RR types are not touched either.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }}
make install
EOT

  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--with-ssl={{deps.openssl.org.prefix}}",
      "--with-drill",
      "--with-examples",
    ]
  }
}

# Makefile.in:354 `install` runs install-config (:360-362, ldns-config into
# bindir), install-drill (:179-184) and install-examples (:230-240), which
# copies EXAMPLE_PROGS (:108) plus the four SSL examples (:117). Seven names,
# each one in those lists.
provides = [
  "bin/drill",
  "bin/ldns-config",
  "bin/ldns-keygen",
  "bin/ldns-read-zone",
  "bin/ldns-signzone",
  "bin/ldns-verify-zone",
  "bin/ldns-version",
]

test {
  script = [
    # drill.c:94 prints "<prog> version <DRILL_VERSION> (ldns version <lib>)":
    # the second number is the LIBRARY's, so a drill linked to another system
    # libldns would show a different one.
    "drill -v | grep 'ldns version {{version.raw}}'",
    "test \"$(ldns-version)\" = {{version.raw}}",
    # packaging/ldns-config.in:41 echoes @PACKAGE_VERSION@.
    "test \"$(ldns-config --version)\" = {{version.raw}}",
    "test -f {{prefix}}/include/ldns/ldns.h",
    "pkg-config --exists libldns",
    # A round trip through the tools: read a zone, generate a key, sign the
    # zone and verify the signature. Exercises the SSL half of the library,
    # which is the part --with-ssl decides.
    {
      run = "printf 'example.org. 3600 IN SOA ns.example.org. h.example.org. 1 7200 900 1209600 86400\\nexample.org. 3600 IN NS ns.example.org.\\nns.example.org. 3600 IN A 192.0.2.1\\n' > example.org.zone && ldns-read-zone example.org.zone > /dev/null && KEY=$(ldns-keygen -a ECDSAP256SHA256 example.org) && ldns-keygen -k -a ECDSAP256SHA256 example.org > /dev/null && ls K$KEY.* > /dev/null"
    },
  ]
}

provenance {
  read = [
    "configure.ac",      # :10 AC_INIT ldns; :160-161 --with-drill defaults to no; :184-185 --with-examples defaults to no; :208-220 ldns-config installed by default; :241-242 and :327 python/perl bindings off; :356 ACX_WITH_SSL_OPTIONAL
    "acx_nlnetlabs.m4",  # :839-847 ACX_WITH_SSL_OPTIONAL — the --with-ssl argument defaults to "yes" (detect)
    "Makefile.in",       # :108-117 example program lists; :179-184 install-drill; :230-240 install-examples; :354 install; :360-362 install-config
    "drill/drill.c",     # :92-94 the version line the test greps
    "packaging/ldns-config.in", # :41 --version prints PACKAGE_VERSION
    "packaging/libldns.pc.in",  # Name: ldns, the pkg-config module is libldns
    "LICENSE",           # three-clause BSD, "Copyright (c) 2005,2006, NLnetLabs"
  ]

  consulted = [
    "https://www.nlnetlabs.nl/downloads/ldns/",
    "https://nlnetlabs.nl/signing-keys",
  ]

  note = <<EOT
Written, not converted: the fragment this replaces declared a dependency and
nothing else.

⛔ THE TEST WAS NOT RUN ON A BUILT ldns IN THIS SESSION: the machine here has
no builder staged for it, so the recipe is checked by `zpkb versions` and the
lint gates and the test block is read against the sources above, not
executed. Stated rather than implied.
EOT
}
