# github.com/10gic/vanitygen-plusplus — vanitygen++, a vanity address generator
# for Bitcoin and many other chains, and keyconv (key format converter).
# Written whole from the project's own files at v0.3.0 (go-zpkg/packages#440
# step 1); the previous file was a fragment with dependencies only.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. IT NEEDS PCRE 8, NOT PCRE2. pattern.c includes <pcre.h> and the Makefile
#      links `-lpcre`. That is why projects/pcre.org (8.45, end of life) was
#      written for this recipe: the PCRE2 recipe installs pcre2.h, and the
#      pcre_* API is not the pcre2_* API.
#   2. THERE IS NO INSTALL TARGET. The Makefile has `most`, `all`, `test`,
#      `clean` (Makefile:45-76) and nothing else, so the build script copies the
#      two programs `make most` produces. README.md:111 states `make` builds
#      "vanitygen++ keyconv".
#   3. THE OPENCL PROGRAMS ARE NOT BUILT. `all` adds oclvanitygen++ and
#      oclvanityminer (Makefile:26, README.md:112), which need an OpenCL
#      runtime and, for the miner, libcurl; `most` needs neither, so libcurl is
#      NOT a dependency here (the old fragment listed it).
#   4. THE DARWIN BLOCK HARD-CODES HOMEBREW PATHS (Makefile:29-36,
#      /opt/homebrew/opt/openssl, pcre, check). A variable given on the make
#      command line overrides those `+=` lines, so the script passes CFLAGS and
#      LIBS whole, naming this tree's openssl and pcre prefixes.
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "vanitygen++: vanity address generator for Bitcoin and other chains, with keyconv"

# LICENSE is the GNU Affero General Public License text; vanitygen.c:5-8 and
# pattern.c:5-8 say "version 3 of the License, or (at your option) any later
# version"; README.md:189-190 says "GNU Affero General Public License".
license = "AGPL-3.0-or-later"

versions {
  github = "10gic/vanitygen-plusplus/tags"
}

distributable {
  # The project's release assets are Windows zips only (v0.3.0: vanitygen-
  # plusplus-windows-x64-v0.3.0.zip), so the source is the GitHub-generated tag
  # archive. Its bytes are not guaranteed stable (see lz4.org); the digest
  # records today's.
  url              = "https://github.com/10gic/vanitygen-plusplus/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 6169935 bytes. Recorded with `zpkb sourcepin` (v0.97.0), confirmed by a
  # second independent fetch (curl, shasum -a 256): the same digest. The project
  # publishes no checksum file and no signature.
  sha256 = {
    "0.3.0" = "9aca3804d7d14c57291b56614258ffabdae61b8291d00780c4f9045da7c94c50"
  }
}

provides = [
  "bin/vanitygen++",
  "bin/keyconv",
]

dependencies = {
  # <openssl/*.h> in vanitygen.c, pattern.c, util.c, keyconv.c, simplevanitygen.c
  # incl. <openssl/core_names.h>, which is OpenSSL 3; README.md:14 says
  # `brew install openssl@3`. Linked as `-lcrypto` (Makefile:18).
  "openssl.org" = "^3"

  # pattern.c includes <pcre.h>; `-lpcre` (Makefile:18). PCRE 8.x.
  "pcre.org" = "^8"
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }
  }

  script = [
    # `make most`: vanitygen++ and keyconv (Makefile:45). LIBS and CFLAGS are the
    # Makefile's own (:18-19) plus the include and library paths of the two
    # dependencies; given whole on the command line so the Darwin homebrew block
    # (:29-36) cannot apply.
    {
      run = <<EOT
set -eu
OS="{{deps.openssl.org.prefix}}"
PC="{{deps.pcre.org.prefix}}"
make most \
  CFLAGS="-O3 -Wall -Wno-deprecated -I$OS/include -I$PC/include" \
  LIBS="-L$OS/lib -L$PC/lib -lpcre -lcrypto -lm -lpthread"
mkdir -p "{{prefix}}/bin"
cp vanitygen++ keyconv "{{prefix}}/bin/"
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
test -x "{{prefix}}/bin/vanitygen++"
test -x "{{prefix}}/bin/keyconv"
# README.md:155-159: `keyconv -G` prints a fresh key pair, one line each.
"{{prefix}}/bin/keyconv" -G > keys.txt
grep -q '^Address: 1' keys.txt
grep -q '^Privkey: 5' keys.txt
# README.md:165-168: a prefix search prints `Address:` beginning with it. The
# two-character prefix `1A` is found in a few dozen tries, and the run goes
# through the pcre matching code (pattern.c).
"{{prefix}}/bin/vanitygen++" 1A > vanity.txt
grep -q '^Address: 1A' vanity.txt
EOT
    },
  ]
}

provenance {
  read = [
    "Makefile",     # :18-19 LIBS and CFLAGS; :26 PROGS; :29-36 Darwin homebrew paths; :45 `most`; :49-56 link lines (oclvanityminer alone uses -lcurl); no install target
    "README.md",    # :14-15 brew openssl@3, pcre; :111-112 make vs make all; :150-177 keyconv -G and the output shape; :189-190 licence
    "LICENSE",      # GNU Affero General Public License
    "vanitygen.c",  # :5-8 AGPL v3 or later
    "pattern.c",    # :5-8 same; includes <pcre.h> and <openssl/*.h>
    "util.c",       # openssl includes
    "keyconv.c",    # openssl includes
    "simplevanitygen.c",  # openssl includes incl. core_names.h
  ]

  consulted = []

  note = <<EOT
⚠ THE SOURCE RUNG: the GitHub-generated tag archive (the project's only release
assets are Windows zips), fetched twice with one answer; no checksum file or
signature is published.

⚠ SELECTED BY READING, NOT TRIED: that the `{{deps.<name>.prefix}}` form
resolves for these two dependencies as it does in crates.io/zellij's runtime
block; that `1A` is found quickly and that vanitygen++ with no `-k` stops at
the first match (README's example shows one result); that no rpath is needed,
the factory's fix-up stage owning the install names of dylibs and the loader
search of ELF binaries.

⛔ NOT BUILT by the factory, and not by hand. Lint only. The first factory run is
this file's test.
EOT
}
