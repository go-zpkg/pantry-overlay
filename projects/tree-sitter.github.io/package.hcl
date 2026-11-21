# tree-sitter — the incremental parsing library behind neovim's syntax tree.
# This recipe builds the C LIBRARY ONLY, from the source archive; the CLI is a
# Rust crate and is not built here.
#
# ⛔ WRITTEN FROM TREE-SITTER'S OWN FILES at 0.27.2 (go-zpkg/packages#440
# step 1), as a link of neovim's dependency chain.

summary = "Incremental parsing library (C library only)"

# LICENSE:1-3 is the MIT text, "Copyright (c) 2018 Max Brunsfeld".
license = "MIT"

versions {
  # Tags are `v0.27.2`.
  github = "tree-sitter/tree-sitter"
  strip  = ["/^v/"]
}

distributable {
  # THE GENERATED TAG ARCHIVE: the release's stored assets are the prebuilt CLI
  # (tree-sitter-cli-*.zip, tree-sitter-<os>-<arch>.gz) and web-tree-sitter, not
  # the library source.
  url              = "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 0.27.2: 1030980 bytes, fetched with `zpkb sourcepin`. Second witness: an
  # independent fetch of codeload.github.com/tree-sitter/tree-sitter/tar.gz/refs/tags/v0.27.2
  # with curl, then `shasum -a 256`, gave the same digest. The release
  # publishes no checksum file for the source.
  sha256 = {
    "0.27.2" = "356528363bf7fbad12a2cfeb5a2678c0118ef886a4d69ad9a379db5fdef0735f"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    "gnu.org/gcc"  = "*"
  }

  # Makefile:56 `all` builds libtree-sitter.a, the shared library and the .pc;
  # :86-99 `install` puts api.h, the .pc, the archive and the versioned shared
  # library under PREFIX. The Makefile's CMake twin (CMakeLists.txt:10) leaves
  # the Wasm feature OFF by default; the Makefile has no Wasm switch at all, so
  # no wasmtime is linked and TREE_SITTER_FEATURE_WASM is never defined.
  # AMALGAMATED (Makefile:13) is left unset: the per-file build.
  script = [
    "make --jobs {{ hw.concurrency }} PREFIX={{prefix}}",
    "make install PREFIX={{prefix}}",
  ]
}

# ⚠ NO `provides`: the install is a library, a header and a pkg-config file;
# the `tree-sitter` command is the Rust CLI, which this recipe does not build.

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
  }

  script = [
    "test -f {{prefix}}/include/tree_sitter/api.h",
    "test -f {{prefix}}/lib/pkgconfig/tree-sitter.pc",
    "pkg-config --exists tree-sitter",
    "test \"$(pkg-config --modversion tree-sitter)\" = {{version.raw}}",
    "test -f {{prefix}}/lib/libtree-sitter.a",
  ]
}

provenance {
  read = [
    "Makefile",              # :1 VERSION 0.27.2; :13-21 sources; :56 all; :71-77 tree-sitter.pc; :86-99 install
    "CMakeLists.txt",        # :9-11 options (Wasm and AMALGAMATED OFF); :99-106 install rules
    "lib/tree-sitter.pc.in", # module `tree-sitter`, libs -ltree-sitter
    "LICENSE",               # MIT, "Copyright (c) 2018 Max Brunsfeld"
  ]

  consulted = [
    "https://github.com/tree-sitter/tree-sitter/releases/tag/v0.27.2",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; the test block has not been
run on either platform.

Makefile:71-77 builds tree-sitter.pc with sed, so the build needs a POSIX sed
that the pantry's base provides; no dependency is named for it.
EOT
}
