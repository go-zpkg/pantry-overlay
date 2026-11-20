# unbound — NLnet Labs' validating, recursive, caching DNS resolver, and
# libunbound.
#
# ⛔ WRITTEN FROM UNBOUND'S OWN FILES at 1.26.2 (go-zpkg/packages#440 step 1).
# It was a fragment: dependencies and a build script, but no versions and no
# distributable, so it could not resolve alone. The dependency list and the
# build script are KEPT from it, re-read against configure.ac below.

summary = "Validating, recursive, caching DNS resolver and libunbound"

# LICENSE is the three-clause BSD text: "Copyright (c) 2007, NLnet Labs. All
# rights reserved.", the two redistribution clauses and "Neither the name of
# the NLNET LABS nor the names of its contributors …".
license = "BSD-3-Clause"

versions {
  url   = "https://www.nlnetlabs.nl/downloads/unbound/"
  match = "/unbound-\\d+\\.\\d+\\.\\d+\\.tar\\.gz\"/"
  strip = [
    "/^unbound-/",
    "/\\.tar\\.gz\"$/",
  ]
}

distributable {
  url              = "https://www.nlnetlabs.nl/downloads/unbound/unbound-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.26.2: 6949796 bytes, signed 2026-10-21. Two witnesses, both from the
  # author and neither from this recipe's own fetch:
  #
  #   - unbound-1.26.2.tar.gz.sha256 beside the tarball on the same download
  #     page says d8ee7aa6bbb3ff1be7d9e57637d0d0ec2f18273a8efff1a0afe2c665858b96f7,
  #     which is the digest below;
  #   - unbound-1.26.2.tar.gz.asc is made by 2310 1869 0C4D 903E F419 146A A144
  #     323D EAAC DF45, "NLnet Labs releases signing key G2" — the same key
  #     that signs nlnetlabs.nl/ldns. The fingerprint is PUBLISHED on
  #     https://nlnetlabs.nl/signing-keys (a page, not the key file); the key
  #     was downloaded from https://nlnetlabs.nl/downloads/keys/releases-g2.asc
  #     and its fingerprint compared with the page's. No keyserver was asked.
  sha256 = {
    "1.26.2" = "d8ee7aa6bbb3ff1be7d9e57637d0d0ec2f18273a8efff1a0afe2c665858b96f7"
  }
}

dependencies = {
  "libexpat.github.io" = "^2"
  "openssl.org"        = "^3"
}

build {
  # flex and bison are kept from the fragment, for a reason read from
  # Makefile.in rather than assumed: the tarball SHIPS util/configlexer.c and
  # util/configparser.c, but rules at :507 and :518 regenerate them with $(LEX)
  # and $(YACC) whenever the .lex/.y is newer, and an extracted tarball does
  # not promise the timestamp order. With the tools staged the outcome cannot
  # depend on that.
  dependencies = {
    "github.com/westes/flex" = "*"
    "gnu.org/bison"          = "^3"
    "libexpat.github.io"     = "*"
  }

  # ⛔⛔ THE VARIABLE WAS $PKGX_DIR, WHICH NOTHING SETS — AND AN EMPTY LEFT-HAND
  # SIDE IS NOT A NO-OP. zpkb runs every build script under a CLOSED environment
  # (`build.SanitizedEnv`, build/build.go:745-769: PATH, HOME, ZPKG_DIR,
  # MAKEFLAGS, FORCE_UNSAFE_CONFIGURE, plus the ZPKG_DIST/PANTRY/VERIFY
  # pass-through). `PKGX_DIR` is in neither that list nor anywhere else in zpkb
  # or artifact's sources — the store variable has been `ZPKG_DIR` since the
  # rename (build/build.go:749, cmd/zpkb/builder.go:626, artifact/pkgx.go:381).
  #
  # So the substitution ran as `s|/|$PKGX_DIR/|g`: not "replace the store
  # path", but "replace EVERY SLASH", which rewrites every absolute path in
  # `unbound-control-setup` and then deletes the .bak that would have shown it.
  # A build does not fail on it — sed exits 0 — so only the installed script is
  # wrong. Both sides renamed; the right-hand side stays escaped, since what it
  # writes is the literal text `$ZPKG_DIR/` for the installed script to expand.
  #
  # Why the script has a store path in it at all: smallapp/unbound-control-
  # setup.sh.in:39 is `DESTDIR=@ub_conf_dir@`, and configure.ac:205 makes
  # ub_conf_dir the directory of ${sysconfdir}/unbound/unbound.conf — under the
  # prefix, so absolute.
  script = <<EOT
./configure $ARGS
make -j {{ hw.concurrency }} install

cd {{prefix}}/bin
sed -i.bak -e "s|$ZPKG_DIR/|\$ZPKG_DIR/|g" unbound-control-setup
rm unbound-control-setup.bak
EOT

  # Left at their defaults, each off or detected from a stated place:
  # libevent (`configure.ac:1499-1500`), hiredis (:1618-1619), nghttp2 (:1650-
  # 1651) and ngtcp2 (:1682-1683) all default to "no"; systemd is off
  # (systemd.m4:5-6); python modules are off (:869, :881). Only expat is
  # mandatory (:1609-1611 is an AC_MSG_ERROR) and ssl is mandatory (:1052,
  # ACX_WITH_SSL), so those two are passed explicitly.
  env {
    ARGS = [
      "--prefix={{ prefix }}",
      "--sbindir={{ prefix }}/bin",
      "--with-ssl={{ deps.openssl.org.prefix }}",
      "--with-libexpat={{ deps.libexpat.github.io.prefix }}",
    ]
    CFLAGS = "-Werror=implicit-function-declaration"
  }
}

# Makefile.in:625-629 and :637 install six programs into $(sbindir), which
# --sbindir above makes bin/.
provides = [
  "bin/unbound",
  "bin/unbound-anchor",
  "bin/unbound-checkconf",
  "bin/unbound-control",
  "bin/unbound-control-setup",
  "bin/unbound-host",
]

test {
  script = [
    "unbound -V | grep 'Version {{version.raw}}'",
    "test -f {{prefix}}/include/unbound.h",
    "pkg-config --exists libunbound",
    # unbound-checkconf parses a config with the same lexer/parser the daemon
    # uses, so it exercises the generated util/configlexer.c.
    {
      run = "printf 'server:\\n  verbosity: 1\\n  interface: 127.0.0.1\\n' > test.conf && unbound-checkconf test.conf"
    },
    # The relocation edit the build makes: the installed script must name the
    # variable, not the store path that built it.
    "grep -F '$ZPKG_DIR' {{prefix}}/bin/unbound-control-setup",
  ]
}

provenance {
  read = [
    "configure.ac",         # :16 AC_INIT unbound; :190-206 sysconfdir/unbound is the config dir; :1052 ACX_WITH_SSL; :1499-1500 libevent defaults to no; :1593-1611 libexpat is mandatory; :1618-1651 hiredis and nghttp2 default to no
    "systemd.m4",           # :5-6 --enable-systemd defaults to no
    "Makefile.in",          # :507-520 util/configlexer.c and configparser.c regenerated through LEX and YACC; :595-638 install-all installs the six programs into sbindir; :613-616 libunbound.h/.pc/.la
    "smallapp/unbound-control-setup.sh.in", # :39 DESTDIR=@ub_conf_dir@ — the store path the build's sed rewrites
    "LICENSE",              # three-clause BSD, "Copyright (c) 2007, NLnet Labs"
  ]

  consulted = [
    "https://www.nlnetlabs.nl/downloads/unbound/",
    "https://nlnetlabs.nl/signing-keys",
    "go-zpkg/zpkb build/build.go", # :745-769 the closed build environment the sed edit relies on
  ]

  note = <<EOT
Written from the fragment plus the sources above. The fragment's dependency
list and its build script, including the corrected ZPKG_DIR edit, are kept;
what was missing was the version source, the distributable and its digest.

⛔ THE TEST BLOCK WAS NOT RUN ON A BUILT unbound IN THIS SESSION. The recipe
is checked with `zpkb versions` and the lint gates; the assertions are read
from the sources cited above, and the fix-up of unbound-control-setup is
asserted by name rather than by value. Stated rather than implied.
EOT
}
