# libsodium.org — libsodium, a portable NaCl-based crypto library.
#
# ⛔ WRITTEN FROM LIBSODIUM'S OWN FILES (go-zpkg/packages#440), at 1.0.22. fizz
# requires it (`find_package(Sodium REQUIRED)`, fizz/CMakeLists.txt:79) and
# folly finds it optionally (folly-deps.cmake:536).

summary = "libsodium: a portable, easy-to-use crypto library (NaCl fork)"

# LICENSE:1-3 opens "ISC License".
license = "ISC"

versions {
  github = "jedisct1/libsodium"
  strip  = ["/-RELEASE$/"]
}

distributable {
  # The project's own download host: the GitHub tag is spelled 1.0.22 for this
  # version but <version>-RELEASE for 1.0.21 and earlier, so a release-asset URL
  # would not hold across versions. .sig (GPG) and .minisig sit beside it and
  # are not used here (see below).
  url              = "https://download.libsodium.org/libsodium/releases/libsodium-{{version.raw}}.tar.gz"
  strip-components = 1

  # 2008529 bytes, `zpkb sourcepin`. Second witness: the GitHub release asset,
  # fetched independently and hashed with shasum, gave the same digest. The signature was not checked: no key was obtained from a
  # source this session could vouch for, and a keyserver is not an option.
  sha256 = {
    "1.0.22" = "adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  # Autotools, shipped with a generated ./configure in the release tarball.
  # configure.ac:63-283 lists every switch; each default was read.
  script = [
    {
      run = <<EOT
./configure --prefix={{prefix}} \
  --enable-shared --enable-static \
  --enable-ssp \
  --enable-asm \
  --disable-minimal \
  --disable-debug \
  --disable-opt \
  --disable-retpoline \
  --disable-blocking-random \
  --with-pthreads
EOT
    },
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/sodium.h",
    "pkg-config --exists libsodium",
    {
      fixture = {
        content  = <<EOT
#include <sodium.h>
#include <stdio.h>
#include <string.h>

int main(void) {
  if (sodium_init() < 0) return 1;
  unsigned char h[crypto_generichash_BYTES];
  crypto_generichash(h, sizeof h, (const unsigned char *)"abc", 3, NULL, 0);
  unsigned char key[crypto_secretbox_KEYBYTES], nonce[crypto_secretbox_NONCEBYTES];
  randombytes_buf(key, sizeof key);
  randombytes_buf(nonce, sizeof nonce);
  unsigned char c[crypto_secretbox_MACBYTES + 5], m[5];
  crypto_secretbox_easy(c, (const unsigned char *)"hello", 5, nonce, key);
  if (crypto_secretbox_open_easy(m, c, sizeof c, nonce, key) != 0) return 1;
  printf("libsodium %s ok\n", sodium_version_string());
  return memcmp(m, "hello", 5) != 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o sodiumcheck $(pkg-config --cflags --libs libsodium)"
    },
    "./sodiumcheck",
  ]
}

provenance {
  read = [
    "configure.ac", # :63-194 the switches: ssp, asm, pie, blocking-random, minimal, pthreads, retpoline
    "LICENSE",      # :1-3 ISC
  ]

  consulted = [
    "homebrew-core Formula/lib/libsodium.rb",
  ]

  note = <<EOT
NOT BUILT. Written from configure.ac; the test block has not been run.

Switches named above that this recipe did not read the definition of:
--disable-debug and --disable-opt (configure.ac:200 and :219 exist, their
bodies were not read). --enable-pie defaults to "maybe" (:113) and is left
alone. Tags up to 1.0.21 are spelled <version>-RELEASE, which `strip` removes.
EOT
}
