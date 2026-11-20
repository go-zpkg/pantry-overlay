# github.com/esnet/iperf — iperf3, the network throughput measurement tool, and
# its library libiperf.
#
# ⛔ WRITTEN FROM IPERF'S OWN FILES (go-zpkg/packages#431), at 3.22.1, from the
# release tarball's configure.ac, src/Makefile.am, src/iperf_locale.c, LICENSE.
#
# ⭐⭐ WHAT WRITING IT FOUND: configure.ac decides two features by looking at
# the build machine and says nothing when it does not find them.
#
#   OpenSSL (configure.ac:171-193)  with no --with-openssl, AX_CHECK_OPENSSL
#       fails SILENTLY and the build continues without HAVE_SSL: iperf3 is then
#       built without --username / --rsa-public-key-path authentication, and
#       the only mention is a line in config.log. `--with-openssl=DIR` turns
#       the failure into AC_MSG_FAILURE (:179-181).
#   SCTP (configure.ac:124-161)     `netinet/sctp.h` present means `--sctp`
#       is compiled in and libsctp is linked; absent, silently not. On a glibc
#       builder it depends on whether lksctp-tools-devel is installed.
#
# Both are named below; the test reads each back from `iperf3 --help`.

summary = "iperf3: measures the maximum achievable network bandwidth (TCP, UDP, SCTP)"

# LICENSE:1-39 is the LBNL-modified BSD 3-clause ("iperf, Copyright (c)
# 2014-2026, The Regents of the University of California, through Lawrence
# Berkeley National Laboratory"), and LICENSE carries the notices of code the
# build COMPILES IN, each read from its section:
#
#   MIT           src/cjson.{c,h} (:43-63), src/net.{c,h} (Russ Cox, MIT, :67-91)
#   BSD-3-Clause  src/net.c (Eric Jackson, :113-140), src/queue.h (UC Regents, :144-175)
#   LicenseRef-iperf-lucent        the Lucent notice inside src/net.* (:95-109)
#   LicenseRef-iperf-illinois      src/units.{c,h} (:179-), the University of
#                                  Illinois Iperf-2 permission notice, which
#                                  carries extra conditions
license = "BSD-3-Clause-LBNL AND MIT AND BSD-3-Clause AND LicenseRef-iperf-lucent AND LicenseRef-iperf-illinois"

versions {
  github = "esnet/iperf"
}

dependencies = {
  # --with-openssl below makes a missing OpenSSL FATAL.
  "openssl.org" = "^3"
}

distributable {
  # The release asset, built by the maintainers: it carries a generated
  # `configure`, so no autotools are needed here.
  url              = "https://github.com/esnet/iperf/releases/download/{{version.raw}}/iperf-{{version.raw}}.tar.gz"
  strip-components = 1

  # 851587 bytes. Recorded with `zpkb sourcepin`; the project's own
  # iperf-3.22.1.tar.gz.sha256 asset, next to the tarball, names the same
  # value, and so did a curl + shasum. The release has no signature.
  sha256 = {
    "3.22.1" = "de018b5252e2a7068c89fac8b35a295d83334f2b7814aa9532a2a8107b04a4a9"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ 1. AUTHENTICATION. configure.ac:171-193 — named, a missing OpenSSL
      # is fatal instead of a silent iperf3 without --username.
      "--with-openssl={{deps.openssl.org.prefix}}",

      # ⛔⛔ 2. SCTP. configure.ac:124-161 — refused: no SCTP library is in
      # this tree, so whether `--sctp` exists would be the builder's choice.
      "--without-sctp",

      # src/Makefile.am:106 `install-exec-hook` runs ldconfig on Linux, which
      # writes outside the prefix; configure.ac:60-68 lets it be skipped.
      "--without-ldconfig",

      # configure.ac:72-74: gprof build `iperf3_profile`, off by default and
      # not installed; named so a change of default is visible.
      "--disable-profiling",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# src/Makefile.am:2: bin_PROGRAMS = iperf3 (and the t_* test programs are noinst).
provides = [
  "bin/iperf3",
]

test {
  # src/iperf_locale.c:153-161,230-233: the usage text lists --username only
  # when HAVE_SSL is defined, and :165-169 lists --sctp only when HAVE_SCTP_H.
  script = [
    "iperf3 --version",
    {
      run = <<EOT
set -eu
iperf3 --help > help.txt 2>&1 || true
grep -q -e '--username' help.txt
if grep -q -e '--sctp' help.txt; then
  echo "iperf3 was built with SCTP, pinned off" >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",         # :60-68 ldconfig, :72-74 profiling, :124-161 SCTP, :171-193 OpenSSL
    "src/Makefile.am",      # :1-8 targets, :104-106 man pages and install-exec-hook
    "src/iperf_locale.c",   # :153-169,230-233 the usage text the test reads
    "LICENSE",              # every section cited in the licence comment
  ]

  consulted = [
    # Read for facts only: that the upstream recipe passed --with-openssl.
    "pkgxdev/pantry projects/github.com/esnet/iperf/package.yml",
  ]

  note = <<EOT
⚠ THE RUNG IS A SINGLE HOST, STATED. The tarball and its .sha256 are both
GitHub release assets of the same release; no detached signature exists. The
digest agreed across the builder's fetcher, curl + shasum, and the project's
own .sha256 asset.

⛔ NOT BUILT. No session here can run the factory; the configure flags were
read from configure.ac, not run.
EOT
}
