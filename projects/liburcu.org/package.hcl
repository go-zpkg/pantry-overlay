# liburcu — Userspace RCU, the read-copy-update library from EfficiOS.
#
# ⛔ WRITTEN FROM LIBURCU'S OWN FILES at 0.15.7 (go-zpkg/packages#440 step 1).
# isc.org/bind9 names `liburcu.org` as a dependency and no recipe existed.

summary = "Userspace RCU (read-copy-update) library"

# LICENSE.md:10 "The library part is distributed under LGPL-2.1-or-later";
# some headers carry MIT text (LICENSE.md:28 onward), and the library is the
# part this recipe installs.
license = "LGPL-2.1-or-later"

versions {
  # The author's download directory: one `.tar.bz2`, `.asc`, `.md5` and
  # `.sha256` per release.
  url   = "https://lttng.org/files/urcu/"
  match = "/userspace-rcu-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2\"/"
  strip = [
    "/^userspace-rcu-/",
    "/\\.tar\\.bz2\"$/",
  ]
}

distributable {
  url              = "https://lttng.org/files/urcu/userspace-rcu-{{version.raw}}.tar.bz2"
  strip-components = 1

  # 0.15.7: signed 2026-09-11. Two witnesses besides the fetch that recorded it:
  #
  #   - userspace-rcu-0.15.7.tar.bz2.sha256 beside the tarball on the same
  #     download page says 2556b83a…edd3, the digest below;
  #   - Homebrew's formula `userspace-rcu` (formulae.brew.sh API, stable
  #     0.15.7, same lttng.org URL) records the same checksum, so a party
  #     that is not the author's server agrees.
  #
  # ⛔ NOT VERIFIED BY SIGNATURE, and the reason is stated rather than hidden:
  # the .asc is made by 2A0B 4ED9 15F2 D3FA 45F5 B162 1728 0A97 8118 6ACF (read
  # from the signature packet), and no copy of that public key could be reached
  # without a keyserver — github.com/mjeanson.gpg serves a different, expired
  # key, and neither lttng.org's download pages nor the liburcu README print a
  # fingerprint. An unverifiable signature is not claimed.
  sha256 = {
    "0.15.7" = "2556b83adc0f9b3ac8024e613e17d014d04c4c49110604ce55fcb14eae32edd3"
  }
}

build {
  script = [
    "./configure --prefix={{prefix}}",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: Makefile.am installs libraries, headers and pkg-config
# files; the tarball has no installed program (src/ builds only libraries).

test {
  script = [
    "test -f {{prefix}}/include/urcu.h",
    "test -f {{prefix}}/include/urcu/urcu-memb.h",
    "pkg-config --exists liburcu",
    "test \"$(pkg-config --modversion liburcu)\" = {{version.raw}}",
    "ls {{prefix}}/lib/liburcu.* > /dev/null",
  ]
}

provenance {
  read = [
    "configure.ac",  # :28 AC_INIT userspace-rcu, URL http://liburcu.org/
    "configure",     # :1499-1512 the only options: --disable-compiler-tls, --disable-smp-support, --enable-rcu-debug, --disable-legacy-mb
    "LICENSE.md",    # :10 library LGPL-2.1-or-later
    "src/liburcu.pc.in", # :10 Name: Userspace RCU — the pkg-config module is liburcu (the file name)
    "README.md",     # :151-156 _LGPL_SOURCE
  ]

  consulted = [
    "https://lttng.org/files/urcu/",
    "https://formulae.brew.sh/api/formula/userspace-rcu.json",
  ]

  note = <<EOT
Written, not converted: no recipe existed.

THE SIGNATURE WAS NOT CHECKED. The archive's .asc names key
2A0B4ED915F2D3FA45F5B16217280A9781186ACF (signed 2026-09-11) and no copy of the
key was reachable without a keyserver. The pin therefore rests on the author's
published .sha256 and on Homebrew's independent record of the same digest,
which is weaker than a verified signature and is said so here.

⛔ THE TEST BLOCK WAS NOT RUN ON A BUILT liburcu IN THIS SESSION. Stated rather
than implied.
EOT
}
