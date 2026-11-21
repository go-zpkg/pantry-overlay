# github.com/Cyan4973/xxHash — xxHash, an extremely fast non-cryptographic hash.
#
# ⛔ WRITTEN FROM XXHASH'S OWN FILES (go-zpkg/packages#440), at 0.8.4. fb303 and
# fbthrift require it; borgbackup.org already names it as a dependency and this
# tree had no recipe.

summary = "xxHash: an extremely fast non-cryptographic hash algorithm"

# LICENSE:1-3 is headed "xxHash Library", "Copyright (c) 2012-2021 Yann Collet".
# Only the LIBRARY is built (XXHASH_BUILD_XXHSUM=OFF below): the xxhsum command
# line tool is under a different licence in the same repository, and it is not
# installed here.
license = "BSD-2-Clause"

versions {
  github = "Cyan4973/xxHash"
}

distributable {
  # The only release asset is xxhsum_win64_v0_8_4.zip (a Windows binary), so the
  # generated tag archive is the source.
  url              = "https://github.com/Cyan4973/xxHash/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1167538 bytes, `zpkb sourcepin`; an independent fetch with curl hashed with
  # shasum gave the same digest. Both come from GitHub's archive generator, so
  # this checks the transfer and not the generator.
  sha256 = {
    "0.8.4" = "5738270935e7c3d38a79b3adf7c9692566ce7895a25f67de43ad52ab504acd32"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      # build/cmake/CMakeLists.txt:59 defaults to ON (shared); the Facebook stack
      # links it static. PIC so it can still go into a shared object.
      "-DBUILD_SHARED_LIBS=OFF",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
      # :60 defaults to ON: the CLI tool, not wanted (see the licence note).
      "-DXXHASH_BUILD_XXHSUM=OFF",
    ]
  }

  # The CMake project is in build/cmake, not at the top (README.md of that
  # directory, and the CMakeLists.txt there at :8).
  script = [
    "cmake -S build/cmake -B build-out $ARGS",
    "cmake --build build-out --parallel {{ hw.concurrency }}",
    "cmake --install build-out",
  ]
}

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/xxhash.h",
    {
      fixture = {
        content  = <<EOT
#include <xxhash.h>
#include <string.h>

int main(void) {
  const char *s = "abc";
  XXH64_hash_t a = XXH64(s, strlen(s), 0);
  XXH64_hash_t b = XXH64(s, strlen(s), 0);
  return (a == b && a != 0) ? 0 : 1;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o xxcheck -I{{prefix}}/include -L{{prefix}}/lib -lxxhash"
    },
    "./xxcheck",
  ]
}

provenance {
  read = [
    "build/cmake/CMakeLists.txt", # :8 cmake 3.10; :59-60 BUILD_SHARED_LIBS and XXHASH_BUILD_XXHSUM
    "LICENSE",                    # :1-3 "xxHash Library", Copyright (c) 2012-2021 Yann Collet
  ]

  consulted = [
    "homebrew-core Formula/x/xxhash.rb",
  ]

  note = <<EOT
NOT BUILT. Written from build/cmake/CMakeLists.txt; the test block has not been run.

The licence field was taken from the header of LICENSE, whose clause text was
not read through. The recipe installs the library only, never xxhsum.
EOT
}
