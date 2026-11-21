# libnl — the netlink library suite (libnl-3, libnl-genl-3, libnl-route-3, ...).
#
# ⛔ WRITTEN FROM LIBNL'S OWN FILES at 3.12.0 (go-zpkg/packages#440 step 1).
# openvpn.net names `github.com/thom311/libnl` on Linux (it is what OpenVPN's
# data-channel-offload path talks netlink through) and no recipe existed.

summary = "Netlink library suite: libnl-3, libnl-genl-3, libnl-route-3 and friends"

# configure.ac:1 SPDX-License-Identifier: LGPL-2.1-only; COPYING is the LGPL 2.1
# text.
license = "LGPL-2.1-only"

# Netlink is a Linux kernel interface.
platforms = ["linux"]

versions {
  github = "thom311/libnl/releases"
  # The release NAME is "libnl 3.12.0" (tag libnl3_12_0), prerelease flag
  # false for every stable one.
  strip  = ["/^libnl\\s+/"]
}

distributable {
  # The release TAG is `libnl3_12_0` and the asset `libnl-3.12.0.tar.gz`, so the
  # URL cannot be built from `version.raw` alone (same shape as expat's tags).
  url              = "https://github.com/thom311/libnl/releases/download/libnl{{version.major}}_{{version.minor}}_{{version.patch}}/libnl-{{version.raw}}.tar.gz"
  strip-components = 1

  # 3.12.0: 1191546 bytes, a STORED release asset. Two witnesses besides the
  # fetch that recorded it:
  #
  #   - libnl-3.12.0.tar.gz.sha256sum, a release asset of the same release, says
  #     fc51ca7196f1a3f5fdf6ffd3864b50f4f9c02333be28be4eeca057e103c0dd18,
  #     which is the digest below (GitHub's own asset digest agrees);
  #   - libnl-3.12.0.tar.gz.sig verifies with gpg: "Good signature from Thomas
  #     Haller <thom311@gmail.com>", RSA key 67DA 3FAE BAE2 76BA 58FC 6CE3 14F1
  #     8A98 993A ECD5, signature made 2025-12-04.
  #
  # ⚠ THE KEY IS NOW EXPIRED (it expired 2026-06-11, six months AFTER the
  # signature was made), so `zpkb sourcepin` refuses it and gpg prints a note.
  # The signature was valid when it was made; the key was fetched from
  # https://github.com/thom311.gpg, a different place from the release, but no
  # page of the project prints its fingerprint, so the key's identity rests on
  # that GitHub account. Said rather than hidden.
  sha256 = {
    "3.12.0" = "fc51ca7196f1a3f5fdf6ffd3864b50f4f9c02333be28be4eeca057e103c0dd18"
  }
}

dependencies = {}

build {
  # ⛔ flex AND bison ARE REQUIRED, read from Makefile.am rather than assumed:
  # lib/route/pktloc_grammar.c, pktloc_syntax.c and the two ematch_* files are
  # BUILT_SOURCES (:374-396, :401-402) generated with $(FLEX) and $(YACC), and
  # the tarball does not ship them (lib/route has only the .l and .y).
  dependencies = {
    "github.com/westes/flex" = "*"
    "gnu.org/bison"          = "^3"
    "gnu.org/make"           = "*"
  }

  # `--disable-cli` is the one choice made here: the nl-* command-line tools
  # (configure.ac:98-108, default `yes`, installed to bin) are not what a
  # library consumer wants, and leaving them on would put about 90 programs in
  # `provides`. `--disable-debug` is NOT passed: it is on by default
  # (:124-132) and turning it off changes the library's behaviour.
  script = [
    "./configure --prefix={{prefix}} --disable-cli",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: with --disable-cli Makefile.am installs libraries, headers
# and seven pkg-config files (:27 pkgconfig_DATA), and no program.

test {
  script = [
    "test -f {{prefix}}/include/libnl3/netlink/netlink.h",
    "pkg-config --exists libnl-3.0 libnl-genl-3.0 libnl-route-3.0",
    "test \"$(pkg-config --modversion libnl-3.0)\" = {{version.raw}}",
    "ls {{prefix}}/lib/libnl-3.* > /dev/null",
    "ls {{prefix}}/lib/libnl-genl-3.* > /dev/null",
  ]
}

provenance {
  read = [
    "configure.ac",  # :1 LGPL-2.1-only; :8-10 3.12.0; :98-108 --enable-cli; :112 --disable-pthreads; :124 --disable-debug; :142-150 pkg-config files
    "Makefile.am",   # :27 pkgconfig_DATA; :374-396 flex/bison BUILT_SOURCES; :829-832 cli programs
    "COPYING",       # :1-2 GNU LGPL 2.1
    "libnl-3.0.pc.in",  # the base pkg-config module is libnl-3.0
  ]

  consulted = [
    "https://github.com/thom311/libnl/releases",
    "https://github.com/thom311.gpg",
  ]

  note = <<EOT
Written, not converted: no recipe existed.

  signature   libnl-3.12.0.tar.gz.sig, over the archive
  identity    Thomas Haller <thom311@gmail.com>
  fingerprint 67DA3FAEBAE276BA58FC6CE314F18A98993AECD5
  signed at   2025-12-04; the key EXPIRED 2026-06-11

The key came from https://github.com/thom311.gpg, not from the release; the
project prints no fingerprint, so this proves the archive was signed by the key
that account holds, not who holds it. Stated rather than implied.

⛔ THE BUILD AND THE TEST BLOCK WERE NOT RUN IN THIS SESSION. Stated rather than
implied. The installed header directory (include/libnl3/netlink) is the
libnl default, read from the 3.x pkg-config files, not exercised.
EOT
}
