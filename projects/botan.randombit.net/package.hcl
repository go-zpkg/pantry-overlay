# botan — Botan, a C++ cryptography library and its `botan` command line tool.
#
# ⛔ WRITTEN FROM BOTAN'S OWN FILES at 3.14.1, not converted. Neither
# pkgxdev/pantry nor this overlay had a recipe. It exists because go-encryptions/
# serpent#2 asks for an amd64 reference measurement, and `botan speed` is the
# reference tool for Serpent (see the note in `provenance`).

summary = "Botan: C++ cryptography library and the botan command line tool"

# license.txt at the root of the tarball is the Simplified (2-clause) BSD text.
license = "BSD-2-Clause"

versions {
  url   = "https://botan.randombit.net/releases/"
  match = "/Botan-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = [
    "/^Botan-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://botan.randombit.net/releases/Botan-{{version.raw}}.tar.xz"
  strip-components = 1

  # Recorded with `zbk sourcepin --sig auto --key <ks.asc> --fingerprint
  # "621D AF64 11E1 851C 4CF9 A2E1 6211 EBF1 EFBA DFBC"`: 10 306 972 bytes,
  # signed by the "Botan Distribution Key" (the signature packet names
  # issuer fpr 621DAF6411E1851C4CF9A2E16211EBF1EFBADFBC, created 2026-11-06).
  #
  # The key material was fetched BY FINGERPRINT from keyserver.ubuntu.com, a
  # host that is not botan.randombit.net, and its fingerprint equals the one
  # the tarball itself prints (doc/pgpkey.txt:4). The tarball and that file
  # come from the same host, so that second agreement is continuity, not
  # independence; the keyserver fetch is the independent leg.
  sha256 = {
    "3.14.1" = "5b85cba0f014d344eb8e9919aee0a3bdc31e16acb05816410025be9bee1e0930"
  }
}

build {
  dependencies = {
    "python.org" = "^3"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",
      # ⛔ `cli` IS WHAT MAKES `botan speed` EXIST. configure.py:3310-3337 turns
      # --build-targets into the targets built, and only `'cli' in
      # options.build_targets` (configure.py:2133, :2148) puts the executable in
      # the build and the install. The library alone has no benchmark.
      "--build-targets=shared,cli",
      "--without-documentation",
      # ⛔ NO `--enable-modules` / `--disable-modules` / `--minimized-build`.
      # The default is every module the compiler can build, and that default is
      # the one whose CPU dispatch we want to MEASURE: serpent_avx512
      # (src/lib/block/serpent/serpent_avx512/info.txt, <isa> avx512) and
      # serpent_simd8x32 (…/serpent_simd8x32/info.txt, <isa> avx2) are separate
      # modules, picked at run time by CPUID (serpent.cpp:28-29, :39, :179-180,
      # :190). A restricted module set would silently measure a different
      # implementation than the one users get. Which one ran is printed by the
      # tool itself: `botan cpuid`, and the "CPUID:" line of `botan speed`
      # (src/cli/speed.cpp:481-483).
    ]
  }

  script = [
    "python3 ./configure.py $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = [
  "bin/botan",
]

test {
  script = [
    # Properties, not a version string.
    #
    # 1. The CLI target was built: `speed` is a registered command, and it names
    #    the CPU features it dispatches on (speed.cpp:481-483).
    "botan speed --msec=10 --buf-size=4096 Serpent > speed.out 2>&1",
    "grep -q 'CPUID:' speed.out",
    "grep -q 'Serpent' speed.out",

    # 2. Serpent round-trips: encrypt, decrypt, compare. CBC with a fixed key and
    #    IV; PKCS7 so any length works.
    "printf 'the quick brown fox jumps over the lazy dog' > plain.txt",
    "botan cipher --cipher=Serpent/CBC/PKCS7 --key=000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f --nonce=000102030405060708090a0b0c0d0e0f plain.txt > ct.bin",
    "! cmp -s plain.txt ct.bin",
    "botan cipher --decrypt --cipher=Serpent/CBC/PKCS7 --key=000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f --nonce=000102030405060708090a0b0c0d0e0f ct.bin > back.txt",
    "cmp plain.txt back.txt",

    # 3. Clearing a CPUID bit selects a different kernel and must not change the
    #    result: the AVX2/AVX-512 paths and the scalar path agree.
    "botan speed --msec=10 --clear-cpuid=avx512f,avx2 --buf-size=4096 Serpent > speed-scalar.out 2>&1",
    "grep -q 'Serpent' speed-scalar.out",
  ]
}

provenance {
  read = [
    "configure.py",                # :364 ACCEPTABLE_BUILD_TARGETS includes "cli"; :590 --build-targets; :2133/:2148 cli in all_targets/install_targets; :3310-3337 canonicalize_build_targets
    "src/cli/speed.cpp",           # :308 usage string (--msec, --buf-size, --clear-cpuid); :470-475 --clear-cpuid; :481-483 prints "CPUID: ..."
    "src/cli/utils.cpp",           # :200-215 `botan cpuid`
    "src/cli/cipher.cpp",          # :26-74 `botan cipher` with --cipher/--key/--nonce/--decrypt
    "src/lib/block/serpent/serpent.cpp", # :28-29, :179-180 AVX512 dispatch; :39, :190 SIMD8X32 dispatch
    "src/lib/block/serpent/serpent_avx512/info.txt",   # <isa> avx512, requires simd_avx512
    "src/lib/block/serpent/serpent_simd8x32/info.txt", # <isa> avx2, requires simd_8x32
    "doc/pgpkey.txt",              # :4 fingerprint of the Botan Distribution Key
  ]

  consulted = [
    "https://botan.randombit.net/ (links the .asc and pgpkey.txt)",
    "go-encryptions/serpent#2",
    "go-zpkg/packages#440",
  ]

  note = <<EOT
Written for go-encryptions/serpent#2 (amd64 reference measurement).

The signature was checked when the digest was recorded:

  signature    https://botan.randombit.net/releases/Botan-3.14.1.tar.xz.asc
  key          fetched by fingerprint from keyserver.ubuntu.com
  identity     Botan Distribution Key
  fingerprint  621DAF6411E1851C4CF9A2E16211EBF1EFBADFBC

Python 3 is a build dependency only (configure.py is a Python script); nothing
installed links it. The C++ compiler comes from the base toolchain.

⛔ NOT YET VERIFIED BY A BUILD. The recipe was written from the source; the first
build is the factory's and is reported on the pull request, not assumed.
EOT
}
