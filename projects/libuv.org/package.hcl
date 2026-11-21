# libuv — the cross-platform asynchronous I/O library behind Node.js.
#
# ⛔ WRITTEN FROM LIBUV'S OWN FILES at 1.53.0 (go-zpkg/packages#440 step 1).
# isc.org/bind9 named `libuv.org` as a dependency and no recipe existed.

summary = "Cross-platform asynchronous I/O library"

# LICENSE is the MIT text: "Copyright (c) 2015-present libuv project
# contributors." followed by "Permission is hereby granted, free of charge".
# LICENSE-extra lists the vendored parts under their own licences.
license = "MIT"

versions {
  # Tags are `v1.53.0`. The project's download area lists the same versions as
  # directories, but GitHub's tag list is shorter to read and carries them all.
  github = "libuv/libuv"
  strip  = ["/^v/"]
}

distributable {
  # The `-dist` archive, not the plain one beside it: it is the `make dist`
  # output and SHIPS `configure` (x/configure present), where the plain archive
  # is a source export that would need autoconf, automake and libtool.
  url              = "https://dist.libuv.org/dist/v{{version.raw}}/libuv-v{{version.raw}}-dist.tar.gz"
  strip-components = 1

  # 1.53.0: 3802599 bytes, signed 2026-09-24. Two witnesses:
  #
  #   - libuv-v1.53.0-dist.tar.gz.sign beside the archive is made by 612F 0EAD
  #     9401 6223 79DF 4402 F28C 3C8D A33C 03BE (Santiago Gimeno), checked with
  #     `zpkb sourcepin --sig <url> --key`;
  #   - that fingerprint is PUBLISHED, by the project, in MAINTAINERS.md ("GPG
  #     key: 612F 0EAD 9401 6223 79DF  4402 F28C 3C8D A33C 03BE
  #     (pubkey-santigimeno)"), a file in the repository and not the key.
  #
  # The key itself is https://github.com/santigimeno.gpg. The key blob stored in
  # the repository under the tag pubkey-santigimeno is EXPIRED, which sourcepin
  # refuses; GitHub's account endpoint serves the current one. No keyserver.
  sha256 = {
    "1.53.0" = "21425fa398be98b51181a1885df31428092d5435c4373a396351e427322e5f1b"
  }
}

build {
  script = [
    "./configure --prefix={{prefix}}",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: configure.ac:87 generates only Makefile and libuv.pc; the
# install is a library, its headers and the pkg-config file, and no program.

test {
  script = [
    "test -f {{prefix}}/include/uv.h",
    "test -f {{prefix}}/lib/pkgconfig/libuv.pc",
    "pkg-config --exists libuv",
    "test \"$(pkg-config --modversion libuv)\" = {{version.raw}}",
    "ls {{prefix}}/lib/libuv.* > /dev/null",
  ]
}

provenance {
  read = [
    "configure.ac",  # :16 AC_INIT libuv 1.53.0; :21 AM_INIT_AUTOMAKE; :47 LT_INIT; :87 AC_CONFIG_FILES Makefile libuv.pc
    "libuv.pc.in",   # the pkg-config module is `libuv`
    "LICENSE",       # MIT, "Copyright (c) 2015-present libuv project contributors."
    "MAINTAINERS.md", # published fingerprints (repository file, not in the dist archive)
  ]

  consulted = [
    "https://dist.libuv.org/dist/v1.53.0/",
    "https://github.com/libuv/libuv/blob/v1.x/MAINTAINERS.md",
    "https://github.com/santigimeno.gpg",
  ]

  note = <<EOT
Written, not converted: no recipe existed.

  signature   https://dist.libuv.org/dist/v1.53.0/libuv-v1.53.0-dist.tar.gz.sign
  key         https://github.com/santigimeno.gpg
  identity    Santiago Gimeno (sgimeno) <santiago.gimeno@gmail.com>
  signed at   2026-09-24T14:38:00Z
  fingerprint 612F0EAD9401622379DF4402F28C3C8DA33C03BE (MAINTAINERS.md)

The repository's own copy of the key (tag pubkey-santigimeno) is expired, so
the current key came from the account endpoint; the fingerprint that vouches
for it comes from the project's file, not from the endpoint. No keyserver.

⛔ THE TEST BLOCK WAS NOT RUN ON A BUILT libuv IN THIS SESSION. Stated rather
than implied.
EOT
}
