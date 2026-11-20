# tcl-lang.org/tcltls — TclTLS, the OpenSSL binding that gives Tcl `package
# require tls` (TLS channels). One of the six packages of the tcl-lang.org
# monolith (go-zpkg/recipes#122 step 4).
#
# ⛔ WRITTEN FROM TCLTLS 2.0.1'S OWN FILES (go-zpkg/packages#431), read out of
# the release tarball, and BUILT, INSTALLED and LOADED in a scratch directory on
# darwin/arm64 against Tcl 9.0.4 and OpenSSL 3.6 (not by the factory).
#
# ⭐ WHAT READING IT FOUND:
#
#   1. THE MONOLITH BUILT A FOSSIL SNAPSHOT (`tcltls-e03e54ee87`, a generated
#      tarball) AND PATCHED IT WITH `sed` because no release built against
#      Tcl 9. There IS one now: the project's stored release file
#      `uv/tcltls2.0.1.tar.gz`. Measured: 1.7.22 — the release before it —
#      FAILS on Tcl 9.0.4 (`_ANSI_ARG_`/`CONST` are gone from Tcl 9; the
#      compile stops at tlsIO.c:25), and 2.0.1 configures, builds, installs and
#      loads. The `sed` over `SSL_SESSION_get0_ticket_appdata` is not carried:
#      2.0.1 compiled against OpenSSL 3.6 without it.
#   2. OpenSSL is located by `--with-openssl-dir`, whose misses are FATAL
#      (acinclude.m4:155 "Unable to locate ssl.h", :192 "Unable to locate
#      libssl"). Passed from the declared openssl.org.
#   3. Protocol switches (acinclude.m4:16-60): SSL3 is DISABLED by default
#      (:22 defines NO_SSL3 unless asked), TLS 1.0/1.1 stay enabled and are gated
#      by the OpenSSL library's own security level. Left at those defaults.
#      `--enable-hardening` defaults yes (:93, -fstack-protector-all,
#      _FORTIFY_SOURCE=2), `--enable-ssl-fastpath` defaults no (:80),
#      `--enable-static-ssl` no (:110): all restated below.

summary = "TclTLS: OpenSSL bindings for Tcl (package require tls)"

# license.terms: the TclTLS licence is the Tcl-style BSD licence of the
# original TLS extension (SPDX `TCL`).
license = "TCL"

dependencies = {
  "tcl-lang.org" = "*"
  "openssl.org"  = "^3"
}

# The project's own stored files, listed on its download page: names are
# `tcltls2.0.1.tar.gz` (and `tcltls-1.7.22.tar.gz` for older ones).
versions {
  url   = "https://core.tcl-lang.org/tcltls/uvlist?byage=1"
  match = "/tcltls\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = [
    "/^tcltls/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  # An unversioned file the maintainers UPLOADED to their fossil repository
  # (`uv/`): stored, so the pin is stable — unlike the `tarball/<hash>` route the
  # monolith used, which fossil generates. 401412 bytes, fetched twice by
  # independent means that agree: the builder's own fetcher (`zpkb sourcepin
  # --version 2.0.1 <url>`, zpkb v0.89.0) and curl + shasum. Unsigned: the
  # download page offers a file and no signature.
  url              = "https://core.tcl-lang.org/tcltls/uv/tcltls{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "2.0.1" = "afffeb5de1978f47745db4804c1dfdcd6605ceac32e324fe8bbe49843de0baae"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      # The default exec-prefix is Tcl's (tclConfig.sh), which would install the
      # library INTO TCL'S PREFIX; this package is its own.
      "--exec-prefix={{prefix}}",
      "--with-tcl={{deps.tcl-lang.org.prefix}}/lib",
      "--with-tclinclude={{deps.tcl-lang.org.prefix}}/include",

      # finding 2: located by directory, miss fatal.
      "--with-openssl-dir={{deps.openssl.org.prefix}}",

      # finding 3, restated so the artifact does not depend on a changed default:
      "--enable-hardening",
      "--disable-ssl3",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

runtime {
  env = {
    # A Tcl list, chained: see github.com/andreas-kupries/critcl.
    TCLLIBPATH = "{{prefix}}/lib $TCLLIBPATH"
  }
}

test {
  script = [
    "test -d \"{{prefix}}/lib/tcltls{{version.raw}}\"",
    {
      run = <<EOT
set -eu
cat > "$PWD/tlscheck.tcl" <<'TCL'
package require tls
if {![string match "OpenSSL 3.*" [tls::version]]} { puts stderr "not linked against OpenSSL 3: [tls::version]"; exit 1 }
if {"tls1.3" ni [tls::protocols]} { puts stderr "no TLS 1.3: [tls::protocols]"; exit 1 }
if {"ssl3" in [tls::protocols]} { puts stderr "SSL3 present"; exit 1 }
puts "tls [package present tls], [tls::version]"
TCL
TCLLIBPATH="{{prefix}}/lib" "{{deps.tcl-lang.org.prefix}}/bin/tclsh" "$PWD/tlscheck.tcl"
EOT
    },
  ]
}

provenance {
  read = [
    "configure --help",   # 2.0.1: the switch list
    "acinclude.m4",       # :16-60 protocol switches; :76-113 fastpath, hardening, static-ssl; :117-282 the OpenSSL location options and their fatal misses
    "license.terms",
    "https://core.tcl-lang.org/tcltls/wiki/Download", # the stored release file
    "https://core.tcl-lang.org/tcltls/uvlist?byage=1", # lists 2.0.1 and 1.7.22 as uploaded files
  ]

  consulted = [
    "pkgxdev/pantry projects/tcl-lang.org/package.yml", # facts only: the snapshot and the sed it patched; neither is carried
  ]

  note = <<EOT
⛔ BUILT AND LOADED HERE IN SCRATCH, against Homebrew's OpenSSL 3.6 and the
Tcl 9.0.4 of the core recipe: configure, make, make install, then
`package require tls` printed "OpenSSL 3.6.5", listed tls1 through tls1.3, and
listed no ssl3. 1.7.22 was built first and failed on Tcl 9. Not run: linux,
the factory, a TLS handshake, an 8.6 Tcl (2.0.1 has `--with-tcl8` for Tcl 8
in a Tcl 9 environment, not used here).

⚠ Unsigned; the digest is of a stored file, confirmed by two fetches.
EOT
}
