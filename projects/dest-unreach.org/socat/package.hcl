# dest-unreach.org/socat — socat, the multipurpose relay (SOcket CAT). This tree
# carried only a dependency list for it (a fragment, go-zpkg/packages#440 step 1);
# this is the whole recipe.
#
# ⛔ WRITTEN FROM SOCAT'S OWN FILES (go-zpkg/packages#431), at 1.8.1.3.
#
# ⭐⭐ WHAT WRITING IT FOUND: socat's two library features are PROBES THAT FALL BACK
# TO "NOT COMPILED IN", and neither has a way to make a miss fatal:
#   openssl   configure.ac:680-706, :768-774  `--enable-openssl-base=DIR` is taken
#             WITHOUT a check (:681-683), then libssl is linked (:717-745); when
#             that fails the only reaction is `AC_MSG_WARN([not all components of
#             OpenSSL found, disabling it])` (:772) and the build goes on.
#   readline  :616-667  tries the system, then /usr/local, /opt/local, /sw,
#             /opt/freeware and /usr/sfw in turn (:622); a miss is a WARNING
#             (:665). The macOS libedit is told apart by append_history (:635).
#   libwrap   :2304-2340  looks in /sw, /usr/local, /opt/freeware, /usr/sfw.
# So the test reads `socat -V` back for `#define WITH_OPENSSL 1` and
# `#define WITH_READLINE 1`, and a TLS round trip is run.

summary = "socat: multipurpose relay between two data channels (sockets, files, pipes, TLS, ...)"

# README:255-266: "GNU GPLv2", with a permission to link OpenSSL (the
# COPYING.OpenSSL file carries the OpenSSL and SSLeay licences it names);
# install-sh is MIT (README:256) and is not installed. No SPDX identifier names the
# OpenSSL linking permission, so it is stated here and not in the field.
license = "GPL-2.0-only"

versions {
  # ⛔ PLAIN HTTP, BECAUSE THE HOST'S HTTPS IS BROKEN: https://www.dest-unreach.org/
  # answers "x509: certificate is not valid for any names" (zpkb v0.94.0, and the
  # bare name dest-unreach.org does not resolve). The listing only chooses a version;
  # the bytes are pinned by sha256 below.
  url = "http://www.dest-unreach.org/socat/download/"

  # Four-component releases only: 1.8.1.3 is the newest stable. The directory also
  # lists 2.0.0-b9 and the older ones; a beta is not a release.
  match = "/socat-\\d+\\.\\d+\\.\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/socat-/", "/\\.tar\\.gz/"]
}

dependencies = {
  "gnu.org/readline"             = "^8.2"
  "invisible-island.net/ncurses" = "*"
  "openssl.org"                  = "^3"
}

distributable {
  # 767082 bytes. NO SIGNATURE: the project publishes none (no .asc under download/).
  # Its own digest file, https://www.dest-unreach.org/socat/download.sha256sum, lists
  # the same SHA-256 for socat-1.8.1.3.tar.gz as `zpkb sourcepin` computed. ⚠ It is on
  # the host that serves the archive: continuity, not independence.
  # Plain http for the reason given at `versions`: a tampered body fails the digest.
  url              = "http://www.dest-unreach.org/socat/download/socat-{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "1.8.1.3" = "06602ffd591e98c75b3dc1d66f0f19136cc666b0b2d95caad987d6ab2cb28097"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ OpenSSL, BY DIRECTORY (configure.ac:676-683); see the header for why a miss
      # is silent. The directory is also where :721 puts -L for libssl.
      "--enable-openssl-base={{deps.openssl.org.prefix}}",

      # ⛔ OFF: libwrap (:2296-2301) would link a tcpd that no recipe here provides
      # and that the builder may have; FIPS (:818-823) is off by default and needs
      # fipsld; named so a changed default shows here.
      "--disable-libwrap",
      "--disable-fips",
    ]

    # readline is found by AC_TRY_LINK on `-lreadline` plus `-lcurses`/`-lncurses`
    # (:637-647), with no DIR option: the declared prefixes go first, so the first
    # attempt (the default location) already succeeds and the /usr/local, /opt/local
    # ... fallbacks (:622) are never taken.
    CPPFLAGS = "-I{{deps.gnu.org/readline.prefix}}/include -I{{deps.invisible-island.net/ncurses.prefix}}/include -I{{deps.openssl.org.prefix}}/include"
    LDFLAGS  = "-L{{deps.gnu.org/readline.prefix}}/lib -L{{deps.invisible-island.net/ncurses.prefix}}/lib -L{{deps.openssl.org.prefix}}/lib"

    linux = {
      LDFLAGS = "-L{{deps.gnu.org/readline.prefix}}/lib -L{{deps.invisible-island.net/ncurses.prefix}}/lib -L{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.gnu.org/readline.prefix}}/lib -Wl,-rpath,{{deps.invisible-island.net/ncurses.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib"
    }
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Makefile.in:133-144: socat is installed as socat1 and `ln -sf socat1 socat`; the
# three shell scripts, procan and filan beside it.
provides = [
  "bin/filan",
  "bin/procan",
  "bin/socat",
  "bin/socat-broker.sh",
  "bin/socat-chain.sh",
  "bin/socat-mux.sh",
  "bin/socat1",
]

test {
  dependencies = {
    "openssl.org" = "^3"
  }

  script = [
    {
      run = <<EOT
set -eu
SOCAT="{{prefix}}/bin/socat"
"$SOCAT" -V > version.txt 2>&1
grep -q '^socat version {{version.raw}} ' version.txt
# the two probes that fall back silently (configure.ac:772, :665), read back
grep -q '#define WITH_OPENSSL 1' version.txt
grep -q '#define WITH_READLINE 1' version.txt
grep -q '#undef WITH_LIBWRAP' version.txt

# a TCP round trip through SYSTEM
"$SOCAT" TCP-LISTEN:38912,bind=127.0.0.1,reuseaddr SYSTEM:'echo tcp-ok' </dev/null > srv-tcp.log 2>&1 &
L=$!
trap 'kill $L 2>/dev/null || true' EXIT
sleep 1
"$SOCAT" -t 3 - TCP:127.0.0.1:38912 </dev/null > tcp.txt 2>&1
[ "$(cat tcp.txt)" = "tcp-ok" ]

# a TLS round trip: only possible when libssl is linked in
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -subj /CN=localhost -days 1 > /dev/null 2>&1
cat key.pem cert.pem > server.pem
"$SOCAT" OPENSSL-LISTEN:38913,bind=127.0.0.1,reuseaddr,cert=server.pem,verify=0 EXEC:'echo tls-ok' </dev/null > srv-tls.log 2>&1 &
L2=$!
trap 'kill $L $L2 2>/dev/null || true' EXIT
sleep 1
"$SOCAT" -t 3 - OPENSSL:127.0.0.1:38913,verify=0 </dev/null > tls.txt 2>/dev/null
[ "$(cat tls.txt)" = "tls-ok" ]

test -x "{{prefix}}/bin/procan"
test -x "{{prefix}}/bin/filan"
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",  # :680-706 and :768-774 openssl, :616-667 readline, :2295-2340 libwrap, :818-835 fips
    "Makefile.in",   # :133-144 what `install` installs
    "README",        # :252-266 the licence
    "COPYING",       # GPL version 2
    "COPYING.OpenSSL", # the OpenSSL and SSLeay licences named by the linking permission
    "https://www.dest-unreach.org/socat/download.sha256sum", # the project's own digests
  ]

  consulted = []

  note = <<EOT
NO SIGNATURE EXISTS; the pin is a SHA-256 computed by `zpkb sourcepin` that agrees with
the project's own digest file, https://www.dest-unreach.org/socat/download.sha256sum
(06602ffd... for socat-1.8.1.3.tar.gz). ⚠ That file is on the host that serves the
archive: continuity, not independence.

BUILT AND TESTED ON A MACHINE, NOT BY THE FACTORY: configure, make and make install
of this source, darwin/arm64, with Homebrew's openssl 3, readline and ncurses by
directory. `socat -V` printed `#define WITH_OPENSSL 1`, `#define WITH_READLINE 1` and
`#undef WITH_LIBWRAP`; a TCP round trip and a TLS round trip (self-signed
certificate, verify=0) returned their text. Other `#undef`s in that output
(SCTP is on, DCCP, VSOCK, TUN off) are the operating system's headers, which
configure probes, and are not a third-party library.

⛔ NOT BUILT BY THE FACTORY, NOT BUILT ON LINUX.
EOT
}
