# libcap — the POSIX 1003.1e capabilities library, with getcap, setcap,
# getpcaps and capsh.
#
# ⛔ WRITTEN FROM LIBCAP'S OWN FILES at 2.78 (go-zpkg/packages#440 step 1).
# isc.org/bind9 declares `kernel.org/libcap` on Linux and no recipe existed.
# This is NOT optional for bind9: its configure.ac:1073 is a
# PKG_CHECK_MODULES([LIBCAP], [libcap]) with no "not found" branch, which
# makes a Linux build without libcap an error.

summary = "POSIX capabilities library and the getcap/setcap/capsh tools"

# License is the file named `License`; its first line is
# "SPDX-License-Identifier: BSD-3-Clause OR GPL-2.0-only" and it states the two
# alternatives, "BSD 3-clause" and "GPL v2.0".
license = "BSD-3-Clause OR GPL-2.0-only"

platforms = ["linux"]

versions {
  url   = "https://kernel.org/pub/linux/libs/security/linux-privs/libcap2/"
  match = "/libcap-\\d+\\.\\d+\\.tar\\.xz/"
  strip = [
    "/^libcap-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-{{version.raw}}.tar.xz"
  strip-components = 1

  # 2.78: 15 files in the release directory — .tar.gz, .tar.xz and one
  # .tar.sign made over the DECOMPRESSED tar (kernel.org's convention).
  #
  #   - the signature, made 2026-04-05 by 38A6 4469 8C69 7873 44E9 54CE 29EE 848A
  #     E2CC F3F4 (Andrew G. Morgan <morgan@kernel.org>), was checked with
  #     gpg --verify over `xz -dc libcap-2.78.tar.xz`: "Good signature";
  #   - that fingerprint is the one the project's own Makefile signs with
  #     (Makefile:80 and :87, `-u 38A644698C69787344E954CE29EE848AE2CCF3F4`),
  #     and the key itself ships in the archive as pgp.keys.asc.
  #
  # ⚠ `zpkb sourcepin` could not be used: it answered "signature made by
  # unknown entity" for key 29EE848AE2CCF3F4 although pgp.keys.asc holds it
  # (gpg imports and verifies it), so the digest below is the sha256 of the
  # archive fetched here, vouched for by gpg rather than by sourcepin.
  sha256 = {
    "2.78" = "0d621e562fd932ccf67b9660fb018e468a683d7b827541df27813228c996bb11"
  }
}

build {
  # Make.Rules:20-22 computes `lib` from the dynamic loader's directory when it
  # is not given (lib64 on some builders); :32-35 turn on autoconf-style
  # prefixes only when `prefix` is defined. Both are passed.
  #
  # GOLANG and PAM_CAP are probed from the builder (Make.Rules:123 and :138)
  # and default to "yes" when Go or pam_modules.h is present; both are turned
  # off, since the Go modules and pam_cap.so are not what a library consumer
  # wants and a probe would make the artifact depend on the builder.
  env = {
    ARGS = [
      "prefix={{prefix}}",
      "lib=lib",
      "GOLANG=no",
      "PAM_CAP=no",
    ]
  }

  script = [
    "make --jobs {{ hw.concurrency }} $ARGS",
    "make $ARGS install",
  ]
}

# progs/Makefile:7 PROGS=getpcaps getcap setcap, :11 plus capsh, installed
# into $(SBINDIR) by :43-47, which is prefix/sbin (Make.Rules:24-26, :48).
provides = [
  "sbin/capsh",
  "sbin/getcap",
  "sbin/getpcaps",
  "sbin/setcap",
]

test {
  script = [
    "test -f {{prefix}}/include/sys/capability.h",
    "pkg-config --exists libcap",
    "test \"$(pkg-config --modversion libcap)\" = {{version.raw}}",
    "ls {{prefix}}/lib/libcap.* > /dev/null",
    "capsh --print | grep -F 'Current:'",
  ]
}

provenance {
  read = [
    "Make.Rules",       # :3-4 VERSION=2 MINOR=78; :20-22 lib; :32-43 prefix; :48-51 target directories; :123 PAM_CAP and :138 GOLANG probes
    "progs/Makefile",   # :7 PROGS=getpcaps getcap setcap; :43-47 install into SBINDIR
    "libcap/Makefile",  # :43 all; :168 install; :215 libcap.pc
    "Makefile",         # :80 and :87 the signing key's fingerprint
    "License",          # :1 BSD-3-Clause OR GPL-2.0-only
    "pgp.keys.asc",     # the signing key, shipped in the archive
  ]

  consulted = [
    "https://kernel.org/pub/linux/libs/security/linux-privs/libcap2/",
  ]

  note = <<EOT
Written, not converted: no recipe existed.

  signature   libcap-2.78.tar.sign, over the decompressed tar
  key         pgp.keys.asc inside the archive
  identity    Andrew G. Morgan <morgan@kernel.org>
  signed at   2026-04-05
  fingerprint 38A644698C69787344E954CE29EE848AE2CCF3F4 (Makefile:80, :87)

The fingerprint and the key both come from the archive being verified, so
this proves the archive is self-consistent with the key its author ships, not
that the key is his; no independent publication of the fingerprint was found.
Stated rather than implied.

⛔ THE TEST BLOCK WAS NOT RUN ON A BUILT libcap IN THIS SESSION. Stated rather
than implied.
EOT
}
