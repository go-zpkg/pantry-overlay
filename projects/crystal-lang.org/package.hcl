# crystal-lang.org — the Crystal compiler (self-hosted, LLVM back end).
#
# ⛔ WRITTEN FROM CRYSTAL'S OWN Makefile, bin/ci AND src/ (go-zpkg/packages#431,
# packages#440 step 1), at 1.22.3, replacing a recipe that was a bare
# dependency list from the pantry: it named no versions, no source and no
# build.
#
# ⭐ THE COMPILER IS BUILT BY AN EARLIER COMPILER. Makefile line 28 says it
# plainly: `CRYSTAL ?= crystal ## which previous crystal compiler use`, and
# bin/crystal (lines 142-199) execs that `$CRYSTAL` to build the new one. The
# version the project itself builds with is `CRYSTAL_BOOTSTRAP_VERSION:=1.21.0`
# (bin/ci line 3), and its release assets are named in bin/ci line 140 for
# darwin (crystal-1.21.0-1-darwin-universal.tar.gz). That previous compiler is
# pinned below in `sources`, one entry per host with its own digest
# (`platforms`, go-zpkg/zpkb#521, shipped in zpkb v0.95.0), and fetched by the
# builder, never by a curl in the build script.

summary = "Crystal: a compiled language with Ruby-inspired syntax, built on LLVM"

# LICENSE at the root of the tarball: Apache License, Version 2.0.
license = "Apache-2.0"

# Release tags are bare versions (1.22.3). Nightlies and pre-releases are not
# tagged this way.
versions {
  github = "crystal-lang/crystal"
}

# What the installed compiler links its programs against. The libraries are
# the `@[Link(...)]` ones of src/: gmp (BigInt), gc (src/gc/boehm.cr), event
# (src/crystal/event_loop/libevent), yaml (src/yaml/lib_yaml.cr), ssl and
# crypto (src/openssl), z (src/compress/zlib), xml2 (src/xml), pcre2-8
# (src/regex/lib_pcre2.cr), iconv (libc, or libiconv on macOS) and ffi
# (src/compiler/crystal/interpreter). A program that uses none of them does
# not link them, so the dependency is the one a program that does needs next
# to the compiler.
#
# Not a dependency: ncurses, which the old recipe named and nothing in this
# tarball but a vendored JavaScript file mentions.
dependencies = {
  "freedesktop.org/pkg-config" = "^0"
  "gnome.org/libxml2"          = "^2"
  "gnu.org/gmp"                = "^6"
  "hboehm.info/gc"             = "^8"
  "libevent.org"               = "^2"
  "llvm.org"                   = ">=8<25"
  "openssl.org"                = "^3"
  "pcre.org/v2"                = "^10"
  "pyyaml.org/libyaml"         = "^0"
  "sourceware.org/libffi"      = "^3"
  "zlib.net"                   = "^1"
}

distributable {
  url              = "https://github.com/crystal-lang/crystal/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 4373036 bytes. The project publishes no source tarball among its release
  # assets (checked: crystal-1.22.3-source.tar.gz and crystal-1.22.3.tar.gz
  # are 404), so the GitHub-generated archive of the tag is the source.
  # Second witness: an independent fetch with curl and shasum -a 256 gave the
  # same digest as `zpkb sourcepin --version 1.22.3`.
  sha256 = {
    "1.22.3" = "90f2613cc004d5734fe0a0364c3fcac3918e3a50e357ae33bdcb506ac44fcbb1"
  }
}

# The previous compiler, 1.21.0 (bin/ci line 3), unpacked into .bootstrap.
# Every digest below is from `zpkb sourcepin --version 1.21.0` on the release
# asset, and agrees with an independent fetch measured with curl and
# shasum -a 256. The project publishes no signature or checksum file for them.
# One tarball per host; the darwin one is a universal binary for both arches.
# There is no asset for another host, so a build there is refused by the
# builder with a message naming the target.
sources = [
  {
    url                = "https://github.com/crystal-lang/crystal/releases/download/1.21.0/crystal-1.21.0-1-linux-x86_64.tar.gz"
    sha256             = "744561ee3cee1b06d106cf9ae99b8064b4e017518ac414d6dd23cfafe36560c9"
    dest               = ".bootstrap"
    "strip-components" = 1
    platforms          = ["linux/x86-64"]
  },
  {
    url                = "https://github.com/crystal-lang/crystal/releases/download/1.21.0/crystal-1.21.0-1-linux-aarch64.tar.gz"
    sha256             = "4f30da9ff083dc485652e3d9b04d7e82cc4c49fb6e8ab3bac76cbde24d960778"
    dest               = ".bootstrap"
    "strip-components" = 1
    platforms          = ["linux/aarch64"]
  },
  {
    url                = "https://github.com/crystal-lang/crystal/releases/download/1.21.0/crystal-1.21.0-1-darwin-universal.tar.gz"
    sha256             = "7fc4af56b0cb5c7ea5703f744c6629bb19ff36ba3abbf232d50e40c39a20ee16"
    dest               = ".bootstrap"
    "strip-components" = 1
    platforms          = ["darwin"]
  },
]

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "release=1",

      # ON: the interpreter (`crystal i`), which links libffi. The Makefile
      # adds -Dwithout_interpreter unless interpreter is set (line 51).
      "interpreter=1",

      # OFF, left unset: static (--static), debug (-d), stats, progress,
      # threads, sequential_codegen, docs_sanitizer (libxml2 in the compiler
      # itself; the Makefile builds the compiler with -Dwithout_libxml2,
      # -Dwithout_openssl and -Dwithout_zlib, line 51, and the libraries
      # above are for the programs it compiles).
      "PREFIX={{prefix}}",
    ]
  }

  script = [
    # `make build` is the packaging target (Makefile line 198): the compiler,
    # in release mode, and the man pages. The previous compiler is $CRYSTAL.
    "make build $ARGS CRYSTAL=\"$PWD/.bootstrap/bin/crystal\"",
    "make install $ARGS CRYSTAL=\"$PWD/.bootstrap/bin/crystal\"",
  ]
}

provides = [
  "bin/crystal",
]

test {
  script = [
    "crystal --version | grep -q \"Crystal {{version.raw}}\"",
    "crystal eval 'puts 1 + 1' | grep -q '^2$'",
    "crystal eval 'require \"big\"; puts (2.to_big_i ** 100).to_s' | grep -q 1267650600228229401496703205376",
    "crystal eval 'puts \"ab12\" =~ /\\d+/'",
    "crystal i -e 'puts 6 * 7'",
  ]
}

provenance {
  read = [
    "Makefile",              # line 28: CRYSTAL ?= previous compiler; 51: COMPILER_FLAGS; 198: build; 220-263: install
    "bin/ci",                # line 3: CRYSTAL_BOOTSTRAP_VERSION:=1.21.0; line 140: the darwin asset name
    "bin/crystal",           # lines 142-199: the wrapper execs $CRYSTAL
    "src/llvm/ext/llvm-versions.txt",
    "src/VERSION",
    "LICENSE",
    "src/",                  # the @[Link(...)] libraries
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the Makefile contract was
read, and `zpkb lint` was run.

⚠ UNKNOWNS: (1) the linux/x86-64 and linux/aarch64 bootstrap tarballs are the
non-bundled ones, so the previous compiler dynamically links the libraries
above; whether they resolve at its run time was not exercised. (2) llvm.org is
named ">=8<25" from src/llvm/ext/llvm-versions.txt (8.0 to 24.0); the old
recipe said "<17" and its reason was not found in the source. (3) the
Makefile calls `git rev-parse` and falls back to an empty commit when the tree
is a tarball. (4) the darwin entry covers both arches with one universal
tarball. (5) this recipe needs zpkb >= v0.95.0 to load (`platforms` in
`sources`).

⚠ pkgxdev/pantry was read only as the former content of this very file.
EOT
}
